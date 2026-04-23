import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class MyPageViewModel {
    struct ShortcutItem: Identifiable {
        let id: String
        let title: String
        let symbol: String
        let colorHexName: String

        var color: Color {
            Color(colorHexName)
        }
    }

    struct FooterItem: Identifiable {
        let id: String
        let title: String
    }

    let shortcutItems: [ShortcutItem] = [
        .init(id: "exam", title: "実力テスト", symbol: "trophy", colorHexName: "main"),
        .init(id: "ranking", title: "ランキング", symbol: "crown", colorHexName: "correctPink")
    ]

    let footerItems: [FooterItem] = [
        .init(id: "school", title: "学校・塾向けの学習プランのご紹介"),
        .init(id: "recruit", title: "理科子を一緒に育てるメンバー募集中")
    ]

    private(set) var announcementUnreadCount: Int = 0

    private let fetchAnnouncements: FetchAnnouncementsUseCase
    private let readStore: AnnouncementReadStore

    init(
        fetchAnnouncements: FetchAnnouncementsUseCase = AppContainer.shared.learningUseCases.fetchAnnouncements,
        readStore: AnnouncementReadStore = AnnouncementReadStore()
    ) {
        self.fetchAnnouncements = fetchAnnouncements
        self.readStore = readStore
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
