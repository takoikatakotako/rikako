import Foundation
import Observation

@Observable
@MainActor
final class MyPageViewModel {
    struct ShortcutItem: Identifiable {
        let id: String
        let title: String
        let symbol: String
    }

    struct FooterItem: Identifiable {
        let id: String
        let title: String
    }

    let shortcutItems: [ShortcutItem] = [
        .init(id: "exam", title: "実力テスト", symbol: "trophy"),
        .init(id: "ranking", title: "ランキング", symbol: "crown")
    ]

    let footerItems: [FooterItem] = [
        .init(id: "school", title: "学校・塾向けの学習プランのご紹介"),
        .init(id: "recruit", title: "理科子を一緒に育てるメンバー募集中")
    ]
}
