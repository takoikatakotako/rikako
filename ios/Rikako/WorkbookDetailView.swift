import SwiftUI

struct WorkbookDetailView: View {
    let workbookID: Int64

    @State private var workbook: WorkbookDetail?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("読み込み中...")
            } else if let errorMessage {
                ContentUnavailableView {
                    Label("読み込みエラー", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("再読み込み") {
                        Task { await loadWorkbook() }
                    }
                }
            } else if let workbook {
                List {
                    Section {
                        Text(workbook.description)
                            .foregroundStyle(.secondary)
                    }

                    Section("問題一覧") {
                        ForEach(Array(workbook.questions.enumerated()), id: \.element.id) { index, question in
                            HStack {
                                Text("Q\(index + 1)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                    .frame(width: 32, height: 32)
                                    .background(Color.accentColor)
                                    .clipShape(Circle())
                                Text(question.text)
                                    .lineLimit(2)
                            }
                        }
                    }

                    Section {
                        NavigationLink(destination: QuizView(questions: workbook.questions, workbookTitle: workbook.title)) {
                            Label("この問題集を解く", systemImage: "play.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }
                    }
                }
                .navigationTitle(workbook.title)
            } else {
                ContentUnavailableView("問題集が見つかりません", systemImage: "exclamationmark.triangle")
            }
        }
        .task {
            await loadWorkbook()
        }
    }

    private func loadWorkbook() async {
        isLoading = true
        errorMessage = nil
        do {
            workbook = try await APIClient.shared.fetchWorkbookDetail(id: workbookID)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

#Preview {
    NavigationStack {
        WorkbookDetailView(workbookID: 1)
    }
}
