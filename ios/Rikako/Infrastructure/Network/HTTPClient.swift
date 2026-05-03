import Foundation

protocol HTTPClient {
    func data(from url: URL) async throws -> (Data, URLResponse)
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

struct URLSessionHTTPClient: HTTPClient {
    let session: URLSession

    func data(from url: URL) async throws -> (Data, URLResponse) {
        try await session.data(from: url)
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }
}

enum APIError: LocalizedError {
    case invalidResponse
    case httpError(Int)
    case sameDevice

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "サーバーからの応答が不正です"
        case .httpError(let code):
            return "サーバーエラー (HTTP \(code))"
        case .sameDevice:
            return "自分のデバイスのQRコードは使用できません"
        }
    }
}
