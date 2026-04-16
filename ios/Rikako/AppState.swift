import Foundation
import Observation

extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}

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
        static let studyDates = "jp.conol.rikako.studyDates"
        static let weeklyAnswered = "jp.conol.rikako.weeklyAnswered"
        static let weeklyCorrect = "jp.conol.rikako.weeklyCorrect"
        static let weeklyCompletedWorkbookIDs = "jp.conol.rikako.weeklyCompletedWorkbookIDs"
        static let currentWeekKey = "jp.conol.rikako.currentWeekKey"
        static let questionResults = "jp.conol.rikako.questionResults"
    }

    var hasCompletedOnboarding: Bool
    var isLoggedIn: Bool
    var anonymousUserId: String?
    var userId: Int64?
    var displayName: String?
    var selectedWorkbookID: Int64?
    private(set) var totalAnswered: Int
    private(set) var totalCorrect: Int
    private(set) var completedWorkbookIDs: Set<Int64>
    private(set) var wrongQuestions: [Question]
    private(set) var studyDates: Set<String>
    private(set) var weeklyAnswered: Int
    private(set) var weeklyCorrect: Int
    private(set) var weeklyCompletedWorkbookIDs: Set<Int64>
    // 問題IDごとの最新の正解/不正解 [questionId(String): isCorrect]
    private(set) var questionResults: [String: Bool]
    private let userDefaults: UserDefaults

    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.hasCompletedOnboarding = userDefaults.bool(forKey: DefaultsKey.hasCompletedOnboarding)
        self.isLoggedIn = false
        self.anonymousUserId = userDefaults.string(forKey: DefaultsKey.anonymousUserId)
        self.userId = nil
        self.displayName = nil
        self.selectedWorkbookID = nil
        self.totalAnswered = 0
        self.totalCorrect = 0
        self.completedWorkbookIDs = []
        self.wrongQuestions = []
        self.studyDates = Set(userDefaults.stringArray(forKey: DefaultsKey.studyDates) ?? [])
        self.questionResults = (userDefaults.dictionary(forKey: DefaultsKey.questionResults) as? [String: Bool]) ?? [:]

        let savedWeek = userDefaults.string(forKey: DefaultsKey.currentWeekKey) ?? ""
        let currentWeek = AppState.isoWeekKey(for: Date())
        if savedWeek == currentWeek {
            self.weeklyAnswered = userDefaults.integer(forKey: DefaultsKey.weeklyAnswered)
            self.weeklyCorrect = userDefaults.integer(forKey: DefaultsKey.weeklyCorrect)
            let ids = userDefaults.array(forKey: DefaultsKey.weeklyCompletedWorkbookIDs) as? [Int64] ?? []
            self.weeklyCompletedWorkbookIDs = Set(ids)
        } else {
            self.weeklyAnswered = 0
            self.weeklyCorrect = 0
            self.weeklyCompletedWorkbookIDs = []
        }
    }

    // "yyyy-Www" 形式（例: "2026-W17"）
    private static func isoWeekKey(for date: Date) -> String {
        let cal = Calendar(identifier: .iso8601)
        let year = cal.component(.yearForWeekOfYear, from: date)
        let week = cal.component(.weekOfYear, from: date)
        return String(format: "%04d-W%02d", year, week)
    }

    var accuracyText: String {
        guard totalAnswered > 0 else { return "--%" }
        let percentage = Int((Double(totalCorrect) / Double(totalAnswered)) * 100)
        return "\(percentage)%"
    }

    var weeklyAccuracyText: String {
        guard weeklyAnswered > 0 else { return "--%" }
        let percentage = Int((Double(weeklyCorrect) / Double(weeklyAnswered)) * 100)
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
        userId = nil
        displayName = nil
        selectedWorkbookID = nil
        totalAnswered = 0
        totalCorrect = 0
        completedWorkbookIDs = []
        wrongQuestions = []
        studyDates = []
        weeklyAnswered = 0
        weeklyCorrect = 0
        weeklyCompletedWorkbookIDs = []
        userDefaults.removeObject(forKey: DefaultsKey.hasCompletedOnboarding)
        userDefaults.removeObject(forKey: DefaultsKey.anonymousUserId)
        userDefaults.removeObject(forKey: DefaultsKey.studyDates)
        userDefaults.removeObject(forKey: DefaultsKey.weeklyAnswered)
        userDefaults.removeObject(forKey: DefaultsKey.weeklyCorrect)
        userDefaults.removeObject(forKey: DefaultsKey.weeklyCompletedWorkbookIDs)
        userDefaults.removeObject(forKey: DefaultsKey.currentWeekKey)
        questionResults = [:]
        userDefaults.removeObject(forKey: DefaultsKey.questionResults)
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

        let today = DateFormatter.yyyyMMdd.string(from: Date())
        studyDates.insert(today)
        userDefaults.set(Array(studyDates), forKey: DefaultsKey.studyDates)

        // 週が変わっていたらリセット
        let currentWeek = AppState.isoWeekKey(for: Date())
        if userDefaults.string(forKey: DefaultsKey.currentWeekKey) != currentWeek {
            weeklyAnswered = 0
            weeklyCorrect = 0
            weeklyCompletedWorkbookIDs = []
            userDefaults.set(currentWeek, forKey: DefaultsKey.currentWeekKey)
        }

        weeklyAnswered += answeredCount
        weeklyCorrect += correctCount
        weeklyCompletedWorkbookIDs.insert(workbookId)
        userDefaults.set(weeklyAnswered, forKey: DefaultsKey.weeklyAnswered)
        userDefaults.set(weeklyCorrect, forKey: DefaultsKey.weeklyCorrect)
        userDefaults.set(Array(weeklyCompletedWorkbookIDs), forKey: DefaultsKey.weeklyCompletedWorkbookIDs)

        // 問題ごとの正解/不正解を更新
        for (question, answer) in answeredPairs {
            questionResults[String(question.id)] = (answer == question.correctIndex)
        }
        userDefaults.set(questionResults, forKey: DefaultsKey.questionResults)

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
