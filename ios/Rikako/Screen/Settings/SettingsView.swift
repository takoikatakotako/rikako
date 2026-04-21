import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = SettingsViewModel()
    @State private var showLogoutConfirmation = false
    @State private var versionTapCount = 0
    @State private var showDebug = false
    @AppStorage(UserPreferencesKey.soundEnabled) private var isSoundEnabled = true
    @AppStorage(UserPreferencesKey.hapticEnabled) private var isHapticEnabled = true

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                feedbackCard
                aboutCard
                logoutButton
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
        .alert("ログアウト", isPresented: $showLogoutConfirmation) {
            Button("キャンセル", role: .cancel) {}
            Button("ログアウト", role: .destructive) {
                appState.resetToInitialState()
            }
        } message: {
            Text("ログアウトすると学習データがリセットされます。よろしいですか？")
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

    private var logoutButton: some View {
        Button(role: .destructive) {
            showLogoutConfirmation = true
        } label: {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("ログアウト")
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red.opacity(0.10))
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
