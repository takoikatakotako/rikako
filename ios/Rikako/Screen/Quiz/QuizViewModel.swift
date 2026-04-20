import Foundation
import Observation

@Observable
@MainActor
final class QuizViewModel {
    let questions: [Question]
    let workbookTitle: String
    let workbookId: Int64

    var currentIndex = 0
    var selectedChoice: Int?
    var showExplanation = false
    var answers: [Int?]
    var showResult = false

    init(questions: [Question], workbookTitle: String, workbookId: Int64) {
        self.questions = questions
        self.workbookTitle = workbookTitle
        self.workbookId = workbookId
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
        let answerItems = zip(questions, answers).compactMap { question, answer -> AnswerItem? in
            guard let choice = answer else { return nil }
            return AnswerItem(questionId: question.id, selectedChoice: choice)
        }
        guard !answerItems.isEmpty else { return }
        _ = try? await AppContainer.shared.learningUseCases.submitAnswers.execute(
            workbookId: workbookId,
            answers: answerItems
        )
    }
}
