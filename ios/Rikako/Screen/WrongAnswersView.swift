import SwiftUI

struct WrongAnswersView: View {
    @State private var questions: [Question] = []
    @State private var total = 0
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView("読み込み中...")
            } else if questions.isEmpty {
                ContentUnavailableView {
                    Label("間違えた問題はありません", systemImage: "checkmark.circle")
                } description: {
                    Text("問題集を解いて、間違えた問題がここに表示されます")
                }
            } else {
                List {
                    Section {
                        Text("\(total)問の間違えた問題があります")
                            .foregroundStyle(.secondary)
                    }

                    Section("問題一覧") {
                        ForEach(Array(questions.enumerated()), id: \.element.id) { index, question in
                            VStack(alignment: .leading, spacing: 12) {
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

                                if let images = question.images, !images.isEmpty {
                                    QuestionImageSection(imageURLs: images)
                                }
                            }
                        }
                    }

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
        .navigationTitle("間違えた問題")
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        let response = try? await AppContainer.shared.learningUseCases.fetchWrongAnswers.execute(limit: 50, offset: 0)
        questions = response?.questions ?? []
        total = response?.total ?? 0
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        WrongAnswersView()
    }
}
