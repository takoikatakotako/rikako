import Foundation
import Security

/// Manages anonymous device identity using Cognito Identity Pool.
/// Identity ID is persisted in Keychain to survive app reinstalls.
final class DeviceIdentity {
    static let shared = DeviceIdentity()

    private let identityPoolId = "ap-northeast-1:51acc74e-ec8d-4de4-bfa1-84648ea45222"
    private let region = "ap-northeast-1"
    private let keychainKey = "jp.conol.rikako.identityId"

    private var cachedIdentityId: String?

    private init() {
        cachedIdentityId = loadFromKeychain()
    }

    /// Returns the device's Identity ID, fetching from Cognito if needed.
    func getIdentityId() async throws -> String {
        if let cached = cachedIdentityId {
            return cached
        }

        let identityId = try await fetchIdentityId()
        saveToKeychain(identityId)
        cachedIdentityId = identityId
        return identityId
    }

    // MARK: - Cognito Identity API

    private func fetchIdentityId() async throws -> String {
        let endpoint = URL(string: "https://cognito-identity.\(region).amazonaws.com/")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-amz-json-1.1", forHTTPHeaderField: "Content-Type")
        request.setValue("AWSCognitoIdentityService.GetId", forHTTPHeaderField: "X-Amz-Target")

        let body: [String: Any] = ["IdentityPoolId": identityPoolId]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw DeviceIdentityError.fetchFailed
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let identityId = json["IdentityId"] as? String else {
            throw DeviceIdentityError.invalidResponse
        }

        return identityId
    }

    // MARK: - Keychain

    private func loadFromKeychain() -> String? {
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

        return String(data: data, encoding: .utf8)
    }

    private func saveToKeychain(_ value: String) {
        let data = Data(value.utf8)

        // Delete existing item
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new item
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }
}

enum DeviceIdentityError: LocalizedError {
    case fetchFailed
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .fetchFailed:
            return "デバイスIDの取得に失敗しました"
        case .invalidResponse:
            return "デバイスIDのレスポンスが不正です"
        }
    }
}
