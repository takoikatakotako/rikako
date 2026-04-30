import Foundation
import Observation

@Observable
@MainActor
final class MyPageViewModel {
    private(set) var announcementUnreadCount: Int = 0

    private let fetchAnnouncements: FetchAnnouncementsUseCase
    private let readStore: AnnouncementReadStore

    init(
        fetchAnnouncements: FetchAnnouncementsUseCase? = nil,
        readStore: AnnouncementReadStore? = nil
    ) {
        self.fetchAnnouncements = fetchAnnouncements ?? AppContainer.shared.learningUseCases.fetchAnnouncements
        self.readStore = readStore ?? AnnouncementReadStore()
    }

    func refreshAnnouncementUnreadCount() async {
        do {
            let fetched = try await fetchAnnouncements.execute()
            announcementUnreadCount = fetched.filter { announcement in
                announcement.isWithinUnreadWindow() && !readStore.isRead(id: announcement.id)
            }.count
        } catch {
            announcementUnreadCount = 0
        }
    }
}
