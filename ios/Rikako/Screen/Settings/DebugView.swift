import SwiftUI

struct DebugView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        List {
            Section("ユーザー情報") {
                row(title: "User ID", value: appState.userId.map { String($0) } ?? "未設定")
                row(title: "Identity ID", value: appState.anonymousUserId ?? "未設定")
                row(title: "表示名", value: appState.displayName ?? "未設定")
            }

            Section("アプリ情報") {
                row(title: "バージョン", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-")
                row(title: "ビルド番号", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-")
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
