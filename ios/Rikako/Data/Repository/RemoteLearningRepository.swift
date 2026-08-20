import Foundation

final class RemoteLearningRepository: LearningRepository {
    private let flavor: AppFlavor
    private let contentBaseURL: URL
    private let apiBaseURL: URL
    private let httpClient: HTTPClient
    private let deviceIdentityProvider: DeviceIdentityProviding
    /// ログイン中のみ ID token を返す。未設定（ローカル/CI）なら常に匿名。
    private let tokenProvider: AuthTokenProviding?
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
    private let encoder = JSONEncoder()

    init(
        flavor: AppFlavor,
        httpClient: HTTPClient,
        deviceIdentityProvider: DeviceIdentityProviding,
        tokenProvider: AuthTokenProviding? = nil
    ) {
        self.tokenProvider = tokenProvider
        self.flavor = flavor
        self.contentBaseURL = flavor.contentBaseURL
        self.apiBaseURL = flavor.apiBaseURL
        self.httpClient = httpClient
        self.deviceIdentityProvider = deviceIdentityProvider
    }

    func fetchAppStatus() async throws -> AppStatusResponse {
        let url = apiBaseURL.appendingPathComponent("status")
        return try await getJSON(url: url, authenticated: false)
    }

    func fetchWorkbooks() async throws -> [Workbook] {
        let url = contentBaseURL.appendingPathComponent("workbooks.json")
        let (data, response) = try await httpClient.data(from: url)
        try validateResponse(response)
        let result = try decoder.decode(WorkbookListResponse.self, from: data)
        let app = try await fetchAppDetail()
        let categoryIDs = Set(app.categories.map(\.id))
        return result.workbooks.filter { workbook in
            guard let categoryID = workbook.categoryId else { return false }
            return categoryIDs.contains(categoryID)
        }
    }

    func fetchWorkbookDetail(id: Int64) async throws -> WorkbookDetail {
        let url = contentBaseURL.appendingPathComponent("workbooks/\(id).json")
        let (data, response) = try await httpClient.data(from: url)
        try validateResponse(response)
        return try decoder.decode(WorkbookDetail.self, from: data)
    }

    func fetchCategories(limit: Int, offset: Int) async throws -> [Category] {
        var components = URLComponents(url: apiBaseURL.appendingPathComponent("categories"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]
        let url = components.url!
        let result: CategoryListResponse = try await getJSON(url: url, authenticated: false)
        return result.categories
    }

    private func fetchAppDetail() async throws -> AppDetail {
        let url = apiBaseURL
            .appendingPathComponent("apps")
            .appendingPathComponent(flavor.slug)
        return try await getJSON(url: url, authenticated: false)
    }

    func fetchCategoryDetail(id: Int64) async throws -> CategoryDetail {
        let url = apiBaseURL.appendingPathComponent("categories/\(id)")
        return try await getJSON(url: url, authenticated: false)
    }

    func submitAnswers(workbookId: Int64, answers: [AnswerItem]) async throws -> AnswerSubmissionResponse {
        let url = apiBaseURL.appendingPathComponent("answers")
        let body = AnswerSubmissionRequest(workbookId: workbookId, answers: answers)
        return try await postJSON(url: url, body: body, authenticated: true)
    }

    func anonymousSignIn() async throws -> String {
        let url = apiBaseURL.appendingPathComponent("auth/anonymous/sign-in")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await httpClient.data(for: request)
        try validateResponse(response)

        struct SignInResponse: Decodable { let identityId: String }
        let result = try decoder.decode(SignInResponse.self, from: data)
        return result.identityId
    }

    func fetchUserProfile(appSlug: String) async throws -> UserProfile {
        let url = apiBaseURL.appendingPathComponent("users/me")
        var request = URLRequest(url: url)
        request.setValue(appSlug, forHTTPHeaderField: "X-App-Slug")

        let (data, response) = try await sendAuthenticated(request)
        try validateResponse(response)
        return try decoder.decode(UserProfile.self, from: data)
    }

    func updateUserProfile(appSlug: String, request: UpdateUserProfileRequest) async throws -> UserProfile {
        let url = apiBaseURL.appendingPathComponent("users/me")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "PUT"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(appSlug, forHTTPHeaderField: "X-App-Slug")
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await sendAuthenticated(urlRequest)
        try validateResponse(response)
        return try decoder.decode(UserProfile.self, from: data)
    }

    func fetchWorkbookProgress(workbookId: Int64) async throws -> WorkbookProgressResponse {
        var components = URLComponents(url: apiBaseURL.appendingPathComponent("users/me/workbook-progress"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "workbook_id", value: "\(workbookId)")]
        return try await getJSON(url: components.url!, authenticated: true)
    }

    func fetchUserSummary() async throws -> UserSummary {
        let url = apiBaseURL.appendingPathComponent("users/me/summary")
        return try await getJSON(url: url, authenticated: true)
    }

    func fetchAnswerLogs(limit: Int, offset: Int) async throws -> AnswerLogsResponse {
        var components = URLComponents(url: apiBaseURL.appendingPathComponent("users/me/answer-logs"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]
        let url = components.url!
        return try await getJSON(url: url, authenticated: true)
    }

    func fetchAnnouncements() async throws -> [Announcement] {
        let url = contentBaseURL.appendingPathComponent("announcements.json")
        let (data, response) = try await httpClient.data(from: url)
        try validateResponse(response)
        let result = try decoder.decode(AnnouncementListResponse.self, from: data)
        return result.announcements
    }

    func fetchWrongAnswers(limit: Int, offset: Int) async throws -> WrongAnswerListResponse {
        var components = URLComponents(url: apiBaseURL.appendingPathComponent("users/me/wrong-answers"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]
        let url = components.url!
        return try await getJSON(url: url, authenticated: true)
    }


    /// 認証ヘッダーを付けて送る。ログイン中は Authorization も付け、401 なら
    /// 1度だけ refresh して再試行する。
    ///
    /// トークン取得が throw した場合はそのまま伝播させる（匿名リクエストへ
    /// フォールバックしない）。降格させると、ログイン中の学習記録が
    /// X-Device-ID 側へ書かれてアカウントと匿名行にデータが分岐するため。
    private func sendAuthenticated(_ original: URLRequest) async throws -> (Data, URLResponse) {
        var request = original
        let deviceId = try await deviceIdentityProvider.getIdentityId()
        request.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")

        let idToken = try await tokenProvider?.validIdToken()
        if let idToken {
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await httpClient.data(for: request)

        // ログイン中に 401 が返るのは、期限内でもトークンが失効している場合。
        // 1度だけ refresh して再試行する。
        guard idToken != nil,
              let http = response as? HTTPURLResponse,
              http.statusCode == 401,
              let refreshed = try await tokenProvider?.forceRefresh() else {
            return (data, response)
        }

        var retry = request
        retry.setValue("Bearer \(refreshed)", forHTTPHeaderField: "Authorization")
        return try await httpClient.data(for: retry)
    }

    /// ログイン中のアカウントに、この端末の匿名データを紐付ける（冪等）。
    /// device id が既に別アカウントへ紐付いている場合は 409 になるので、
    /// 新しい identity を取り直して1度だけやり直す。
    func linkAccount() async throws -> AccountLink {
        do {
            return try await postAccountLink()
        } catch APIError.httpError(409) {
            _ = try await deviceIdentityProvider.rotateIdentityId()
            return try await postAccountLink()
        }
    }

    private func postAccountLink() async throws -> AccountLink {
        let url = apiBaseURL.appendingPathComponent("account/link")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(flavor.slug, forHTTPHeaderField: "X-App-Slug")
        request.httpBody = try encoder.encode([String: String]())

        let (data, response) = try await sendAuthenticated(request)
        try validateResponse(response)
        return try decoder.decode(AccountLink.self, from: data)
    }

    private func getJSON<T: Decodable>(url: URL, authenticated: Bool) async throws -> T {
        var request = URLRequest(url: url)
        // X-App-Slug は常に送る。/status はアプリ別の minimumVersion/latestVersion を
        // 返せるように slug を必要とする（強制アップデートをアプリ単位で制御するため）。
        request.setValue(flavor.slug, forHTTPHeaderField: "X-App-Slug")

        let (data, response) = authenticated
            ? try await sendAuthenticated(request)
            : try await httpClient.data(for: request)
        try validateResponse(response)
        return try decoder.decode(T.self, from: data)
    }

    private func postJSON<T: Decodable, B: Encodable>(url: URL, body: B, authenticated: Bool) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if authenticated {
            request.setValue(flavor.slug, forHTTPHeaderField: "X-App-Slug")
        }
        request.httpBody = try encoder.encode(body)

        let (data, response) = authenticated
            ? try await sendAuthenticated(request)
            : try await httpClient.data(for: request)
        try validateResponse(response)
        return try decoder.decode(T.self, from: data)
    }

    func fetchTransferToken() async throws -> TransferToken {
        let url = apiBaseURL.appendingPathComponent("transfer/token")
        var request = URLRequest(url: url)
        let deviceId = try await deviceIdentityProvider.getIdentityId()
        request.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")

        let (data, response) = try await httpClient.data(for: request)
        try validateResponse(response)

        struct Response: Decodable {
            let token: String
            let expires_at: Date
        }
        let result = try decoder.decode(Response.self, from: data)
        return TransferToken(token: result.token, expiresAt: result.expires_at)
    }

    func refreshTransferToken() async throws -> TransferToken {
        let url = apiBaseURL.appendingPathComponent("transfer/token")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let deviceId = try await deviceIdentityProvider.getIdentityId()
        request.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")

        let (data, response) = try await httpClient.data(for: request)
        try validateResponse(response)

        struct Response: Decodable {
            let token: String
            let expires_at: Date
        }
        let result = try decoder.decode(Response.self, from: data)
        return TransferToken(token: result.token, expiresAt: result.expires_at)
    }

    func chatWithQuestion(questionId: Int64, messages: [ChatMessageRequest], selectedChoice: Int) async throws -> ChatResponse {
        let url = apiBaseURL.appendingPathComponent("questions/\(questionId)/chat")
        return try await postJSON(url: url, body: ChatRequest(messages: messages, selectedChoice: selectedChoice), authenticated: true)
    }

    func submitContact(subject: String?, body: String, email: String?, userId: String?, deviceModel: String?, osVersion: String?, appVersion: String?) async throws {
        let url = apiBaseURL.appendingPathComponent("contact")
        struct Body: Encodable {
            let subject: String?
            let body: String
            let email: String?
            let userId: String?
            let deviceModel: String?
            let osVersion: String?
            let appVersion: String?
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let deviceId = try await deviceIdentityProvider.getIdentityId()
        request.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")
        request.httpBody = try encoder.encode(Body(subject: subject, body: body, email: email, userId: userId, deviceModel: deviceModel, osVersion: osVersion, appVersion: appVersion))
        let (_, response) = try await httpClient.data(for: request)
        try validateResponse(response)
    }

    func applyTransferToken(_ token: String) async throws -> String {
        let url = apiBaseURL.appendingPathComponent("transfer/apply")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let deviceId = try await deviceIdentityProvider.getIdentityId()
        request.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")

        struct Body: Encodable { let token: String }
        request.httpBody = try encoder.encode(Body(token: token))

        let (data, response) = try await httpClient.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            if (String(data: data, encoding: .utf8) ?? "").contains("SAME_DEVICE") {
                throw APIError.sameDevice
            }
            throw APIError.httpError(http.statusCode)
        }

        struct Response: Decodable { let identity_id: String }
        let result = try decoder.decode(Response.self, from: data)
        return result.identity_id
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw APIError.httpError(http.statusCode)
        }
    }
}
