import Foundation

/// POST /account/link のレスポンス。
struct AccountLink: Decodable, Equatable {
    let accountId: Int64
    let email: String?
}
