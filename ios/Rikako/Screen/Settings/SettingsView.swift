import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = SettingsViewModel()
    @State private var session = AppContainer.shared.accountSession
    @State private var showRestartOnboardingConfirmation = false
    @State private var showSignOutConfirmation = false
    @State private var showLogin = false
    @State private var linkErrorMessage: String?
    @State private var versionTapCount = 0
    @State private var showDebug = false
    @AppStorage(UserPreferencesKey.soundEnabled) private var isSoundEnabled = true
    @AppStorage(UserPreferencesKey.hapticEnabled) private var isHapticEnabled = true

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                accountCard
                feedbackCard
                aboutCard
                restartOnboardingButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationTitle("設定")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .navigationDestination(isPresented: $showDebug) {
            DebugView()
        }
        .navigationDestination(isPresented: $showLogin) {
            LoginView(onLoggedIn: {
                showLogin = false
                Task { await linkAccount() }
            })
        }
        .alert("学習記録の引き継ぎ", isPresented: .constant(linkErrorMessage != nil)) {
            Button("OK") { linkErrorMessage = nil }
        } message: {
            Text(linkErrorMessage ?? "")
        }
        .alert("ログアウト", isPresented: $showSignOutConfirmation) {
            Button("キャンセル", role: .cancel) {}
            Button("ログアウト", role: .destructive) {
                Task { await session.signOut() }
            }
        } message: {
            Text("ログアウトしても、この端末の学習データは残ります。")
        }
        .alert("初期設定をやり直す", isPresented: $showRestartOnboardingConfirmation) {
            Button("キャンセル", role: .cancel) {}
            Button("やり直す") {
                appState.resetToInitialState()
            }
        } message: {
            Text("オンボーディングから設定をやり直します。学習記録は削除されず、同じ端末の記録として復元されます。ログイン中の場合、ログイン状態もそのまま保たれます。")
        }
    }

    private var feedbackCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("サウンド・フィードバック")

            VStack(spacing: 0) {
                toggleRow(symbol: "speaker.wave.2.fill", title: "効果音", accentColor: .purple, isOn: $isSoundEnabled)
                Divider().padding(.leading, 48)
                toggleRow(symbol: "hand.tap.fill", title: "触覚フィードバック", accentColor: .orange, isOn: $isHapticEnabled)
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("アプリについて")

            VStack(spacing: 0) {
                infoRow(symbol: "info.circle.fill", title: "バージョン", trailing: viewModel.versionText, accentColor: .blue)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        versionTapCount += 1
                        if versionTapCount >= 3 {
                            versionTapCount = 0
                            showDebug = true
                        }
                    }
                Divider().padding(.leading, 48)
                NavigationLink {
                    NotificationsView()
                } label: {
                    infoRow(symbol: "bell.fill", title: "お知らせ", accentColor: .orange)
                }
                .buttonStyle(.plain)
                Divider().padding(.leading, 48)
                infoRow(symbol: "questionmark.circle.fill", title: "使い方", accentColor: Color(.main))
                Divider().padding(.leading, 48)
                infoRow(symbol: "star.fill", title: "レビューする", accentColor: .orange)
                Divider().padding(.leading, 48)
                infoRow(symbol: "bird", title: "理科子さんのTwitter", accentColor: .pink)
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }

    /// ログイン直後にこの端末の匿名データをアカウントへ紐付ける（冪等）。
    /// 失敗してもログイン自体は成立しているので、通知だけしてセッションは維持する。
    private func linkAccount() async {
        do {
            try await AppContainer.shared.learningUseCases.linkAccount.execute()
        } catch {
            linkErrorMessage = "ログインはできましたが、この端末の学習記録の引き継ぎに失敗しました。通信環境の良い場所で、もう一度ログインし直してください。"
        }
    }

    /// アカウント欄。未ログインなら任意ログインへの導線、ログイン中はメールアドレスとログアウト。
    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("アカウント")

            VStack(spacing: 0) {
                if session.isLoggedIn {
                    infoRow(
                        symbol: "person.crop.circle.fill",
                        title: "メールアドレス",
                        trailing: session.email ?? "-",
                        accentColor: Color(.main)
                    )
                    Divider().padding(.leading, 48)
                    Button {
                        showSignOutConfirmation = true
                    } label: {
                        infoRow(
                            symbol: "rectangle.portrait.and.arrow.right",
                            title: "ログアウト",
                            trailing: "",
                            accentColor: .red
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        showLogin = true
                    } label: {
                        infoRow(
                            symbol: "person.crop.circle.badge.plus",
                            title: "ログイン / アカウント作成",
                            accentColor: Color(.main)
                        )
                    }
                    .buttonStyle(.plain)

                    Text("ログインすると、機種変更しても学習記録を引き継げます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }

    /// オンボーディングをやり直すだけのボタン。データ削除ではないので破壊的な見た目にはしない。
    private var restartOnboardingButton: some View {
        Button {
            showRestartOnboardingConfirmation = true
        } label: {
            HStack {
                Image(systemName: "arrow.counterclockwise")
                Text("初期設定をやり直す")
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.secondary.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline.bold())
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func toggleRow(symbol: String, title: String, accentColor: Color, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.subheadline.bold())
                .foregroundStyle(accentColor)
                .frame(width: 28, height: 28)
                .background(accentColor.opacity(0.10))
                .clipShape(Circle())

            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func infoRow(symbol: String, title: String, trailing: String? = nil, accentColor: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.subheadline.bold())
                .foregroundStyle(accentColor)
                .frame(width: 28, height: 28)
                .background(accentColor.opacity(0.10))
                .clipShape(Circle())

            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            Spacer()

            if let trailing {
                Text(trailing)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environment(AppState.shared)
    }
}
