import SwiftUI

struct LegacyTopView: View {
    @Environment(AppState.self) private var appState
    @State private var workbooks: [Workbook] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var completionRateText: String {
        guard !workbooks.isEmpty else { return "0.0%" }
        let rate = (Double(appState.completedWorkbookIDs.count) / Double(workbooks.count)) * 100
        return String(format: "%.1f%%", rate)
    }

    private var nextWorkbook: Workbook? {
        if let selectedWorkbookID = appState.selectedWorkbookID,
           let selectedWorkbook = workbooks.first(where: { $0.id == selectedWorkbookID }),
           !appState.completedWorkbookIDs.contains(selectedWorkbookID) {
            return selectedWorkbook
        }
        return workbooks.first { !appState.completedWorkbookIDs.contains($0.id) } ?? workbooks.first
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color("main")
                    .ignoresSafeArea()

                if isLoading {
                    ProgressView("読み込み中...")
                        .tint(.white)
                } else if let errorMessage {
                    VStack(spacing: 16) {
                        Text("読み込みエラー")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                        Button("再読み込み") {
                            Task { await loadWorkbooks() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(24)
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            Spacer(minLength: 20)

                            Image("top-app-logo")
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 220)

                            Image("top-rikako-standing")
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 280)

                            VStack(spacing: 8) {
                                statRow(title: "問題集", value: "\(workbooks.count)冊")
                                statRow(title: "達成率", value: completionRateText)
                            }
                            .padding(.horizontal, 12)

                            HStack(spacing: 12) {
                                NavigationLink(destination: WrongAnswersView()) {
                                    actionButtonTitle("復習(\(appState.wrongQuestions.count))", color: Color("incorrectBlue"))
                                }

                                if let nextWorkbook {
                                    NavigationLink(destination: WorkbookDetailView(workbookID: nextWorkbook.id)) {
                                        actionButtonTitle("未学習", color: Color("correctPink"))
                                    }
                                } else {
                                    actionButtonTitle("未学習", color: Color("correctPink"))
                                }
                            }
                            .padding(.horizontal, 12)

                            if let nextWorkbook {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("次に解く")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    NavigationLink(destination: WorkbookDetailView(workbookID: nextWorkbook.id)) {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(nextWorkbook.title)
                                                .font(.headline)
                                                .foregroundStyle(.primary)
                                            Text(nextWorkbook.description)
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                            Text("\(nextWorkbook.questionCount)問")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(16)
                                        .background(Color.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                    }
                                }
                                .padding(.horizontal, 12)
                            }

                            Spacer(minLength: 20)
                        }
                    }
                }
            }
            .navigationTitle("トップ")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await loadWorkbooks()
        }
    }

    private func statRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.white)
                .font(.system(size: 20, weight: .bold))
            Spacer()
            Text(value)
                .foregroundStyle(.white)
                .font(.system(size: 20, weight: .bold))
        }
    }

    private func actionButtonTitle(_ title: String, color: Color) -> some View {
        Text(title)
            .foregroundStyle(.white)
            .font(.system(size: 20, weight: .bold))
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func loadWorkbooks() async {
        isLoading = true
        errorMessage = nil
        do {
            workbooks = try await AppContainer.shared.learningUseCases.fetchWorkbooks.execute()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

#Preview {
    LegacyTopView()
        .environment(AppState.shared)
}
