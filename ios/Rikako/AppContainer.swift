import Foundation

final class AppContainer {
    static let shared = AppContainer()

    let appState: AppState
    let learningUseCases: LearningUseCases

    private init() {
        let httpClient = URLSessionHTTPClient(session: .shared)
        let deviceIdentityProvider = CognitoDeviceIdentityProvider(
            session: .shared,
            keychainStore: KeychainIdentityStore()
        )
        let repository = RemoteLearningRepository(
            httpClient: httpClient,
            deviceIdentityProvider: deviceIdentityProvider
        )

        self.appState = AppState.shared
        self.learningUseCases = LearningUseCases(repository: repository)
    }
}
