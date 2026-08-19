import Foundation
import Testing
@testable import Rikako

/// Cognito 呼び出しを差し替えるスタブ。
private final class StubCognitoClient: CognitoUserPoolClienting, @unchecked Sendable {
    var signInResult: Result<AuthTokens, Error> = .failure(CognitoError(code: "NotStubbed", message: ""))
    var refreshResult: Result<AuthTokens, Error> = .failure(CognitoError(code: "NotStubbed", message: ""))
    var revokedTokens: [String] = []
    var refreshCallCount = 0

    func signUp(email: String, password: String) async throws {}
    func confirmSignUp(email: String, code: String) async throws {}
    func resendConfirmationCode(email: String) async throws {}
    func forgotPassword(email: String) async throws {}
    func confirmForgotPassword(email: String, code: String, newPassword: String) async throws {}

    func signIn(email: String, password: String) async throws -> AuthTokens {
        try signInResult.get()
    }

    func refresh(refreshToken: String) async throws -> AuthTokens {
        refreshCallCount += 1
        return try refreshResult.get()
    }

    func revokeToken(refreshToken: String) async throws {
        revokedTokens.append(refreshToken)
    }
}

/// email クレーム付きの ID token を組み立てる（署名は検証しないのでダミー）。
private func makeIdToken(email: String?) -> String {
    var claims: [String: Any] = ["sub": "user-1"]
    if let email {
        claims["email"] = email
    }
    let payload = try! JSONSerialization.data(withJSONObject: claims)
        .base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
    return "header.\(payload).signature"
}

private func makeTokens(
    email: String? = "user@example.com",
    refreshToken: String = "refresh-1",
    expiresIn: TimeInterval = 3600
) -> AuthTokens {
    AuthTokens(
        idToken: makeIdToken(email: email),
        accessToken: "access-1",
        refreshToken: refreshToken,
        expiresAt: Date().addingTimeInterval(expiresIn)
    )
}

@MainActor
struct AccountSessionTests {
    /// 保存済みトークンがあれば、起動時点でログイン状態として復帰する。
    @Test func restoresSavedSession() {
        let store = InMemoryAuthTokenStore(tokens: makeTokens(email: "saved@example.com"))
        let session = AccountSession(client: StubCognitoClient(), store: store)

        #expect(session.isLoggedIn)
        #expect(session.email == "saved@example.com")
    }

    @Test func startsLoggedOutWithoutSavedTokens() {
        let session = AccountSession(client: StubCognitoClient(), store: InMemoryAuthTokenStore())

        #expect(session.isLoggedIn == false)
        #expect(session.email == nil)
    }

    /// ログインするとトークンを保存し、ID token の email を表示用に取り出す。
    @Test func signInPersistsTokensAndEmail() async throws {
        let client = StubCognitoClient()
        client.signInResult = .success(makeTokens(email: "new@example.com"))
        let store = InMemoryAuthTokenStore()
        let session = AccountSession(client: client, store: store)

        try await session.signIn(email: "new@example.com", password: "Passw0rd!")

        #expect(session.isLoggedIn)
        #expect(session.email == "new@example.com")
        #expect(store.load() != nil)
    }

    /// email クレームが無いトークンでも、ログイン自体は成立させる。
    @Test func signInWithoutEmailClaimStillLogsIn() async throws {
        let client = StubCognitoClient()
        client.signInResult = .success(makeTokens(email: nil))
        let session = AccountSession(client: client, store: InMemoryAuthTokenStore())

        try await session.signIn(email: "x@example.com", password: "Passw0rd!")

        #expect(session.isLoggedIn)
        #expect(session.email == nil)
    }

    /// 期限内なら refresh せずに手持ちの ID token を返す。
    @Test func validIdTokenSkipsRefreshWhenFresh() async {
        let client = StubCognitoClient()
        let tokens = makeTokens(expiresIn: 3600)
        let session = AccountSession(client: client, store: InMemoryAuthTokenStore(tokens: tokens))

        #expect(await session.validIdToken() == tokens.idToken)
        #expect(client.refreshCallCount == 0)
    }

    /// 期限切れなら refresh し、新しいトークンを保存する。
    @Test func validIdTokenRefreshesWhenExpired() async {
        let client = StubCognitoClient()
        let refreshed = makeTokens(email: "refreshed@example.com")
        client.refreshResult = .success(refreshed)
        let store = InMemoryAuthTokenStore(tokens: makeTokens(expiresIn: -10))
        let session = AccountSession(client: client, store: store)

        #expect(await session.validIdToken() == refreshed.idToken)
        #expect(client.refreshCallCount == 1)
        #expect(session.email == "refreshed@example.com")
        #expect(store.load()?.idToken == refreshed.idToken)
    }

    /// refresh に失敗したらセッションを終了する（匿名として続行できるように nil を返す）。
    @Test func validIdTokenClearsSessionWhenRefreshFails() async {
        let client = StubCognitoClient()
        client.refreshResult = .failure(CognitoError(code: "NotAuthorizedException", message: ""))
        let store = InMemoryAuthTokenStore(tokens: makeTokens(expiresIn: -10))
        let session = AccountSession(client: client, store: store)

        #expect(await session.validIdToken() == nil)
        #expect(session.isLoggedIn == false)
        #expect(store.load() == nil)
    }

    /// ログアウトは refresh token を失効させたうえでローカルを消す。
    @Test func signOutRevokesAndClears() async {
        let client = StubCognitoClient()
        let store = InMemoryAuthTokenStore(tokens: makeTokens(refreshToken: "refresh-to-revoke"))
        let session = AccountSession(client: client, store: store)

        await session.signOut()

        #expect(client.revokedTokens == ["refresh-to-revoke"])
        #expect(session.isLoggedIn == false)
        #expect(store.load() == nil)
    }
}
