import Foundation
import Testing
@testable import Rikako

/// cognito-idp のレスポンスを差し替えるスタブ。送られたリクエストを検証用に控える。
private nonisolated final class StubHTTPClient: HTTPClient {
    var requests: [URLRequest] = []
    var statusCode: Int
    var responseBody: [String: Any]

    init(statusCode: Int = 200, responseBody: [String: Any] = [:]) {
        self.statusCode = statusCode
        self.responseBody = responseBody
    }

    func data(from url: URL) async throws -> (Data, URLResponse) {
        try await data(for: URLRequest(url: url))
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        let data = try JSONSerialization.data(withJSONObject: responseBody)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (data, response)
    }
}

private func authenticationResult(
    refreshToken: String? = "refresh-1",
    expiresIn: Int = 3600
) -> [String: Any] {
    var result: [String: Any] = [
        "IdToken": "id-1",
        "AccessToken": "access-1",
        "ExpiresIn": expiresIn,
    ]
    if let refreshToken {
        result["RefreshToken"] = refreshToken
    }
    return ["AuthenticationResult": result]
}

private func body(of request: URLRequest) -> [String: Any] {
    let data = request.httpBody ?? Data()
    return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
}

struct CognitoUserPoolClientTests {
    private static let clientId = "test-client-id"

    private func makeClient(_ stub: StubHTTPClient) -> CognitoUserPoolClient {
        CognitoUserPoolClient(httpClient: stub, clientId: Self.clientId, region: "ap-northeast-1")
    }

    /// SignUp は X-Amz-Target と email 属性を正しく組み立てる。
    @Test func signUpSendsExpectedRequest() async throws {
        let stub = StubHTTPClient()
        try await makeClient(stub).signUp(email: "a@example.com", password: "Passw0rd!")

        let request = try #require(stub.requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://cognito-idp.ap-northeast-1.amazonaws.com/")
        #expect(
            request.value(forHTTPHeaderField: "X-Amz-Target")
                == "AWSCognitoIdentityProviderService.SignUp"
        )
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/x-amz-json-1.1")

        let sent = body(of: request)
        #expect(sent["ClientId"] as? String == Self.clientId)
        #expect(sent["Username"] as? String == "a@example.com")
        #expect(sent["Password"] as? String == "Passw0rd!")
        let attributes = sent["UserAttributes"] as? [[String: String]]
        #expect(attributes?.first?["Name"] == "email")
        #expect(attributes?.first?["Value"] == "a@example.com")
        // App Client は generate_secret=false なので SECRET_HASH は送らない。
        #expect(sent["SecretHash"] == nil)
    }

    /// ログインは USER_PASSWORD_AUTH で、トークンと有効期限を組み立てる。
    @Test func signInReturnsTokens() async throws {
        let stub = StubHTTPClient(responseBody: authenticationResult())
        let tokens = try await makeClient(stub).signIn(email: "a@example.com", password: "Passw0rd!")

        let sent = body(of: try #require(stub.requests.first))
        #expect(sent["AuthFlow"] as? String == "USER_PASSWORD_AUTH")
        let parameters = sent["AuthParameters"] as? [String: String]
        #expect(parameters?["USERNAME"] == "a@example.com")
        #expect(parameters?["PASSWORD"] == "Passw0rd!")

        #expect(tokens.idToken == "id-1")
        #expect(tokens.accessToken == "access-1")
        #expect(tokens.refreshToken == "refresh-1")
        #expect(tokens.expiresAt > Date())
    }

    /// REFRESH_TOKEN_AUTH のレスポンスに RefreshToken が無くても、手持ちの値を引き継ぐ。
    @Test func refreshCarriesOverRefreshToken() async throws {
        let stub = StubHTTPClient(responseBody: authenticationResult(refreshToken: nil))
        let tokens = try await makeClient(stub).refresh(refreshToken: "refresh-existing")

        let sent = body(of: try #require(stub.requests.first))
        #expect(sent["AuthFlow"] as? String == "REFRESH_TOKEN_AUTH")
        #expect((sent["AuthParameters"] as? [String: String])?["REFRESH_TOKEN"] == "refresh-existing")

        #expect(tokens.refreshToken == "refresh-existing")
        #expect(tokens.idToken == "id-1")
    }

    /// AuthenticationResult が無いレスポンスはエラーにする（黙って壊れたトークンを保存しない）。
    @Test func missingAuthenticationResultThrows() async throws {
        let stub = StubHTTPClient(responseBody: [:])
        await #expect(throws: CognitoError.self) {
            _ = try await makeClient(stub).signIn(email: "a@example.com", password: "Passw0rd!")
        }
    }

    /// エラーレスポンスは __type の `#` 以降をコードとして取り出す。
    @Test func errorTypeIsParsed() async throws {
        let stub = StubHTTPClient(
            statusCode: 400,
            responseBody: [
                "__type": "com.amazonaws.cognito.identity.model#UsernameExistsException",
                "message": "User already exists",
            ]
        )

        do {
            try await makeClient(stub).signUp(email: "a@example.com", password: "Passw0rd!")
            Issue.record("エラーが投げられなかった")
        } catch let error as CognitoError {
            #expect(error.code == "UsernameExistsException")
            #expect(error.errorDescription == "このメールアドレスは既に登録されています。")
        }
    }

    /// client ID が未設定なら、Cognito に投げる前に設定不備として弾く。
    @Test func missingClientIdIsRejectedBeforeRequest() async throws {
        let stub = StubHTTPClient()
        let client = CognitoUserPoolClient(httpClient: stub, clientId: "", region: "ap-northeast-1")

        await #expect(throws: CognitoError(code: "MissingClientId", message: "アプリの設定に問題があります。")) {
            try await client.signUp(email: "a@example.com", password: "Passw0rd!")
        }
        #expect(stub.requests.isEmpty)
    }

    /// 既知のエラーコードは日本語文言に、未知のコードはサーバー文言にフォールバックする。
    @Test func japaneseMessages() {
        #expect(
            CognitoError(code: "CodeMismatchException", message: "x").errorDescription
                == "確認コードが正しくありません。"
        )
        #expect(
            CognitoError(code: "NotAuthorizedException", message: "x").errorDescription
                == "メールアドレスまたはパスワードが正しくありません。"
        )
        #expect(
            CognitoError(code: "TooManyRequestsException", message: "x").errorDescription
                == "試行回数が多すぎます。しばらくしてから再度お試しください。"
        )
        #expect(
            CognitoError(code: "SomethingNewException", message: "生の文言").errorDescription == "生の文言"
        )
        #expect(
            CognitoError(code: "SomethingNewException", message: "").errorDescription == "エラーが発生しました。"
        )
        #expect(
            CognitoError(code: "MissingClientId", message: "x").errorDescription == "アプリの設定に問題があります。"
        )
    }
}

struct AuthTokensTests {
    /// 期限まで 60 秒を切ったトークンは期限切れ扱い（時計ずれと通信時間のマージン）。
    @Test func expiryHasLeeway() {
        let now = Date()
        func tokens(expiresIn: TimeInterval) -> AuthTokens {
            AuthTokens(
                idToken: "id",
                accessToken: "access",
                refreshToken: "refresh",
                expiresAt: now.addingTimeInterval(expiresIn)
            )
        }

        #expect(tokens(expiresIn: 3600).isExpired(now: now) == false)
        #expect(tokens(expiresIn: 30).isExpired(now: now) == true)
        #expect(tokens(expiresIn: -1).isExpired(now: now) == true)
    }

    /// Keychain へは JSON で保存するため、往復して同じ値に戻る。
    @Test func codableRoundTrip() throws {
        let original = AuthTokens(
            idToken: "id",
            accessToken: "access",
            refreshToken: "refresh",
            expiresAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let decoded = try JSONDecoder().decode(
            AuthTokens.self,
            from: JSONEncoder().encode(original)
        )
        #expect(decoded == original)
    }
}
