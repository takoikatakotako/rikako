import Foundation
import Testing
@testable import Rikako

/// 応答を順番に返すスタブ。送られたリクエストは検証用に控える。
private final class SequenceHTTPClient: HTTPClient, @unchecked Sendable {
    var responses: [(status: Int, body: [String: Any])]
    private(set) var requests: [URLRequest] = []

    init(responses: [(status: Int, body: [String: Any])]) {
        self.responses = responses
    }

    func data(from url: URL) async throws -> (Data, URLResponse) {
        try await data(for: URLRequest(url: url))
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        let next = responses.isEmpty
            ? (status: 500, body: [String: Any]())
            : responses.removeFirst()
        let data = try JSONSerialization.data(withJSONObject: next.body)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: next.status,
            httpVersion: nil,
            headerFields: nil
        )!
        return (data, response)
    }
}

private final class StubDeviceIdentityProvider: DeviceIdentityProviding, @unchecked Sendable {
    var identityId: String
    private(set) var rotateCallCount = 0

    init(identityId: String = "device-1") {
        self.identityId = identityId
    }

    func getIdentityId() async throws -> String { identityId }
    func overrideIdentityId(_ id: String) { identityId = id }

    func rotateIdentityId() async throws -> String {
        rotateCallCount += 1
        identityId = "device-\(rotateCallCount + 1)"
        return identityId
    }
}

private final class StubTokenProvider: AuthTokenProviding, @unchecked Sendable {
    var idToken: String?
    var validError: Error?
    var forceRefreshResult: String?
    private(set) var forceRefreshCallCount = 0

    init(idToken: String? = nil) {
        self.idToken = idToken
    }

    func validIdToken() async throws -> String? {
        if let validError { throw validError }
        return idToken
    }

    func forceRefresh() async throws -> String? {
        forceRefreshCallCount += 1
        if let forceRefreshResult {
            idToken = forceRefreshResult
        }
        return forceRefreshResult
    }
}

private func makeRepository(
    http: SequenceHTTPClient,
    device: StubDeviceIdentityProvider = StubDeviceIdentityProvider(),
    token: StubTokenProvider? = nil
) -> RemoteLearningRepository {
    RemoteLearningRepository(
        flavor: AppFlavor(bundle: .main),
        httpClient: http,
        deviceIdentityProvider: device,
        tokenProvider: token
    )
}

struct RemoteLearningRepositoryAuthTests {
    /// 未ログインなら従来どおり X-Device-ID だけを送る。
    @Test func anonymousRequestSendsOnlyDeviceId() async throws {
        let http = SequenceHTTPClient(responses: [(200, ["accountId": 1])])
        let repository = makeRepository(http: http, token: StubTokenProvider(idToken: nil))

        _ = try? await repository.linkAccount()

        let request = try #require(http.requests.first)
        #expect(request.value(forHTTPHeaderField: "X-Device-ID") == "device-1")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    }

    /// ログイン中は Authorization を付ける。X-Device-ID も従来どおり送る。
    @Test func loggedInRequestSendsBearerToken() async throws {
        let http = SequenceHTTPClient(responses: [(200, ["accountId": 1])])
        let repository = makeRepository(http: http, token: StubTokenProvider(idToken: "id-token-1"))

        _ = try await repository.linkAccount()

        let request = try #require(http.requests.first)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer id-token-1")
        #expect(request.value(forHTTPHeaderField: "X-Device-ID") == "device-1")
    }

    /// 401 なら1度だけ refresh して、新しいトークンで再試行する。
    @Test func retriesOnceWithRefreshedTokenOn401() async throws {
        let http = SequenceHTTPClient(responses: [(401, [:]), (200, ["accountId": 1])])
        let token = StubTokenProvider(idToken: "old-token")
        token.forceRefreshResult = "new-token"
        let repository = makeRepository(http: http, token: token)

        let result = try await repository.linkAccount()

        #expect(result.accountId == 1)
        #expect(token.forceRefreshCallCount == 1)
        #expect(http.requests.count == 2)
        #expect(http.requests[0].value(forHTTPHeaderField: "Authorization") == "Bearer old-token")
        #expect(http.requests[1].value(forHTTPHeaderField: "Authorization") == "Bearer new-token")
    }

    /// 再試行も 401 ならそれ以上繰り返さない（無限ループにしない）。
    @Test func doesNotRetryTwiceOn401() async throws {
        let http = SequenceHTTPClient(responses: [(401, [:]), (401, [:])])
        let token = StubTokenProvider(idToken: "old-token")
        token.forceRefreshResult = "new-token"
        let repository = makeRepository(http: http, token: token)

        await #expect(throws: APIError.httpError(401)) {
            _ = try await repository.linkAccount()
        }
        #expect(http.requests.count == 2)
        #expect(token.forceRefreshCallCount == 1)
    }

    /// トークン取得が throw したら、匿名リクエストへフォールバックせず失敗させる。
    /// 降格させると、ログイン中の学習記録が匿名側に書かれてデータが分岐するため。
    @Test func doesNotFallBackToAnonymousWhenTokenThrows() async throws {
        let http = SequenceHTTPClient(responses: [(200, ["accountId": 1])])
        let token = StubTokenProvider(idToken: "id-token-1")
        token.validError = AccountSessionError.sessionExpired
        let repository = makeRepository(http: http, token: token)

        await #expect(throws: AccountSessionError.sessionExpired) {
            _ = try await repository.linkAccount()
        }
        #expect(http.requests.isEmpty, "リクエストが匿名で送られてしまっている")
    }

    /// 409（この端末が別アカウントに紐付いている）なら device id を取り直して1度だけやり直す。
    @Test func rotatesDeviceIdOnConflict() async throws {
        let http = SequenceHTTPClient(responses: [(409, [:]), (200, ["accountId": 2])])
        let device = StubDeviceIdentityProvider()
        let repository = makeRepository(
            http: http,
            device: device,
            token: StubTokenProvider(idToken: "id-token-1")
        )

        let result = try await repository.linkAccount()

        #expect(result.accountId == 2)
        #expect(device.rotateCallCount == 1)
        #expect(http.requests.count == 2)
        #expect(http.requests[0].value(forHTTPHeaderField: "X-Device-ID") == "device-1")
        #expect(http.requests[1].value(forHTTPHeaderField: "X-Device-ID") == "device-2")
    }

    /// 409 が続く場合はローテーションを繰り返さない。
    @Test func rotatesOnlyOnceOnRepeatedConflict() async throws {
        let http = SequenceHTTPClient(responses: [(409, [:]), (409, [:])])
        let device = StubDeviceIdentityProvider()
        let repository = makeRepository(
            http: http,
            device: device,
            token: StubTokenProvider(idToken: "id-token-1")
        )

        await #expect(throws: APIError.httpError(409)) {
            _ = try await repository.linkAccount()
        }
        #expect(device.rotateCallCount == 1)
    }
}
