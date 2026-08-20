import Foundation
import Observation

/// セッション由来のエラー。
enum AccountSessionError: LocalizedError, Equatable {
    /// refresh token が失効・無効になり、再ログインが必要な状態。
    case sessionExpired

    var errorDescription: String? {
        switch self {
        case .sessionExpired:
            return "ログインの有効期限が切れました。もう一度ログインしてください。"
        }
    }
}

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
    /// nil を返すのは「呼び出し時点で未ログイン」のときだけ。refresh の失敗は
    /// terminal（refresh token が失効・無効）と transient（オフライン、timeout、
    /// Cognito の 5xx、レート制限）を区別し、どちらも throw する。
    ///
    /// terminal でもローカルをクリアしたうえで throw するのが要点で、nil を返すと
    /// 期限切れを検知したその1回の書き込みだけが X-Device-ID 側へ流れてしまう。
    /// 匿名フローに戻るのは、tokens が無くなった **次の呼び出し以降**。
    func validIdToken() async throws -> String? {
        guard let tokens else { return nil }
        guard tokens.isExpired() else { return tokens.idToken }

        do {
            let refreshed = try await client.refresh(refreshToken: tokens.refreshToken)
            apply(refreshed)
            return refreshed.idToken
        } catch let error as CognitoError where AccountSession.isTerminal(error) {
            // ローカルのセッションは終了するが、この1回のリクエストは匿名で流さず失敗させる。
            clear()
            throw AccountSessionError.sessionExpired
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
