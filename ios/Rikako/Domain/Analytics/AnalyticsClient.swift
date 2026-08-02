import Foundation

/// 利用イベント計測の抽象。実装は差し替え可能（Firebase / Noop / Console / テスト用 spy）。
protocol AnalyticsClient {
    /// イベントを記録する。
    func log(_ event: AnalyticsEvent)
    /// バージョン別・アプリ別に比較するための共通プロパティを設定する。
    func setCommonProperties(_ properties: AnalyticsCommonProperties)
}

/// 全イベントに付与する共通プロパティ。個人を識別しない値のみ。
struct AnalyticsCommonProperties {
    let appVersion: String
    let appBuild: String
    let appSlug: String
    let osVersion: String

    var asUserProperties: [String: String] {
        [
            "app_version": appVersion,
            "app_build": appBuild,
            "app_slug": appSlug,
            "os_version": osVersion,
        ]
    }
}
