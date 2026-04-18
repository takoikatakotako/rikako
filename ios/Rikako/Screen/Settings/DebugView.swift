import SwiftUI

struct DebugView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        List {
            Section("ユーザー") {
                row(title: "User ID", value: appState.userId.map { String($0) } ?? "未設定")
                row(title: "Identity ID", value: appState.anonymousUserId ?? "未設定")
                row(title: "表示名", value: appState.displayName ?? "未設定")
            }

            Section("コンテンツ") {
                NavigationLink(destination: DebugWorkbooksView()) {
                    Label("問題集", systemImage: "books.vertical")
                }
                NavigationLink(destination: DebugLearningLogView()) {
                    Label("学習ログ", systemImage: "square.and.pencil")
                }
            }
        }
        .navigationTitle("デバッグ")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .font(.caption)
                .textSelection(.enabled)
        }
    }
}

#Preview {
    NavigationStack {
        DebugView()
            .environment(AppState.shared)
    }
}
