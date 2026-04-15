import SwiftUI

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @State private var displayName = ""
    @State private var email = "guest@example.com"

    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Circle()
                            .fill(Color(.main).opacity(0.10))
                            .frame(width: 92, height: 92)
                            .overlay(
                                Image(systemName: "tortoise.fill")
                                    .font(.system(size: 40, weight: .bold))
                                    .foregroundStyle(Color(.main))
                            )
                        VStack(spacing: 4) {
                            Text("ゲストユーザー")
                                .font(.headline)
                            if let userId = appState.anonymousUserId {
                                Text(userId)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            Section("プロフィール") {
                HStack {
                    Text("表示名")
                    Spacer()
                    TextField("未設定", text: $displayName)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("メール")
                    Spacer()
                    Text(email)
                        .foregroundStyle(.secondary)
                }
            }

            Section("学習記録") {
                HStack {
                    Label("総解答数", systemImage: "number")
                    Spacer()
                    Text("\(appState.totalAnswered)")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Label("正答数", systemImage: "checkmark")
                    Spacer()
                    Text("\(appState.totalCorrect)")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Label("完了した問題集", systemImage: "book.closed")
                    Spacer()
                    Text("\(appState.completedWorkbookIDs.count)")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("プロフィール")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
        NavigationStack {
            ProfileView()
            .environment(AppState.shared)
    }
}
