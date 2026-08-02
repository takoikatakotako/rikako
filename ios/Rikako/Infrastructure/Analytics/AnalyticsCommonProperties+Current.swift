import UIKit

extension AnalyticsCommonProperties {
    /// 実行中のアプリ/端末から共通プロパティを組み立てる。
    static func current(flavor: AppFlavor = .current, bundle: Bundle = .main) -> AnalyticsCommonProperties {
        let info = bundle.infoDictionary ?? [:]
        return AnalyticsCommonProperties(
            appVersion: info["CFBundleShortVersionString"] as? String ?? "unknown",
            appBuild: info["CFBundleVersion"] as? String ?? "unknown",
            appSlug: flavor.slug,
            osVersion: UIDevice.current.systemVersion
        )
    }
}
