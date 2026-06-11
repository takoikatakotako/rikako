import Foundation
import Observation

@Observable
@MainActor
final class QuizViewModel {
    let questions: [Question]
    let workbookTitle: String
    let workbookId: Int64
    let questionWorkbookIds: [Int64: Int64]?

    var currentIndex = 0
    var selectedChoice: Int?
    var showExplanation = false
    var answers: [Int?]
    var showResult = false

    init(questions: [Question], workbookTitle: String, workbookId: Int64, questionWorkbookIds: [Int64: Int64]? = nil) {
        self.questions = questions
        self.workbookTitle = workbookTitle
        self.workbookId = workbookId
        self.questionWorkbookIds = questionWorkbookIds
        self.answers = Array(repeating: nil, count: questions.count)
    }

    var currentQuestion: Question {
        questions[currentIndex]
    }

    var isLastQuestion: Bool {
        currentIndex == questions.count - 1
    }

    func selectChoice(_ index: Int) {
        guard !showExplanation else { return }
        selectedChoice = index
        answers[currentIndex] = index
        showExplanation = true
    }

    func goToNextQuestionOrResult() {
        if isLastQuestion {
            showResult = true
        } else {
            currentIndex += 1
            selectedChoice = nil
            showExplanation = false
        }
    }

    func submitAnswers() async {
        var byWorkbook: [Int64: [AnswerItem]] = [:]
        for (question, answer) in zip(questions, answers) {
            guard let choice = answer else { continue }
            let item = AnswerItem(questionId: question.id, selectedChoice: choice)
            let wbId = questionWorkbookIds?[question.id] ?? workbookId
            byWorkbook[wbId, default: []].append(item)
        }
        guard !byWorkbook.isEmpty else { return }
        for (wbId, items) in byWorkbook {
            _ = try? await AppContainer.shared.learningUseCases.submitAnswers.execute(
                workbookId: wbId,
                answers: items
            )
        }
    }
}
