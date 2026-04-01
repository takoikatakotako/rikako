import Foundation

final class APIClient {
    static let shared = APIClient()

    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    private init() {
        self.baseURL = URL(string: "https://content.dev.rikako.jp/v1")!
        self.session = .shared
        self.decoder = JSONDecoder()
    }

    func fetchWorkbooks() async throws -> [Workbook] {
        let url = baseURL.appendingPathComponent("workbooks.json")
        let (data, response) = try await session.data(from: url)
        try validateResponse(response)
        let result = try decoder.decode(WorkbooksResponse.self, from: data)
        return result.workbooks
    }

    func fetchWorkbookDetail(id: Int64) async throws -> WorkbookDetail {
        let url = baseURL.appendingPathComponent("workbooks/\(id).json")
        let (data, response) = try await session.data(from: url)
        try validateResponse(response)
        return try decoder.decode(WorkbookDetail.self, from: data)
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
