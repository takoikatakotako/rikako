import Foundation
import Security

protocol DeviceIdentityProviding {
    func getIdentityId() async throws -> String
}

final class CognitoDeviceIdentityProvider: DeviceIdentityProviding {
    private let identityPoolId = "ap-northeast-1:51acc74e-ec8d-4de4-bfa1-84648ea45222"
    private let region = "ap-northeast-1"

    private let session: URLSession
    private let keychainStore: KeychainIdentityStore
    private var cachedIdentityId: String?

    init(session: URLSession, keychainStore: KeychainIdentityStore) {
        self.session = session
        self.keychainStore = keychainStore
        self.cachedIdentityId = keychainStore.load()
    }

    func getIdentityId() async throws -> String {
        if let cachedIdentityId {
            return cachedIdentityId
        }

        let identityId = try await fetchIdentityId()
        keychainStore.save(identityId)
        cachedIdentityId = identityId
        return identityId
    }

    private func fetchIdentityId() async throws -> String {
        let endpoint = URL(string: "https://cognito-identity.\(region).amazonaws.com/")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-amz-json-1.1", forHTTPHeaderField: "Content-Type")
        request.setValue("AWSCognitoIdentityService.GetId", forHTTPHeaderField: "X-Amz-Target")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["IdentityPoolId": identityPoolId])

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw DeviceIdentityError.fetchFailed
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let identityId = json["IdentityId"] as? String else {
            throw DeviceIdentityError.invalidResponse
        }

        return identityId
    }
}

struct KeychainIdentityStore {
    private let keychainKey = "jp.conol.rikako.identityId"

    func load() -> String? {
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

    func save(_ value: String) {
        let data = Data(value.utf8)

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
