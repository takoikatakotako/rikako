import Foundation

struct Announcement: Identifiable, Codable, Hashable {
    let id: Int64
    let title: String
    let body: String
    let category: String
    let publishedAt: Date
}

extension Announcement {
    /// 公開日から7日以内かどうか。
    func isWithinUnreadWindow(now: Date = Date()) -> Bool {
        let sevenDays: TimeInterval = 7 * 24 * 60 * 60
        return now.timeIntervalSince(publishedAt) < sevenDays
    }
}
