import Foundation

final class RemoteLearningRepository: LearningRepository {
    private let contentBaseURL = URL(string: "https://content.dev.rikako.jp/v1")!
    private let apiBaseURL = URL(string: "https://api.dev.rikako.jp")!

    private let httpClient: HTTPClient
    private let deviceIdentityProvider: DeviceIdentityProviding
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
    private let encoder = JSONEncoder()

    init(httpClient: HTTPClient, deviceIdentityProvider: DeviceIdentityProviding) {
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
        return result.workbooks
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
        let deviceId = try await deviceIdentityProvider.getIdentityId()
        request.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")
        request.setValue(appSlug, forHTTPHeaderField: "X-App-Slug")

        let (data, response) = try await httpClient.data(for: request)
        try validateResponse(response)
        return try decoder.decode(UserProfile.self, from: data)
    }

    func updateUserProfile(appSlug: String, request: UpdateUserProfileRequest) async throws -> UserProfile {
        let url = apiBaseURL.appendingPathComponent("users/me")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "PUT"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let deviceId = try await deviceIdentityProvider.getIdentityId()
        urlRequest.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")
        urlRequest.setValue(appSlug, forHTTPHeaderField: "X-App-Slug")
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await httpClient.data(for: urlRequest)
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

    private func getJSON<T: Decodable>(url: URL, authenticated: Bool) async throws -> T {
        var request = URLRequest(url: url)
        if authenticated {
            let deviceId = try await deviceIdentityProvider.getIdentityId()
            request.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")
        }

        let (data, response) = try await httpClient.data(for: request)
        try validateResponse(response)
        return try decoder.decode(T.self, from: data)
    }

    private func postJSON<T: Decodable, B: Encodable>(url: URL, body: B, authenticated: Bool) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if authenticated {
            let deviceId = try await deviceIdentityProvider.getIdentityId()
            request.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")
        }
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await httpClient.data(for: request)
        try validateResponse(response)
        return try decoder.decode(T.self, from: data)
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
