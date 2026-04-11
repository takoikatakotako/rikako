import SwiftUI

struct NotificationsView: View {
    struct NotificationItem: Identifiable {
        let id: Int
        let title: String
        let body: String
        let date: String
        let isUnread: Bool
    }

    private let notifications: [NotificationItem] = [
        .init(id: 1, title: "春のチャレンジ応援キャンペーン", body: "期間限定で学習を続けやすい企画を実施中です。", date: "4/12", isUnread: true),
        .init(id: 2, title: "新しい問題集を追加しました", body: "基礎化学の復習に使いやすい問題集を追加しました。", date: "4/10", isUnread: true),
        .init(id: 3, title: "アップデートのお知らせ", body: "マイページと学習記録画面を改善しました。", date: "4/08", isUnread: false)
    ]

    var body: some View {
        List(notifications) { item in
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(item.isUnread ? Color.orange : Color(.systemGray4))
                    .frame(width: 10, height: 10)
                    .padding(.top, 6)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(item.title)
                            .font(.headline)
                        Spacer()
                        Text(item.date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(item.body)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 6)
        }
        .navigationTitle("お知らせ")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        NotificationsView()
    }
}
