import Foundation

/// Cognito User Pool の操作。Amplify は使わず cognito-idp を URLSession で直叩きする
/// （匿名認証の `CognitoDeviceIdentityProvider` と同じ流儀）。
/// 操作・エラー文言は Web ポータルの `portal/src/lib/cognito.ts` と対になっている。
protocol CognitoUserPoolClienting {
    func signUp(email: String, password: String) async throws
    func confirmSignUp(email: String, code: String) async throws
    func resendConfirmationCode(email: String) async throws
    func signIn(email: String, password: String) async throws -> AuthTokens
    func refresh(refreshToken: String) async throws -> AuthTokens
    func forgotPassword(email: String) async throws
    func confirmForgotPassword(email: String, code: String, newPassword: String) async throws
    func revokeToken(refreshToken: String) async throws
}

/// cognito-idp が返すエラー。`__type` の `#` 以降がエラーコード。
struct CognitoError: LocalizedError, Equatable {
    let code: String
    let message: String

    var errorDescription: String? {
        CognitoError.japaneseMessage(code: code, fallback: message)
    }

    /// エラーコードを日本語メッセージに寄せる。
    /// prevent_user_existence_errors=ENABLED のため「ユーザー不存在」は出さない方針。
    static func japaneseMessage(code: String, fallback: String) -> String {
        switch code {
        case "UsernameExistsException":
            return "このメールアドレスは既に登録されています。"
        case "InvalidPasswordException":
            return "パスワードが要件を満たしていません（8文字以上・大小英字・数字・記号）。"
        case "CodeMismatchException":
            return "確認コードが正しくありません。"
        case "ExpiredCodeException":
            return "確認コードの有効期限が切れています。再送してください。"
        case "NotAuthorizedException":
            return "メールアドレスまたはパスワードが正しくありません。"
        case "UserNotConfirmedException":
            return "メール確認が完了していません。確認コードを入力してください。"
        case "LimitExceededException", "TooManyRequestsException":
            return "試行回数が多すぎます。しばらくしてから再度お試しください。"
        default:
            return fallback.isEmpty ? "エラーが発生しました。" : fallback
        }
    }
}

struct CognitoUserPoolClient: CognitoUserPoolClienting {
    private let httpClient: HTTPClient
    private let clientId: String
    private let endpoint: URL

    init(httpClient: HTTPClient, clientId: String, region: String = "ap-northeast-1") {
        self.httpClient = httpClient
        self.clientId = clientId
        self.endpoint = URL(string: "https://cognito-idp.\(region).amazonaws.com/")!
    }

    // MARK: - サインアップ

    /// サインアップ。成功するとメールに確認コードが送られる。
    func signUp(email: String, password: String) async throws {
        _ = try await call("SignUp", body: [
            "ClientId": clientId,
            "Username": email,
            "Password": password,
            "UserAttributes": [["Name": "email", "Value": email]],
        ])
    }

    func confirmSignUp(email: String, code: String) async throws {
        _ = try await call("ConfirmSignUp", body: [
            "ClientId": clientId,
            "Username": email,
            "ConfirmationCode": code,
        ])
    }

    func resendConfirmationCode(email: String) async throws {
        _ = try await call("ResendConfirmationCode", body: [
            "ClientId": clientId,
            "Username": email,
        ])
    }

    // MARK: - ログイン

    /// ログイン（USER_PASSWORD_AUTH）。App Client は generate_secret=false なので SECRET_HASH 不要。
    func signIn(email: String, password: String) async throws -> AuthTokens {
        let json = try await call("InitiateAuth", body: [
            "AuthFlow": "USER_PASSWORD_AUTH",
            "ClientId": clientId,
            "AuthParameters": ["USERNAME": email, "PASSWORD": password],
        ])
        return try tokens(from: json, currentRefreshToken: nil)
    }

    /// リフレッシュトークンで ID/Access token を更新する。
    func refresh(refreshToken: String) async throws -> AuthTokens {
        let json = try await call("InitiateAuth", body: [
            "AuthFlow": "REFRESH_TOKEN_AUTH",
            "ClientId": clientId,
            "AuthParameters": ["REFRESH_TOKEN": refreshToken],
        ])
        return try tokens(from: json, currentRefreshToken: refreshToken)
    }

    // MARK: - パスワード再設定

    func forgotPassword(email: String) async throws {
        _ = try await call("ForgotPassword", body: [
            "ClientId": clientId,
            "Username": email,
        ])
    }

    func confirmForgotPassword(email: String, code: String, newPassword: String) async throws {
        _ = try await call("ConfirmForgotPassword", body: [
            "ClientId": clientId,
            "Username": email,
            "ConfirmationCode": code,
            "Password": newPassword,
        ])
    }

    // MARK: - ログアウト

    /// refresh token を Cognito 側で失効させる（secret 不要）。
    /// ローカルのトークン破棄は呼び出し側の責務（失敗しても必ず消すこと）。
    func revokeToken(refreshToken: String) async throws {
        _ = try await call("RevokeToken", body: [
            "Token": refreshToken,
            "ClientId": clientId,
        ])
    }

    // MARK: - 内部

    private func call(_ action: String, body: [String: Any]) async throws -> [String: Any] {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-amz-json-1.1", forHTTPHeaderField: "Content-Type")
        request.setValue("AWSCognitoIdentityProviderService.\(action)", forHTTPHeaderField: "X-Amz-Target")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await httpClient.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw CognitoError(code: "InvalidResponse", message: "通信エラーが発生しました。")
        }

        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]

        guard (200...299).contains(http.statusCode) else {
            let rawType = json["__type"] as? String ?? "UnknownError"
            let code = rawType.split(separator: "#").last.map(String.init) ?? rawType
            throw CognitoError(code: code, message: json["message"] as? String ?? "")
        }

        return json
    }

    /// InitiateAuth のレスポンスを AuthTokens に変換する。
    /// REFRESH_TOKEN_AUTH のレスポンスには RefreshToken が含まれないため、手持ちの値を引き継ぐ。
    private func tokens(from json: [String: Any], currentRefreshToken: String?) throws -> AuthTokens {
        guard let result = json["AuthenticationResult"] as? [String: Any],
              let idToken = result["IdToken"] as? String,
              let accessToken = result["AccessToken"] as? String,
              let expiresIn = result["ExpiresIn"] as? Double,
              let refreshToken = (result["RefreshToken"] as? String) ?? currentRefreshToken else {
            throw CognitoError(code: "NoAuthenticationResult", message: "認証結果が取得できませんでした。")
        }

        return AuthTokens(
            idToken: idToken,
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: Date().addingTimeInterval(expiresIn)
        )
    }
}
