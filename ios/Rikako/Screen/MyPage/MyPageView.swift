import SwiftUI

struct MyPageView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = MyPageViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    profileCard
                    shortcutButtons
                    menuList
                    promoRow
                    footerTexts
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("マイページ")
            .navigationBarTitleDisplayMode(.inline)
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
                    Text("かびごん")
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

    private var shortcutButtons: some View {
        HStack(spacing: 12) {
            ForEach(viewModel.shortcutItems) { item in
                shortcutButton(title: item.title, symbol: item.symbol, accentColor: item.color)
            }
        }
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
                badge: "12",
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

    private var promoRow: some View {
        HStack(spacing: 10) {
            promoCard(
                title: "今日のおすすめ\n10問学習を続けよう",
                subtitle: "学習タブへ",
                color: Color(.main).opacity(0.16)
            )
            promoCard(
                title: "理科子をもっと\n使いやすくする",
                subtitle: "お知らせを見る",
                color: Color.orange.opacity(0.12)
            )
        }
    }

    private var footerTexts: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(viewModel.footerItems) { item in
                Text(item.title)
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func shortcutButton(title: String, symbol: String, accentColor: Color) -> some View {
        Button {} label: {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .foregroundStyle(accentColor)
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
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

    private func promoCard(title: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline.bold())
                .foregroundStyle(.primary)
            Spacer()
            Text(subtitle)
                .font(.caption.bold())
                .foregroundStyle(Color(.main))
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .background(color)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.6), lineWidth: 1)
        )
    }
}

#Preview {
    MyPageView()
        .environment(AppState.shared)
}
