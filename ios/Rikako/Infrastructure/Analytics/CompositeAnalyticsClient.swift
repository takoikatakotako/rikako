import Foundation

/// 複数の `AnalyticsClient` に同じイベントをファンアウトする。
/// dev では Console（コンソール即確認）と Firebase(rikako-dev, DebugView 検証) の両方に流すために使う。
final class CompositeAnalyticsClient: AnalyticsClient {
    private let clients: [AnalyticsClient]

    init(_ clients: [AnalyticsClient]) {
        self.clients = clients
    }

    func log(_ event: AnalyticsEvent) {
        clients.forEach { $0.log(event) }
    }

    func setCommonProperties(_ properties: AnalyticsCommonProperties) {
        clients.forEach { $0.setCommonProperties(properties) }
    }
}
