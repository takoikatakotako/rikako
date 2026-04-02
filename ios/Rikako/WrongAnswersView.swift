import SwiftUI

struct WrongAnswersView: View {
    @State private var questions: [Question] = []
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
                        Task { await loadWrongAnswers() }
                    }
                }
            } else if questions.isEmpty {
                ContentUnavailableView {
                    Label("間違えた問題はありません", systemImage: "checkmark.circle")
                } description: {
                    Text("問題集を解いて、間違えた問題がここに表示されます")
                }
            } else {
                List {
                    Section {
                        Text("\(questions.count)問の間違えた問題があります")
                            .foregroundStyle(.secondary)
                    }

                    Section("問題一覧") {
                        ForEach(Array(questions.enumerated()), id: \.element.id) { index, question in
                            HStack {
                                Text("Q\(index + 1)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                    .frame(width: 32, height: 32)
                                    .background(Color.red)
                                    .clipShape(Circle())
                                Text(question.text)
                                    .lineLimit(2)
                            }
                        }
                    }

                    if !questions.isEmpty {
                        Section {
                            NavigationLink(destination: QuizView(questions: questions, workbookTitle: "復習", workbookId: 0)) {
                                Label("復習する", systemImage: "arrow.counterclockwise")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("間違えた問題")
        .task {
            await loadWrongAnswers()
        }
    }

    private func loadWrongAnswers() async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await APIClient.shared.fetchWrongAnswers()
            questions = response.questions
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

#Preview {
    NavigationStack {
        WrongAnswersView()
    }
}
