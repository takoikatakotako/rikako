import Foundation

final class AppContainer {
    static let shared = AppContainer()

    let appState: AppState
    let learningUseCases: LearningUseCases
    let deviceIdentityProvider: DeviceIdentityProviding
    let anonymousSignIn: () async throws -> String
    let analytics: AnalyticsClient

    private init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-uitest-screenshots") {
            let repository = PreviewLearningRepository()
            self.appState = AppState.shared
            self.learningUseCases = LearningUseCases(repository: repository)
            self.deviceIdentityProvider = PreviewDeviceIdentityProvider()
            self.anonymousSignIn = { try await repository.anonymousSignIn() }
            self.analytics = NoopAnalyticsClient()
            return
        }
        #endif

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

        // Phase 1: Firebase 未結線のため DEBUG はコンソール出力、Release は Noop。
        // Phase 2 で Release を FirebaseAnalyticsClient に差し替える（#261）。
        #if DEBUG
        let analytics: AnalyticsClient = ConsoleAnalyticsClient()
        #else
        let analytics: AnalyticsClient = NoopAnalyticsClient()
        #endif
        analytics.setCommonProperties(.current(flavor: flavor))
        self.analytics = analytics
    }
}
