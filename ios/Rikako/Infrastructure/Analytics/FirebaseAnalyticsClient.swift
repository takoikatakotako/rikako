import FirebaseCore
import FirebaseAnalytics

/// Firebase Analytics 実装（prod フレーバー = Release ビルドで使用）。
///
/// - Note: firebase-ios-sdk 12.x では `FirebaseAnalytics` 単体で IDFA を収集しない
///   （旧 `FirebaseAnalyticsWithoutAdIdSupport` 相当がデフォルト）。IDFA を使う
///   `FirebaseAnalyticsIdentitySupport` は**追加しない**こと。これにより
///   `PrivacyInfo.xcprivacy` の `NSPrivacyTracking=false` を維持する。
final class FirebaseAnalyticsClient: AnalyticsClient {
    /// `GoogleService-Info-<slug>-<environment>.plist` で Firebase を初期化してクライアントを返す。
    /// plist が無い場合は nil（呼び出し側で Console/Noop にフォールバックする）。
    /// - Parameters:
    ///   - slug: `AppFlavor.slug`（`high-school-chemistry` / `it-passport`）
    ///   - environment: `dev`（rikako-dev）または `prod`（rikako-prd）
    static func configured(slug: String, environment: String) -> FirebaseAnalyticsClient? {
        // すでに configure 済みなら再利用（多重 configure を避ける）。
        if FirebaseApp.app() != nil {
            return FirebaseAnalyticsClient()
        }
        guard let path = Bundle.main.path(forResource: "GoogleService-Info-\(slug)-\(environment)", ofType: "plist"),
              let options = FirebaseOptions(contentsOfFile: path) else {
            return nil
        }
        FirebaseApp.configure(options: options)
        return FirebaseAnalyticsClient()
    }

    func log(_ event: AnalyticsEvent) {
        Analytics.logEvent(event.name, parameters: event.parameters)
    }

    func setCommonProperties(_ properties: AnalyticsCommonProperties) {
        for (key, value) in properties.asUserProperties {
            Analytics.setUserProperty(value, forName: key)
        }
    }
}
