import Foundation
import Observation

@Observable
@MainActor
final class StudyStore {
    static let shared = StudyStore()

    var hasCompletedOnboarding: Bool
    var isLoggedIn: Bool
    private(set) var totalAnswered: Int
    private(set) var totalCorrect: Int
    private(set) var completedWorkbookIDs: Set<Int64>
    private(set) var wrongQuestions: [Question]

    private let defaults: UserDefaults

    private enum Keys {
        static let hasCompletedOnboarding = "study.hasCompletedOnboarding"
        static let isLoggedIn = "study.isLoggedIn"
        static let totalAnswered = "study.totalAnswered"
        static let totalCorrect = "study.totalCorrect"
        static let completedWorkbookIDs = "study.completedWorkbookIDs"
        static let wrongQuestions = "study.wrongQuestions"
    }

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.hasCompletedOnboarding = defaults.object(forKey: Keys.hasCompletedOnboarding) as? Bool ?? false
        self.isLoggedIn = defaults.object(forKey: Keys.isLoggedIn) as? Bool ?? false
        self.totalAnswered = defaults.integer(forKey: Keys.totalAnswered)
        self.totalCorrect = defaults.integer(forKey: Keys.totalCorrect)

        let workbookIDs = defaults.array(forKey: Keys.completedWorkbookIDs) as? [Int64] ?? []
        self.completedWorkbookIDs = Set(workbookIDs)

        if let data = defaults.data(forKey: Keys.wrongQuestions),
           let questions = try? JSONDecoder().decode([Question].self, from: data) {
            self.wrongQuestions = questions
        } else {
            self.wrongQuestions = []
        }
    }

    var accuracyText: String {
        guard totalAnswered > 0 else { return "--%" }
        let percentage = Int((Double(totalCorrect) / Double(totalAnswered)) * 100)
        return "\(percentage)%"
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        defaults.set(true, forKey: Keys.hasCompletedOnboarding)
    }

    func setLoggedIn(_ value: Bool) {
        isLoggedIn = value
        defaults.set(value, forKey: Keys.isLoggedIn)
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

        defaults.set(totalAnswered, forKey: Keys.totalAnswered)
        defaults.set(totalCorrect, forKey: Keys.totalCorrect)
        defaults.set(Array(completedWorkbookIDs), forKey: Keys.completedWorkbookIDs)

        var latestWrongQuestions = wrongQuestions
        for (question, answer) in answeredPairs {
            guard answer != question.correctIndex else { continue }
            latestWrongQuestions.removeAll { $0.id == question.id }
            latestWrongQuestions.insert(question, at: 0)
        }
        wrongQuestions = latestWrongQuestions
        persistWrongQuestions()
    }

    func clearWrongAnswers() {
        wrongQuestions = []
        defaults.removeObject(forKey: Keys.wrongQuestions)
    }

    private func persistWrongQuestions() {
        if let data = try? JSONEncoder().encode(wrongQuestions) {
            defaults.set(data, forKey: Keys.wrongQuestions)
        }
    }
}
