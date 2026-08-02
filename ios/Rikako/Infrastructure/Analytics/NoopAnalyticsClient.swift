import Foundation

/// 何もしない実装。preview / UI テスト / 計測を無効化したいビルドで使う。
final class NoopAnalyticsClient: AnalyticsClient {
    func log(_ event: AnalyticsEvent) {}
    func setCommonProperties(_ properties: AnalyticsCommonProperties) {}
}
