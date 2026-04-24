import Foundation
import Observation

@Observable
@MainActor
final class NotificationsViewModel {
    enum LoadState {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    private(set) var announcements: [Announcement] = []
    private(set) var state: LoadState = .idle
    private(set) var readIDs: Set<Int64> = []

    private let fetchAnnouncements: FetchAnnouncementsUseCase
    private let readStore: AnnouncementReadStore

    init(
        fetchAnnouncements: FetchAnnouncementsUseCase,
        readStore: AnnouncementReadStore = AnnouncementReadStore()
    ) {
        self.fetchAnnouncements = fetchAnnouncements
        self.readStore = readStore
    }

    var unreadCount: Int {
        announcements.filter { isUnread($0) }.count
    }

    func isUnread(_ announcement: Announcement) -> Bool {
        announcement.isWithinUnreadWindow() && !readIDs.contains(announcement.id)
    }

    func load() async {
        state = .loading
        do {
            let fetched = try await fetchAnnouncements.execute()
            announcements = fetched
            readStore.prune(existingIDs: Set(fetched.map { $0.id }))
            readIDs = Set(fetched.map { $0.id }.filter { readStore.isRead(id: $0) })
            state = .loaded
        } catch {
            state = .failed("お知らせの取得に失敗しました")
        }
    }

    func markRead(_ announcement: Announcement) {
        guard !readIDs.contains(announcement.id) else { return }
        readStore.markRead(id: announcement.id)
        readIDs.insert(announcement.id)
    }
}
