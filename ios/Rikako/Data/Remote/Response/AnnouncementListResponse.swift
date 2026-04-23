import Foundation

struct AnnouncementListResponse: Codable {
    let announcements: [Announcement]
    let total: Int
}
