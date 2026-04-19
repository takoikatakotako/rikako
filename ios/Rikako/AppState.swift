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
        static let selectedWorkbookID = "jp.conol.rikako.selectedWorkbookID"
    }

    var hasCompletedOnboarding: Bool
    var isLoggedIn: Bool
    var anonymousUserId: String?
    var userId: Int64?
    var displayName: String?
    var selectedWorkbookID: Int64?
    private let userDefaults: UserDefaults

    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.hasCompletedOnboarding = userDefaults.bool(forKey: DefaultsKey.hasCompletedOnboarding)
        self.isLoggedIn = false
        self.anonymousUserId = userDefaults.string(forKey: DefaultsKey.anonymousUserId)
        self.userId = nil
        self.displayName = nil
        self.selectedWorkbookID = nil
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
        userDefaults.removeObject(forKey: DefaultsKey.hasCompletedOnboarding)
        userDefaults.removeObject(forKey: DefaultsKey.anonymousUserId)
        userDefaults.removeObject(forKey: DefaultsKey.selectedWorkbookID)
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
}
