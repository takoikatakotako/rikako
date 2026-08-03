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

        // dev(Debug) = rikako-dev、prod(Release) = rikako-prd。plist は slug×env で選択。
        // dev は Console にも出力（コンソール即確認 + DebugView 検証の両立）。
        // plist が無ければ Firebase 分はスキップ（dev=Consoleのみ / prod=Noop）。
        #if DEBUG
        let environment = "dev"
        var clients: [AnalyticsClient] = [ConsoleAnalyticsClient()]
        if let firebase = FirebaseAnalyticsClient.configured(slug: flavor.slug, environment: environment) {
            clients.append(firebase)
        }
        let analytics: AnalyticsClient = CompositeAnalyticsClient(clients)
        #else
        let environment = "prod"
        let analytics: AnalyticsClient = FirebaseAnalyticsClient.configured(slug: flavor.slug, environment: environment) ?? NoopAnalyticsClient()
        #endif
        analytics.setCommonProperties(.current(flavor: flavor))
        self.analytics = analytics
    }
}
