import SwiftUI

struct ProfileView: View {
    @State private var displayName = ""
    @State private var email = "guest@example.com"

    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(Color.accentColor)
                        Text("ゲストユーザー")
                            .font(.headline)
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
                    Text("0")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Label("正答数", systemImage: "checkmark")
                    Spacer()
                    Text("0")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Label("完了した問題集", systemImage: "book.closed")
                    Spacer()
                    Text("0")
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
    }
}
