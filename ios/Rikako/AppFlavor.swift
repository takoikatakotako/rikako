import Foundation

struct AppFlavor {
    let slug: String
    let apiBaseURL: URL
    let contentBaseURL: URL

    static let current = AppFlavor(bundle: .main)

    init(bundle: Bundle) {
        let info = bundle.infoDictionary ?? [:]
        self.slug = info["RIKAKO_APP_SLUG"] as? String ?? "high-school-chemistry"
        self.apiBaseURL = AppFlavor.urlValue(info["RIKAKO_API_BASE_URL"], fallback: "https://api.dev.rikako.jp")
        self.contentBaseURL = AppFlavor.urlValue(info["RIKAKO_CONTENT_BASE_URL"], fallback: "https://content.dev.rikako.jp/v1")
    }

    private static func urlValue(_ value: Any?, fallback: String) -> URL {
        if let string = value as? String, let url = URL(string: string) {
            return url
        }
        return URL(string: fallback)!
    }
}
