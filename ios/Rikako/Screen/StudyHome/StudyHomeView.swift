import SwiftUI

struct StudyHomeView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = StudyHomeViewModel(
        fetchWorkbooksUseCase: AppContainer.shared.learningUseCases.fetchWorkbooks,
        fetchWorkbookDetailUseCase: AppContainer.shared.learningUseCases.fetchWorkbookDetail
    )

    private var selectedWorkbook: Workbook? {
        viewModel.selectedWorkbook(selectedWorkbookID: appState.selectedWorkbookID)
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("問題集を読み込み中...")
                } else if let errorMessage = viewModel.errorMessage {
                    ContentUnavailableView {
                        Label("読み込みエラー", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("再読み込み") {
                            Task { await loadInitialState() }
                        }
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 18) {
                            if let selectedWorkbook {
                                workbookHero(selectedWorkbook)
                            }

                            chapterPanel
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("学習")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.isShowingWorkbookPicker = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.headline)
                    }
                    .accessibilityLabel("問題集を変更")
                }
            }
        }
        .sheet(isPresented: $viewModel.isShowingWorkbookPicker) {
            workbookPickerSheet
        }
        .task {
            await loadInitialState()
        }
        .task(id: appState.selectedWorkbookID) {
            await viewModel.loadSelectedWorkbookDetail(selectedWorkbookID: appState.selectedWorkbookID)
        }
    }

    private func loadInitialState() async {
        do {
            if let selectedWorkbookID = try await viewModel.loadInitialState(selectedWorkbookID: appState.selectedWorkbookID),
               appState.selectedWorkbookID != selectedWorkbookID {
                appState.selectWorkbook(selectedWorkbookID)
            }
        } catch {
        }
    }

    private func completionText() -> String {
        guard !viewModel.workbooks.isEmpty else { return "0%" }
        let rate = Int((Double(appState.completedWorkbookIDs.count) / Double(viewModel.workbooks.count)) * 100)
        return "\(rate)%"
    }

    private func selectedWorkbookStatusText(_ workbook: Workbook) -> String {
        if appState.completedWorkbookIDs.contains(workbook.id) {
            return "完了済み"
        }
        return "学習中"
    }

    private func workbookHero(_ workbook: Workbook) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 28)
                .fill(
                    LinearGradient(
                        colors: [Color("main"), Color.blue.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 74, height: 106)
                        .overlay(
                            VStack(spacing: 6) {
                                Image(systemName: "book.closed.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(.white)
                                Text("0点から\n化学基礎")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.center)
                            }
                        )

                    VStack(alignment: .leading, spacing: 8) {
                        Text(workbook.title)
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                            .lineLimit(2)

                        Text("おすすめ")
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.18))
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }

                    Spacer()
                }

                Text(workbook.description)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(3)
            }
            .padding(20)
        }
        .frame(height: 230)
    }

    private var chapterPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                VStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.headline)
                    Text("チャプター")
                        .font(.subheadline.bold())
                }
                Spacer()
            }
            .padding(.top, 18)
            .padding(.bottom, 12)

            RoundedRectangle(cornerRadius: 2)
                .fill(Color.orange)
                .frame(width: 70, height: 4)
                .padding(.bottom, 16)

            if let workbookDetail = viewModel.workbookDetail {
                NavigationLink(destination: QuizView(
                    questions: viewModel.firstChapterQuestions(),
                    workbookTitle: workbookDetail.title,
                    workbookId: workbookDetail.id
                )) {
                    VStack(spacing: 4) {
                        Text("はじめる")
                            .font(.headline.bold())
                        Text(viewModel.chapters().first?.title ?? "Lesson 1")
                            .font(.caption)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color("main"))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color("main").opacity(0.75), lineWidth: 4)
                    )
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
                }
                .buttonStyle(.plain)
            } else if viewModel.isDetailLoading {
                ProgressView("チャプターを準備中...")
                    .padding(.vertical, 24)
            }

            VStack(spacing: 0) {
                ForEach(viewModel.chapters()) { chapter in
                    chapterRow(chapter)
                    if chapter.id != viewModel.chapters().last?.id {
                        Divider()
                            .padding(.leading, 54)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 16)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private func chapterRow(_ chapter: StudyHomeViewModel.Chapter) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.35), lineWidth: 2)
                    .frame(width: 38, height: 38)

                if chapter.isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.gray)
                } else {
                    Text("\(chapter.id)")
                        .font(.headline.bold())
                        .foregroundStyle(.primary)
                }
            }

            Text(chapter.title)
                .font(.headline)
                .foregroundStyle(chapter.isLocked ? .secondary : .primary)

            Spacer()

            Text("\(chapter.questionCount)問")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.vertical, 14)
    }

    private var workbookPickerSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(viewModel.workbooks) { workbook in
                        Button {
                            appState.selectWorkbook(workbook.id)
                            viewModel.isShowingWorkbookPicker = false
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(workbook.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                        .multilineTextAlignment(.leading)
                                    Text(workbook.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.leading)
                                        .lineLimit(2)
                                    Text("\(workbook.questionCount)問")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if appState.selectedWorkbookID == workbook.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color("main"))
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("問題集を変更")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") {
                        viewModel.isShowingWorkbookPicker = false
                    }
                }
            }
        }
    }
}

#Preview {
    StudyHomeView()
        .environment(AppState.shared)
}
