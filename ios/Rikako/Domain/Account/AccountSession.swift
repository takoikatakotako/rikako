import Foundation
import Observation

/// メールアドレスでのログイン状態を持つ。トークンは Keychain に永続化するので、
/// アプリ再起動後もログインが続く。未ログインのときは従来どおり匿名（X-Device-ID）で動く。
@Observable
@MainActor
final class AccountSession {
    private(set) var tokens: AuthTokens?
    /// ログイン中のメールアドレス。ID token の email クレームから取る（表示用）。
    private(set) var email: String?

    private let client: CognitoUserPoolClienting
    private let store: AuthTokenStoring

    var isLoggedIn: Bool { tokens != nil }

    init(client: CognitoUserPoolClienting, store: AuthTokenStoring) {
        self.client = client
        self.store = store
        let saved = store.load()
        self.tokens = saved
        self.email = saved.flatMap { AccountSession.email(fromIdToken: $0.idToken) }
    }

    // MARK: - サインアップ

    func signUp(email: String, password: String) async throws {
        try await client.signUp(email: email, password: password)
    }

    func confirmSignUp(email: String, code: String) async throws {
        try await client.confirmSignUp(email: email, code: code)
    }

    func resendConfirmationCode(email: String) async throws {
        try await client.resendConfirmationCode(email: email)
    }

    // MARK: - ログイン

    func signIn(email: String, password: String) async throws {
        let tokens = try await client.signIn(email: email, password: password)
        apply(tokens)
    }

    /// API 呼び出し用の有効な ID token。期限が近ければ refresh する。
    ///
    /// nil を返すのは「本当に未ログイン」のときだけ。refresh の失敗は
    /// terminal（refresh token が失効・無効）と transient（オフライン、timeout、
    /// Cognito の 5xx、レート制限）を区別し、transient では **セッションを保持したまま
    /// throw する**。ここで匿名に降格させると、通信障害の瞬間からログインユーザーの
    /// 学習記録が X-Device-ID 側に書かれ、アカウントと匿名行にデータが分岐するため。
    func validIdToken() async throws -> String? {
        guard let tokens else { return nil }
        guard tokens.isExpired() else { return tokens.idToken }

        do {
            let refreshed = try await client.refresh(refreshToken: tokens.refreshToken)
            apply(refreshed)
            return refreshed.idToken
        } catch let error as CognitoError where AccountSession.isTerminal(error) {
            clear()
            return nil
        }
        // transient は呼び出し側へ伝える（匿名にフォールバックさせない）。
    }

    /// 再ログインしない限り回復しないエラーかどうか。
    /// refresh token の失効・無効・ユーザー削除だけを terminal として扱う。
    private static func isTerminal(_ error: CognitoError) -> Bool {
        switch error.code {
        case "NotAuthorizedException", "UserNotFoundException", "UserNotConfirmedException":
            return true
        default:
            return false
        }
    }

    // MARK: - パスワード再設定

    func forgotPassword(email: String) async throws {
        try await client.forgotPassword(email: email)
    }

    func confirmForgotPassword(email: String, code: String, newPassword: String) async throws {
        try await client.confirmForgotPassword(email: email, code: code, newPassword: newPassword)
    }

    // MARK: - ログアウト

    /// Cognito 側で refresh token を失効させたうえで、成否にかかわらずローカルを消す。
    /// device id は消さない（消すと再ログインのたびに空の users 行が増えるため）。
    func signOut() async {
        if let refreshToken = tokens?.refreshToken {
            try? await client.revokeToken(refreshToken: refreshToken)
        }
        clear()
    }

    // MARK: - 内部

    private func apply(_ tokens: AuthTokens) {
        self.tokens = tokens
        self.email = AccountSession.email(fromIdToken: tokens.idToken)
        store.save(tokens)
    }

    private func clear() {
        tokens = nil
        email = nil
        store.clear()
    }

    /// ID token（JWT）の payload から email を取り出す。表示専用なので署名検証はしない
    /// （検証はサーバー側の責務。取り出せなくてもログイン自体は成立させる）。
    static func email(fromIdToken idToken: String) -> String? {
        let parts = idToken.split(separator: ".")
        guard parts.count == 3 else { return nil }

        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        base64.append(String(repeating: "=", count: (4 - base64.count % 4) % 4))

        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json["email"] as? String
    }
}
