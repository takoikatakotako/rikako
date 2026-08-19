import Foundation
import Security

/// Cognito User Pool のトークン一式。`portal/src/lib/tokens.ts` の AuthTokens と同じ構成。
struct AuthTokens: Codable, Equatable {
    let idToken: String
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date

    /// 期限切れ判定。時計ずれと通信時間を見込んで 60 秒手前で切れたものとして扱う。
    func isExpired(now: Date = Date()) -> Bool {
        now.addingTimeInterval(60) >= expiresAt
    }
}

protocol AuthTokenStoring {
    func load() -> AuthTokens?
    func save(_ tokens: AuthTokens)
    func clear()
}

/// Keychain にトークンを保存する。匿名 identity 用の `KeychainIdentityStore` と同じ流儀
/// （kSecClassGenericPassword + AfterFirstUnlock）に揃えている。
struct KeychainAuthTokenStore: AuthTokenStoring {
    private let keychainKey = "jp.conol.rikako.authTokens"

    func load() -> AuthTokens? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return try? JSONDecoder().decode(AuthTokens.self, from: data)
    }

    func save(_ tokens: AuthTokens) {
        guard let data = try? JSONEncoder().encode(tokens) else { return }

        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

/// テスト・プレビュー用のメモリ保管。
final class InMemoryAuthTokenStore: AuthTokenStoring {
    private var tokens: AuthTokens?

    init(tokens: AuthTokens? = nil) {
        self.tokens = tokens
    }

    func load() -> AuthTokens? { tokens }
    func save(_ tokens: AuthTokens) { self.tokens = tokens }
    func clear() { tokens = nil }
}
