import SwiftUI

struct MyPageView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = MyPageViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    profileCard
                    menuList
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("マイページ")
            .navigationBarTitleDisplayMode(.inline)
            .task { await viewModel.refreshAnnouncementUnreadCount() }
        }
    }

    private var profileCard: some View {
        NavigationLink(destination: ProfileView()) {
            HStack(spacing: 14) {
                Circle()
                    .fill(Color(.main).opacity(0.10))
                    .frame(width: 58, height: 58)
                    .overlay(
                        Image(systemName: "tortoise.fill")
                            .font(.title2)
                            .foregroundStyle(Color(.main))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(appState.displayName ?? "ゲストユーザー")
                        .font(.headline.bold())
                        .foregroundStyle(.primary)
                    Text(appState.anonymousUserId == nil ? "ゲストユーザー" : "無料会員")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(
                LinearGradient(
                    colors: [Color.white, Color(.main).opacity(0.06)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color(.main).opacity(0.10), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var menuList: some View {
        VStack(spacing: 0) {
            menuLinkRow(
                symbol: "gearshape",
                title: "設定",
                accentColor: Color(.main),
                destination: AnyView(SettingsView())
            )
            Divider().padding(.leading, 48)
            menuLinkRow(
                symbol: "bell",
                title: "お知らせ",
                badge: viewModel.announcementUnreadCount > 0 ? "\(viewModel.announcementUnreadCount)" : nil,
                accentColor: .orange,
                destination: AnyView(NotificationsView())
            )
            Divider().padding(.leading, 48)
            menuLinkRow(
                symbol: "questionmark.bubble",
                title: "よくある質問・お問い合わせ",
                accentColor: .blue,
                destination: AnyView(HelpAndSupportView())
            )
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(.main).opacity(0.08), lineWidth: 1)
        )
    }

    private func menuLinkRow(symbol: String, title: String, badge: String? = nil, accentColor: Color, destination: AnyView) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(accentColor)
                    .frame(width: 28, height: 28)
                    .background(accentColor.opacity(0.10))
                    .clipShape(Circle())
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                if let badge {
                    Text(badge)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Color.orange)
                        .clipShape(Capsule())
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
        }
    }


}

#Preview {
    MyPageView()
        .environment(AppState.shared)
}
