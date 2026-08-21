import Foundation
import Testing
@testable import Rikako

private final class StubLinkCognitoClient: CognitoUserPoolClienting, @unchecked Sendable {
    var tokens: AuthTokens?

    func signUp(email: String, password: String) async throws {}
    func confirmSignUp(email: String, code: String) async throws {}
    func resendConfirmationCode(email: String) async throws {}
    func forgotPassword(email: String) async throws {}
    func confirmForgotPassword(email: String, code: String, newPassword: String) async throws {}
    func revokeToken(refreshToken: String) async throws {}
    func refresh(refreshToken: String) async throws -> AuthTokens {
        throw CognitoError(code: "NotStubbed", message: "")
    }

    func signIn(email: String, password: String) async throws -> AuthTokens {
        guard let tokens else { throw CognitoError(code: "NotStubbed", message: "") }
        return tokens
    }
}

private func linkTestTokens(expiresIn: TimeInterval = 3600) -> AuthTokens {
    AuthTokens(
        idToken: "header.payload.signature",
        accessToken: "access",
        refreshToken: "refresh",
        expiresAt: Date().addingTimeInterval(expiresIn)
    )
}

/// テストごとに独立した UserDefaults を使う。
private func makePendingStore() -> AccountLinkPendingStore {
    AccountLinkPendingStore(
        userDefaults: UserDefaults(suiteName: "jp.conol.rikako.tests.\(UUID().uuidString)")!
    )
}

/// save が呼ばれた瞬間に検証を差し込めるトークン保管。
private final class ObservingAuthTokenStore: AuthTokenStoring, @unchecked Sendable {
    private var tokens: AuthTokens?
    private let onSave: () -> Void
    private(set) var saveCallCount = 0

    init(onSave: @escaping () -> Void) {
        self.onSave = onSave
    }

    func load() -> AuthTokens? { tokens }

    func save(_ tokens: AuthTokens) {
        saveCallCount += 1
        onSave()
        self.tokens = tokens
    }

    func clear() { tokens = nil }
}

@MainActor
struct AccountLinkCoordinatorTests {
    private func makeSession(
        pendingStore: AccountLinkPendingStore,
        tokens: AuthTokens? = nil
    ) -> AccountSession {
        AccountSession(
            client: StubLinkCognitoClient(),
            store: InMemoryAuthTokenStore(tokens: tokens),
            linkPendingStore: pendingStore
        )
    }

    /// 未ログインならリンクを試みない。
    @Test func doesNothingWhenLoggedOut() async {
        let store = makePendingStore()
        store.set(true)
        var callCount = 0
        let coordinator = AccountLinkCoordinator(
            session: makeSession(pendingStore: store),
            pendingStore: store,
            link: { callCount += 1 }
        )

        await coordinator.ensureLinked()

        #expect(callCount == 0)
        #expect(coordinator.state == .idle)
    }

    /// 未完了フラグが無ければ呼ばない（冪等・毎起動で無駄打ちしない）。
    @Test func doesNothingWhenNotPending() async {
        let store = makePendingStore()
        store.set(false)
        var callCount = 0
        let coordinator = AccountLinkCoordinator(
            session: makeSession(pendingStore: store, tokens: linkTestTokens()),
            pendingStore: store,
            link: { callCount += 1 }
        )

        await coordinator.ensureLinked()

        #expect(callCount == 0)
    }

    /// 成功したらフラグを下ろす。
    @Test func clearsPendingOnSuccess() async {
        let store = makePendingStore()
        store.set(true)
        let coordinator = AccountLinkCoordinator(
            session: makeSession(pendingStore: store, tokens: linkTestTokens()),
            pendingStore: store,
            link: {}
        )

        await coordinator.ensureLinked()

        #expect(store.isPending == false)
        #expect(coordinator.state == .idle)
    }

    /// 失敗してもフラグは残す（次回起動でやり直せるように）。
    @Test func keepsPendingOnFailure() async {
        let store = makePendingStore()
        store.set(true)
        let coordinator = AccountLinkCoordinator(
            session: makeSession(pendingStore: store, tokens: linkTestTokens()),
            pendingStore: store,
            link: { throw APIError.httpError(500) }
        )

        await coordinator.ensureLinked()

        #expect(store.isPending, "失敗したのにフラグが落ちている")
        #expect(coordinator.state == .failed)
    }

    /// ログイン → リンク失敗 → アプリ再起動、で自動的にやり直される。
    @Test func retriesOnNextLaunchAfterFailure() async {
        let store = makePendingStore()
        let tokens = linkTestTokens()

        // 1回目の起動（ログイン直後にリンクが失敗する）
        let failing = AccountLinkCoordinator(
            session: makeSession(pendingStore: store, tokens: tokens),
            pendingStore: store,
            link: { throw APIError.httpError(500) }
        )
        store.set(true)
        await failing.ensureLinked()
        #expect(store.isPending)

        // 2回目の起動（同じ端末＝同じ store。今度は成功する）
        var callCount = 0
        let succeeding = AccountLinkCoordinator(
            session: makeSession(pendingStore: store, tokens: tokens),
            pendingStore: store,
            link: { callCount += 1 }
        )
        await succeeding.ensureLinked()

        #expect(callCount == 1, "再起動後にリンクがやり直されていない")
        #expect(store.isPending == false)
        #expect(succeeding.state == .idle)
    }

    /// 失敗表示からの明示的な再試行で回復できる。
    @Test func retryRecoversFromFailure() async {
        let store = makePendingStore()
        store.set(true)
        var shouldFail = true
        let coordinator = AccountLinkCoordinator(
            session: makeSession(pendingStore: store, tokens: linkTestTokens()),
            pendingStore: store,
            link: {
                if shouldFail { throw APIError.httpError(500) }
            }
        )

        await coordinator.ensureLinked()
        #expect(coordinator.state == .failed)

        shouldFail = false
        await coordinator.retry()

        #expect(coordinator.state == .idle)
        #expect(store.isPending == false)
    }

    /// ログインすると未完了フラグが立つ（リンク前にアプリが終了しても残る）。
    @Test func signInMarksPending() async throws {
        let store = makePendingStore()
        let client = StubLinkCognitoClient()
        client.tokens = linkTestTokens()
        let session = AccountSession(
            client: client,
            store: InMemoryAuthTokenStore(),
            linkPendingStore: store
        )

        try await session.signIn(email: "a@example.com", password: "Passw0rd!")

        #expect(store.isPending)
    }

    /// signIn は「トークン保存より先に」pending を立てる。
    /// 途中で終了しても「ログイン済みなのに pending=false」にならないようにするため。
    @Test func signInMarksPendingBeforePersistingTokens() async throws {
        let store = makePendingStore()
        let client = StubLinkCognitoClient()
        client.tokens = linkTestTokens()

        // トークン保存の瞬間に pending が既に立っていることを確認する。
        let tokenStore = ObservingAuthTokenStore { #expect(store.isPending, "トークン保存時点で pending が立っていない") }
        let session = AccountSession(client: client, store: tokenStore, linkPendingStore: store)

        try await session.signIn(email: "a@example.com", password: "Passw0rd!")

        #expect(tokenStore.saveCallCount == 1)
        #expect(store.isPending)
    }

    /// pending キーを持たないビルドから持ち越した端末は、ログイン済みなら未完了として扱う。
    @Test func treatsMissingPendingKeyAsPending() async {
        let defaults = UserDefaults(suiteName: "jp.conol.rikako.tests.\(UUID().uuidString)")!
        let store = AccountLinkPendingStore(userDefaults: defaults)
        var callCount = 0
        let coordinator = AccountLinkCoordinator(
            session: makeSession(pendingStore: store, tokens: linkTestTokens()),
            pendingStore: store,
            link: { callCount += 1 }
        )

        await coordinator.ensureLinked()

        #expect(callCount == 1, "持ち越し端末でリンクが実行されていない")
        #expect(store.isPending == false)
    }

    /// ログアウトしたらフラグを下ろす（走らせても意味がないため）。
    @Test func signOutClearsPending() async {
        let store = makePendingStore()
        store.set(true)
        let session = AccountSession(
            client: StubLinkCognitoClient(),
            store: InMemoryAuthTokenStore(tokens: linkTestTokens()),
            linkPendingStore: store
        )

        await session.signOut()

        #expect(store.isPending == false)
    }
}
