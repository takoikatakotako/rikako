import SwiftUI

struct NotificationDetailView: View {
    let announcement: Announcement

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    categoryBadge
                    Text(dateText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(announcement.title)
                    .font(.title2.bold())

                Divider()

                MarkdownView(markdown: announcement.body)
                    .foregroundStyle(.primary)
            }
            .padding(20)
        }
        .navigationTitle("お知らせ")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var categoryBadge: some View {
        Text(NotificationCategoryStyle.label(for: announcement.category))
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(NotificationCategoryStyle.color(for: announcement.category).opacity(0.15))
            .foregroundStyle(NotificationCategoryStyle.color(for: announcement.category))
            .clipShape(Capsule())
    }

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: announcement.publishedAt)
    }
}

enum NotificationCategoryStyle {
    static func label(for category: String) -> String {
        switch category {
        case "release": return "リリース"
        case "maintenance": return "メンテナンス"
        case "info": return "お知らせ"
        default: return category
        }
    }

    static func color(for category: String) -> Color {
        switch category {
        case "release": return .green
        case "maintenance": return .red
        case "info": return .orange
        default: return .gray
        }
    }
}

#Preview {
    NavigationStack {
        NotificationDetailView(
            announcement: Announcement(
                id: 1,
                title: "新しい問題集を追加しました",
                body: "基礎化学の復習に使いやすい問題集を追加しました。ぜひ使ってみてください。",
                category: "release",
                publishedAt: Date()
            )
        )
    }
}
