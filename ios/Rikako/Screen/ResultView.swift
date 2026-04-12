import SwiftUI

struct ResultView: View {
    let questions: [Question]
    let answers: [Int?]
    let workbookTitle: String
    let workbookId: Int64

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
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

    private var legacyResultImageName: String {
        if scorePercentage == 100 { return "result-100per" }
        if scorePercentage >= 80 { return "result-80per" }
        if scorePercentage >= 60 { return "result-60per" }
        if scorePercentage >= 40 { return "result-40per" }
        return "result-20per"
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
        .toolbar(.hidden, for: .tabBar)
        .task {
            guard !didSubmit else { return }
            didSubmit = true
            appState.recordSession(workbookId: workbookId, questions: questions, answers: answers)
        }
    }

    private var scoreCard: some View {
        HStack(alignment: .bottom, spacing: 16) {
            Image(legacyResultImageName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 160)

            VStack(alignment: .trailing, spacing: 8) {
                Text(workbookTitle)
                    .font(.headline)
                    .foregroundStyle(.secondary)

                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(Int(scorePercentage))")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundStyle(Color("reaultColor-60per"))
                    Text("%")
                        .font(.title3.bold())
                        .foregroundStyle(Color("reaultColor-60per"))
                }

                Text("\(correctCount)問 / \(questions.count)問")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text(resultMessage)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
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
                    Image(answers[index] == question.correctIndex ? "result-correct" : "result-discorrect")
                        .resizable()
                        .frame(width: 28, height: 28)
                        .opacity(0.6)
                    Text("Q\(index + 1)")
                        .fontWeight(.bold)
                        .frame(width: 32)
                    Text(question.text)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image("result-next")
                        .resizable()
                        .frame(width: 18, height: 18)
                        .opacity(0.4)
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

}

#Preview {
    NavigationStack {
        ResultView(
            questions: MockData.questions,
            answers: [0, 1, 2, 0, 2],
            workbookTitle: "基礎化学",
            workbookId: 1
        )
        .environment(AppState.shared)
    }
}
