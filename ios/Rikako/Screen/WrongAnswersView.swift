import SwiftUI

struct WrongAnswersView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if appState.wrongQuestions.isEmpty {
                ContentUnavailableView {
                    Label("間違えた問題はありません", systemImage: "checkmark.circle")
                } description: {
                    Text("問題集を解いて、間違えた問題がここに表示されます")
                }
            } else {
                List {
                    Section {
                        Text("\(appState.wrongQuestions.count)問の間違えた問題があります")
                            .foregroundStyle(.secondary)
                    }

                    Section("問題一覧") {
                        ForEach(Array(appState.wrongQuestions.enumerated()), id: \.element.id) { index, question in
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
                        NavigationLink(destination: QuizView(questions: appState.wrongQuestions, workbookTitle: "復習", workbookId: 0)) {
                            Label("復習する", systemImage: "arrow.counterclockwise")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }
                    }

                    Section {
                        Button(role: .destructive) {
                            appState.clearWrongAnswers()
                        } label: {
                            Label("一覧をクリア", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("間違えた問題")
    }
}

#Preview {
    NavigationStack {
        WrongAnswersView()
            .environment(AppState.shared)
    }
}
