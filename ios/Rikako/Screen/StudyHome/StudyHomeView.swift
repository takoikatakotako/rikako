import SwiftUI

struct StudyHomeView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: StudyHomeViewModel
    @State private var workbookProgress: [String: Bool] = [:]
    private let isPreview: Bool

    init() {
        _viewModel = State(initialValue: StudyHomeViewModel(
            fetchWorkbooksUseCase: AppContainer.shared.learningUseCases.fetchWorkbooks,
            fetchWorkbookDetailUseCase: AppContainer.shared.learningUseCases.fetchWorkbookDetail
        ))
        isPreview = false
    }

    fileprivate init(viewModel: StudyHomeViewModel) {
        _viewModel = State(initialValue: viewModel)
        isPreview = true
    }

    private var selectedWorkbook: Workbook? {
        viewModel.selectedWorkbook(selectedWorkbookID: appState.selectedWorkbookID)
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    skeletonView
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

                            sectionPanel
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
                        Image(systemName: "books.vertical.fill")
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
            guard !isPreview else { return }
            await loadInitialState()
        }
        .task(id: appState.selectedWorkbookID) {
            guard !isPreview else { return }
            await viewModel.loadSelectedWorkbookDetail(selectedWorkbookID: appState.selectedWorkbookID)
            await loadWorkbookProgress()
        }
    }

    private func loadWorkbookProgress() async {
        guard let workbookId = appState.selectedWorkbookID else { return }
        let response = try? await AppContainer.shared.learningUseCases.fetchWorkbookProgress.execute(workbookId: workbookId)
        workbookProgress = Dictionary(uniqueKeysWithValues: (response?.results ?? []).map { (String($0.questionId), $0.isCorrect) })
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

    private func workbookHero(_ workbook: Workbook) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 28)
                .fill(
                    LinearGradient(
                        colors: [Color(.main), Color.blue.opacity(0.7)],
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

    private var sectionPanel: some View {
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
                    questions: viewModel.firstSectionQuestions(),
                    workbookTitle: workbookDetail.title,
                    workbookId: workbookDetail.id,
                    allSectionsQuestions: viewModel.sections().map { viewModel.questions(for: $0) },
                    currentSectionIndex: 0
                )) {
                    VStack(spacing: 4) {
                        Text("はじめる")
                            .font(.headline.bold())
                        Text(viewModel.sections().first?.title ?? "Section 1")
                            .font(.caption)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color(.main))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(.main).opacity(0.75), lineWidth: 4)
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
                ForEach(viewModel.sections()) { section in
                    sectionRow(section)
                    if section.id != viewModel.sections().last?.id {
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

    private func sectionRow(_ section: StudyHomeViewModel.Section) -> some View {
        let questions = viewModel.questions(for: section)
        let workbookDetail = viewModel.workbookDetail
        let progress = viewModel.sectionProgress(for: section, questionResults: workbookProgress)

        return NavigationLink(destination: Group {
            if let workbookDetail {
                QuizView(
                    questions: questions,
                    workbookTitle: workbookDetail.title,
                    workbookId: workbookDetail.id,
                    allSectionsQuestions: viewModel.sections().map { viewModel.questions(for: $0) },
                    currentSectionIndex: section.id - 1
                )
            }
        }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.35), lineWidth: 2)
                        .frame(width: 38, height: 38)
                    Text("\(section.id)")
                        .font(.headline.bold())
                        .foregroundStyle(.primary)
                }

                Text(section.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                HStack(spacing: 2) {
                    Text("\(progress.correct)")
                        .font(.subheadline.bold())
                        .foregroundStyle(progress.answered > 0 ? Color(.main) : Color.secondary)
                    Text("/\(section.questionCount)")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var skeletonView: some View {
        ScrollView {
            VStack(spacing: 18) {
                // Hero skeleton
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color(.systemGray5))
                    .frame(height: 230)

                // Section panel skeleton
                VStack(spacing: 0) {
                    VStack(spacing: 8) {
                        skeletonRect(width: 120, height: 14)
                        skeletonRect(width: 80, height: 4)
                    }
                    .padding(.top, 18)
                    .padding(.bottom, 16)

                    skeletonRect(height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 14)
                        .padding(.bottom, 14)

                    VStack(spacing: 0) {
                        ForEach(0..<4, id: \.self) { index in
                            HStack(spacing: 14) {
                                Circle()
                                    .fill(Color(.systemGray5))
                                    .frame(width: 38, height: 38)
                                skeletonRect(width: 120, height: 14)
                                Spacer()
                                skeletonRect(width: 50, height: 30)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .padding(.vertical, 14)

                            if index < 3 {
                                Divider().padding(.leading, 54)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 16)
                }
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 24))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func skeletonRect(width: CGFloat? = nil, height: CGFloat = 14) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color(.systemGray5))
            .frame(width: width, height: height)
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
                                        .foregroundStyle(Color(.main))
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

#Preview("通常") {
    StudyHomeView()
        .environment(AppState.shared)
}

#Preview("読み込み中") {
    StudyHomeView(viewModel: .previewLoading())
        .environment(AppState.shared)
}

#Preview("エラー") {
    StudyHomeView(viewModel: .previewError())
        .environment(AppState.shared)
}
