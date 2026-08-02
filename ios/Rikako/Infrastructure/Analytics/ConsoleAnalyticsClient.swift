import Foundation
import OSLog

/// DEBUG ビルドでイベントをコンソール出力する実装。Firebase 結線前でも導線を確認できる。
final class ConsoleAnalyticsClient: AnalyticsClient {
    private let logger = Logger(subsystem: "org.rikako.analytics", category: "event")

    func log(_ event: AnalyticsEvent) {
        if event.parameters.isEmpty {
            logger.debug("event: \(event.name, privacy: .public)")
        } else {
            logger.debug("event: \(event.name, privacy: .public) \(String(describing: event.parameters), privacy: .public)")
        }
    }

    func setCommonProperties(_ properties: AnalyticsCommonProperties) {
        logger.debug("common: \(properties.asUserProperties, privacy: .public)")
    }
}
