import Foundation
import Observation

@Observable
@MainActor
final class AppState {
    static let shared = AppState()
    static func preview() -> AppState { AppState() }

    var hasCompletedOnboarding: Bool
    var isLoggedIn: Bool
    var selectedWorkbookID: Int64?
    private(set) var totalAnswered: Int
    private(set) var totalCorrect: Int
    private(set) var completedWorkbookIDs: Set<Int64>
    private(set) var wrongQuestions: [Question]

    private init() {
        self.hasCompletedOnboarding = false
        self.isLoggedIn = false
        self.selectedWorkbookID = nil
        self.totalAnswered = 0
        self.totalCorrect = 0
        self.completedWorkbookIDs = []
        self.wrongQuestions = []
    }

    var accuracyText: String {
        guard totalAnswered > 0 else { return "--%" }
        let percentage = Int((Double(totalCorrect) / Double(totalAnswered)) * 100)
        return "\(percentage)%"
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
    }

    func setLoggedIn(_ value: Bool) {
        isLoggedIn = value
    }

    func selectWorkbook(_ workbookID: Int64) {
        selectedWorkbookID = workbookID
    }

    func recordSession(workbookId: Int64, questions: [Question], answers: [Int?]) {
        let answeredPairs = zip(questions, answers).filter { $0.1 != nil }
        let answeredCount = answeredPairs.count
        let correctCount = answeredPairs.filter { question, answer in
            answer == question.correctIndex
        }.count

        totalAnswered += answeredCount
        totalCorrect += correctCount
        completedWorkbookIDs.insert(workbookId)

        var latestWrongQuestions = wrongQuestions
        for (question, answer) in answeredPairs {
            guard answer != question.correctIndex else { continue }
            latestWrongQuestions.removeAll { $0.id == question.id }
            latestWrongQuestions.insert(question, at: 0)
        }
        wrongQuestions = latestWrongQuestions
    }

    func clearWrongAnswers() {
        wrongQuestions = []
    }
}
