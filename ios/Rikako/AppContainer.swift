import Foundation

final class AppContainer {
    static let shared = AppContainer()

    let appState: AppState
    let learningUseCases: LearningUseCases
    let deviceIdentityProvider: DeviceIdentityProviding
    let anonymousSignIn: () async throws -> String
    let analytics: AnalyticsClient
    let accountSession: AccountSession
    let accountLinkCoordinator: AccountLinkCoordinator

    private init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-uitest-screenshots") {
            let repository = PreviewLearningRepository()
            self.appState = AppState.shared
            self.learningUseCases = LearningUseCases(repository: repository)
            self.deviceIdentityProvider = PreviewDeviceIdentityProvider()
            self.anonymousSignIn = { try await repository.anonymousSignIn() }
            self.analytics = NoopAnalyticsClient()
            let previewSession = AccountSession(
                client: CognitoUserPoolClient(httpClient: URLSessionHTTPClient(session: .shared), clientId: ""),
                store: InMemoryAuthTokenStore()
            )
            self.accountSession = previewSession
            self.accountLinkCoordinator = AccountLinkCoordinator(
                session: previewSession,
                pendingStore: AccountLinkPendingStore(),
                link: {}
            )
            return
        }
        #endif

        #if DEBUG
        // E2E 用: 匿名 identity とログインセッションを消してから起動する。
        // 「未リンクの新しい端末」を毎回作れないと、匿名 → アカウントのマージを
        // 実際には通らないまま検証したつもりになるため。
        if ProcessInfo.processInfo.arguments.contains("-uitest-reset-identity") {
            KeychainIdentityStore().clear()
            KeychainAuthTokenStore().clear()
            AccountLinkPendingStore().set(false)
        }
        #endif

        let flavor = AppFlavor.current
        let httpClient = URLSessionHTTPClient(session: .shared)
        let deviceIdentityProvider = CognitoDeviceIdentityProvider(
            session: .shared,
            keychainStore: KeychainIdentityStore(),
            identityPoolId: flavor.cognitoIdentityPoolId
        )
        let accountSession = AccountSession(
            client: CognitoUserPoolClient(httpClient: httpClient, clientId: flavor.cognitoClientId),
            store: KeychainAuthTokenStore()
        )
        let repository = RemoteLearningRepository(
            flavor: flavor,
            httpClient: httpClient,
            deviceIdentityProvider: deviceIdentityProvider,
            tokenProvider: accountSession
        )

        self.appState = AppState.shared
        self.learningUseCases = LearningUseCases(repository: repository)
        self.deviceIdentityProvider = deviceIdentityProvider
        self.anonymousSignIn = { try await repository.anonymousSignIn() }
        self.accountSession = accountSession
        self.accountLinkCoordinator = AccountLinkCoordinator(
            session: accountSession,
            pendingStore: AccountLinkPendingStore(),
            link: { try await repository.linkAccount() }
        )

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
