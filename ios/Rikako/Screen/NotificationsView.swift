import SwiftUI

struct NotificationsView: View {
    @State private var viewModel = NotificationsViewModel(
        fetchAnnouncements: AppContainer.shared.learningUseCases.fetchAnnouncements
    )

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                loadingView
            case .failed(let message):
                errorView(message: message)
            case .loaded:
                if viewModel.announcements.isEmpty {
                    emptyView
                } else {
                    list
                }
            }
        }
        .navigationTitle("お知らせ")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    private var loadingView: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text(message)
                .foregroundStyle(.secondary)
            Button("再読み込み") {
                Task { await viewModel.load() }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.slash")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("お知らせはありません")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var list: some View {
        List(viewModel.announcements) { item in
            NavigationLink {
                NotificationDetailView(announcement: item)
                    .onAppear { viewModel.markRead(item) }
            } label: {
                row(for: item)
            }
        }
        .listStyle(.plain)
    }

    private func row(for item: Announcement) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(viewModel.isUnread(item) ? Color.orange : Color(.systemGray4))
                .frame(width: 10, height: 10)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(NotificationCategoryStyle.label(for: item.category))
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(NotificationCategoryStyle.color(for: item.category).opacity(0.15))
                        .foregroundStyle(NotificationCategoryStyle.color(for: item.category))
                        .clipShape(Capsule())
                    Spacer()
                    Text(shortDate(item.publishedAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(item.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(item.body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 6)
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        NotificationsView()
    }
}
