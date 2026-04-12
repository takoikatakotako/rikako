import Foundation
import Observation

@Observable
@MainActor
final class ResultViewModel {
    struct QuestionResultRow: Identifiable {
        let id: Int64
        let index: Int
        let question: Question
        let selectedAnswer: Int?
        let isCorrect: Bool
    }

    let questions: [Question]
    let answers: [Int?]
    let workbookTitle: String
    let workbookId: Int64

    private(set) var didSubmit = false

    init(questions: [Question], answers: [Int?], workbookTitle: String, workbookId: Int64) {
        self.questions = questions
        self.answers = answers
        self.workbookTitle = workbookTitle
        self.workbookId = workbookId
    }

    var correctCount: Int {
        zip(questions, answers).filter { question, answer in
            answer == question.correctIndex
        }.count
    }

    var scorePercentage: Double {
        guard !questions.isEmpty else { return 0 }
        return Double(correctCount) / Double(questions.count) * 100
    }

    var legacyResultImageName: String {
        if scorePercentage == 100 { return "result-100per" }
        if scorePercentage >= 80 { return "result-80per" }
        if scorePercentage >= 60 { return "result-60per" }
        if scorePercentage >= 40 { return "result-40per" }
        return "result-20per"
    }

    var resultMessage: String {
        if scorePercentage == 100 { return "完璧です！" }
        if scorePercentage >= 80 { return "よくできました！" }
        if scorePercentage >= 60 { return "もう少しです！" }
        return "復習しましょう！"
    }

    var scoreColorName: String {
        if scorePercentage == 100 { return "resultColor-80per" }
        if scorePercentage >= 80 { return "resultColor-80per" }
        if scorePercentage >= 60 { return "resultColor-60per" }
        if scorePercentage >= 40 { return "resultColor-40per" }
        return "resultColor-20per"
    }

    var summaryText: String {
        "\(correctCount)問正解 / 全\(questions.count)問"
    }

    var questionResults: [QuestionResultRow] {
        Array(questions.enumerated()).map { index, question in
            QuestionResultRow(
                id: question.id,
                index: index,
                question: question,
                selectedAnswer: answers[index],
                isCorrect: answers[index] == question.correctIndex
            )
        }
    }

    func recordSessionIfNeeded(appState: AppState) {
        guard !didSubmit else { return }
        didSubmit = true
        appState.recordSession(workbookId: workbookId, questions: questions, answers: answers)
    }
}
