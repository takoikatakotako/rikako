import Foundation

final class APIClient {
    static let shared = APIClient()

    private let contentBaseURL: URL
    private let apiBaseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    private init() {
        self.contentBaseURL = URL(string: "https://content.dev.rikako.jp/v1")!
        self.apiBaseURL = URL(string: "https://api.dev.rikako.jp")!
        self.session = .shared
        self.decoder = JSONDecoder()
    }

    // MARK: - Content (Static JSON from CloudFront)

    func fetchWorkbooks() async throws -> [Workbook] {
        let url = contentBaseURL.appendingPathComponent("workbooks.json")
        let (data, response) = try await session.data(from: url)
        try validateResponse(response)
        let result = try decoder.decode(WorkbooksResponse.self, from: data)
        return result.workbooks
    }

    func fetchWorkbookDetail(id: Int64) async throws -> WorkbookDetail {
        let url = contentBaseURL.appendingPathComponent("workbooks/\(id).json")
        let (data, response) = try await session.data(from: url)
        try validateResponse(response)
        return try decoder.decode(WorkbookDetail.self, from: data)
    }

    // MARK: - Answers (Public API Lambda)

    func submitAnswers(workbookId: Int64, answers: [AnswerItem]) async throws -> SubmitAnswersResponse {
        let url = apiBaseURL.appendingPathComponent("answers")
        let body = SubmitAnswersRequest(workbookId: workbookId, answers: answers)
        return try await postJSON(url: url, body: body, authenticated: true)
    }

    func fetchWrongAnswers(limit: Int = 50, offset: Int = 0) async throws -> WrongAnswersResponse {
        var components = URLComponents(url: apiBaseURL.appendingPathComponent("users/me/wrong-answers"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)"),
        ]
        let url = components.url!
        return try await getJSON(url: url, authenticated: true)
    }

    // MARK: - Private

    private func getJSON<T: Decodable>(url: URL, authenticated: Bool) async throws -> T {
        var request = URLRequest(url: url)
        if authenticated {
            let deviceId = try await DeviceIdentity.shared.getIdentityId()
            request.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")
        }
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        return try decoder.decode(T.self, from: data)
    }

    private func postJSON<T: Decodable, B: Encodable>(url: URL, body: B, authenticated: Bool) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if authenticated {
            let deviceId = try await DeviceIdentity.shared.getIdentityId()
            request.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")
        }
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await session.data(for: request)
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

enum APIError: LocalizedError {
    case invalidResponse
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "サーバーからの応答が不正です"
        case .httpError(let code):
            return "サーバーエラー (HTTP \(code))"
        }
    }
}
