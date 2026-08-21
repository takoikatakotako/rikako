import Foundation

struct AppFlavor {
    let slug: String
    let apiBaseURL: URL
    let contentBaseURL: URL
    /// Cognito User Pool の App Client ID（環境ごとに異なる）。generate_secret=false なので公開値でよい。
    let cognitoClientId: String
    /// Cognito Identity Pool の ID（匿名認証用。環境ごとに異なる）。
    let cognitoIdentityPoolId: String

    static let current = AppFlavor(bundle: .main)

    /// App Store のアプリ ID。iOS 版が未公開のフレーバーは nil。
    var appStoreID: String? {
        switch slug {
        case "high-school-chemistry": return "960647263"
        default: return nil // it-passport は iOS 版未公開
        }
    }

    /// App Store ページの URL（未公開フレーバーは nil）。
    var appStoreURL: URL? {
        appStoreID.flatMap { URL(string: "https://apps.apple.com/jp/app/id\($0)") }
    }

    init(bundle: Bundle) {
        let info = bundle.infoDictionary ?? [:]
        self.slug = info["RIKAKO_APP_SLUG"] as? String ?? "high-school-chemistry"
        self.apiBaseURL = AppFlavor.urlValue(info["RIKAKO_API_BASE_URL"], fallback: "https://api.dev.rikako.org")
        self.contentBaseURL = AppFlavor.urlValue(info["RIKAKO_CONTENT_BASE_URL"], fallback: "https://content.dev.rikako.org/v1")
        self.cognitoClientId = info["RIKAKO_COGNITO_CLIENT_ID"] as? String ?? ""
        self.cognitoIdentityPoolId = info["RIKAKO_COGNITO_IDENTITY_POOL_ID"] as? String ?? ""
    }

    private static func urlValue(_ value: Any?, fallback: String) -> URL {
        if let string = value as? String, let url = URL(string: string) {
            return url
        }
        return URL(string: fallback)!
    }
}
