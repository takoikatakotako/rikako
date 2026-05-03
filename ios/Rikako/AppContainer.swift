import Foundation

final class AppContainer {
    static let shared = AppContainer()

    let appState: AppState
    let learningUseCases: LearningUseCases
    let deviceIdentityProvider: DeviceIdentityProviding
    let anonymousSignIn: () async throws -> String

    private init() {
        let flavor = AppFlavor.current
        let httpClient = URLSessionHTTPClient(session: .shared)
        let deviceIdentityProvider = CognitoDeviceIdentityProvider(
            session: .shared,
            keychainStore: KeychainIdentityStore()
        )
        let repository = RemoteLearningRepository(
            flavor: flavor,
            httpClient: httpClient,
            deviceIdentityProvider: deviceIdentityProvider
        )

        self.appState = AppState.shared
        self.learningUseCases = LearningUseCases(repository: repository)
        self.deviceIdentityProvider = deviceIdentityProvider
        self.anonymousSignIn = { try await repository.anonymousSignIn() }
    }
}
