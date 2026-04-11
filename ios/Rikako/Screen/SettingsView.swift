import SwiftUI

struct SettingsView: View {
    @Environment(StudyStore.self) private var studyStore

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
                    Text("\(studyStore.totalAnswered)問")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Label("正答率", systemImage: "chart.bar")
                    Spacer()
                    Text(studyStore.accuracyText)
                        .foregroundStyle(.secondary)
                }
            }

            Section("アプリについて") {
                HStack {
                    Label("バージョン", systemImage: "info.circle")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }
                Label("使い方", systemImage: "questionmark.circle")
                Label("レビューする", systemImage: "star")
                Label("理科子さんのTwitter", systemImage: "bird")
            }

            Section {
                Button(role: .destructive) {
                    studyStore.setLoggedIn(false)
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
            .environment(StudyStore.shared)
    }
}
