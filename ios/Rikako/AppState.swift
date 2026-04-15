import Foundation
import Observation

@Observable
@MainActor
final class AppState {
    static let shared = AppState()
    static func preview() -> AppState {
        AppState(userDefaults: UserDefaults(suiteName: "jp.conol.rikako.preview.\(UUID().uuidString)")!)
    }

    private enum DefaultsKey {
        static let hasCompletedOnboarding = "jp.conol.rikako.hasCompletedOnboarding"
        static let anonymousUserId = "jp.conol.rikako.anonymousUserId"
    }

    var hasCompletedOnboarding: Bool
    var isLoggedIn: Bool
    var anonymousUserId: String?
    var displayName: String?
    var selectedWorkbookID: Int64?
    private(set) var totalAnswered: Int
    private(set) var totalCorrect: Int
    private(set) var completedWorkbookIDs: Set<Int64>
    private(set) var wrongQuestions: [Question]
    private let userDefaults: UserDefaults

    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.hasCompletedOnboarding = userDefaults.bool(forKey: DefaultsKey.hasCompletedOnboarding)
        self.isLoggedIn = false
        self.anonymousUserId = userDefaults.string(forKey: DefaultsKey.anonymousUserId)
        self.displayName = nil
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

    func completeOnboarding(anonymousUserId: String) {
        self.anonymousUserId = anonymousUserId
        hasCompletedOnboarding = true
        userDefaults.set(anonymousUserId, forKey: DefaultsKey.anonymousUserId)
        userDefaults.set(true, forKey: DefaultsKey.hasCompletedOnboarding)
    }

    func setLoggedIn(_ value: Bool) {
        isLoggedIn = value
    }

    func resetToInitialState() {
        hasCompletedOnboarding = false
        isLoggedIn = false
        anonymousUserId = nil
        displayName = nil
        selectedWorkbookID = nil
        totalAnswered = 0
        totalCorrect = 0
        completedWorkbookIDs = []
        wrongQuestions = []
        userDefaults.removeObject(forKey: DefaultsKey.hasCompletedOnboarding)
        userDefaults.removeObject(forKey: DefaultsKey.anonymousUserId)
    }

    func selectWorkbook(_ workbookID: Int64) {
        selectedWorkbookID = workbookID
        Task {
            try? await AppContainer.shared.learningUseCases.updateUserProfile.execute(
                appSlug: "chemistry",
                request: UpdateUserProfileRequest(selectedWorkbookId: workbookID)
            )
        }
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
