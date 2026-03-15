import SwiftUI

struct SettingsView: View {
    @Binding var isLoggedIn: Bool
    @AppStorage("selectedCategory") private var selectedCategoryRaw = ""

    private var selectedCategory: Category? {
        Category(rawValue: selectedCategoryRaw)
    }

    var body: some View {
        List {
            Section("カテゴリ") {
                Picker("学習カテゴリ", selection: $selectedCategoryRaw) {
                    ForEach(Category.allCases) { category in
                        Label(category.displayName, systemImage: category.icon)
                            .tag(category.rawValue)
                    }
                }
            }

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
                    Text("0問")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Label("正答率", systemImage: "chart.bar")
                    Spacer()
                    Text("--%")
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
                Label("利用規約", systemImage: "doc.text")
                Label("プライバシーポリシー", systemImage: "hand.raised")
            }

            Section {
                Button(role: .destructive) {
                    isLoggedIn = false
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
        SettingsView(isLoggedIn: .constant(true))
    }
}
