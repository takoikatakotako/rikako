import SwiftUI

struct ResultView: View {
    let questions: [Question]
    let answers: [Int?]
    let workbookTitle: String
    let workbookId: Int64

    @Environment(\.dismiss) private var dismiss
    @State private var didSubmit = false

    private var correctCount: Int {
        zip(questions, answers).filter { question, answer in
            answer == question.correctIndex
        }.count
    }

    private var scorePercentage: Double {
        guard !questions.isEmpty else { return 0 }
        return Double(correctCount) / Double(questions.count) * 100
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                scoreCard
                questionResults
                backButton
            }
            .padding()
        }
        .navigationTitle("結果")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .task {
            guard !didSubmit else { return }
            didSubmit = true
            await submitAnswersToServer()
        }
    }

    private var scoreCard: some View {
        VStack(spacing: 12) {
            Text(workbookTitle)
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("\(correctCount) / \(questions.count)")
                .font(.system(size: 48, weight: .bold))

            Text("\(Int(scorePercentage))%")
                .font(.title2)
                .foregroundStyle(scorePercentage >= 80 ? .green : scorePercentage >= 60 ? .orange : .red)

            Text(resultMessage)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    private var questionResults: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("解答一覧")
                .font(.headline)

            ForEach(Array(questions.enumerated()), id: \.element.id) { index, question in
                HStack {
                    Image(systemName: answers[index] == question.correctIndex ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(answers[index] == question.correctIndex ? .green : .red)
                    Text("Q\(index + 1)")
                        .fontWeight(.bold)
                        .frame(width: 32)
                    Text(question.text)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            Text("問題集一覧に戻る")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .cornerRadius(12)
        }
    }

    private var resultMessage: String {
        if scorePercentage == 100 { return "完璧です！" }
        if scorePercentage >= 80 { return "よくできました！" }
        if scorePercentage >= 60 { return "もう少しです！" }
        return "復習しましょう！"
    }

    private func submitAnswersToServer() async {
        let answerItems: [AnswerItem] = zip(questions, answers).compactMap { question, answer in
            guard let selectedChoice = answer else { return nil }
            return AnswerItem(questionId: question.id, selectedChoice: selectedChoice)
        }
        guard !answerItems.isEmpty else { return }

        do {
            _ = try await APIClient.shared.submitAnswers(workbookId: workbookId, answers: answerItems)
        } catch {
            // Fail silently — answer submission is best-effort
            print("Failed to submit answers: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        ResultView(
            questions: MockData.questions,
            answers: [0, 1, 2, 0, 2],
            workbookTitle: "基礎化学",
            workbookId: 1
        )
    }
}
