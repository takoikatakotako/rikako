import Foundation
import Observation

@Observable
@MainActor
final class QuizViewModel {
    let questions: [Question]
    let workbookTitle: String
    let source: QuizSource

    var currentIndex = 0
    var selectedChoice: Int?
    var showExplanation = false
    var answers: [Int?]
    var showResult = false

    init(questions: [Question], workbookTitle: String, source: QuizSource) {
        self.questions = questions
        self.workbookTitle = workbookTitle
        self.source = source
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
        let byWorkbook = source.groupedAnswers(questions: questions, answers: answers)
        guard !byWorkbook.isEmpty else { return }
        for (wbId, items) in byWorkbook {
            _ = try? await AppContainer.shared.learningUseCases.submitAnswers.execute(
                workbookId: wbId,
                answers: items
            )
        }
    }
}
