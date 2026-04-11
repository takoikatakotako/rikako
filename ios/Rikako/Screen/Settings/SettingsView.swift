import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = SettingsViewModel()

    var body: some View {
        List {
            Section("アカウント") {
                NavigationLink(destination: ProfileView()) {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.title)
                            .foregroundStyle(Color.accentColor)
                        VStack(alignment: .leading) {
                            Text("ゲストユーザー")
                                .font(.headline)
                            Text("プロフィールを編集")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("学習") {
                HStack {
                    Label("解答した問題数", systemImage: "checkmark.circle")
                    Spacer()
                    Text(viewModel.answeredText(totalAnswered: appState.totalAnswered))
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Label("正答率", systemImage: "chart.bar")
                    Spacer()
                    Text(appState.accuracyText)
                        .foregroundStyle(.secondary)
                }
            }

            Section("アプリについて") {
                HStack {
                    Label("バージョン", systemImage: "info.circle")
                    Spacer()
                    Text(viewModel.versionText)
                        .foregroundStyle(.secondary)
                }
                Label("使い方", systemImage: "questionmark.circle")
                Label("レビューする", systemImage: "star")
                Label("理科子さんのTwitter", systemImage: "bird")
            }

            Section {
                Button(role: .destructive) {
                    appState.setLoggedIn(false)
                } label: {
                    Label("ログアウト", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        }
        .navigationTitle("設定")
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environment(AppState.shared)
    }
}
