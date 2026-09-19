import Foundation

/// 複数の `AnalyticsClient` に同じイベントをファンアウトする。
/// dev では Console（コンソール即確認）と Firebase(sandbox-492513。GA4 未リンクのため DebugView は見えない) の両方に流すために使う。
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
