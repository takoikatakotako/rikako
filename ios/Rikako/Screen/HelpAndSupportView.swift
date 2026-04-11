import SwiftUI

struct HelpAndSupportView: View {
    var body: some View {
        List {
            Section("よくある質問") {
                faqRow(question: "学習記録はどこで見られますか？", answer: "下部タブの「学習記録」から確認できます。")
                faqRow(question: "選ぶ問題集は後から変更できますか？", answer: "マイページではなく、学習タブの「教材を切り替える」から変更できます。")
                faqRow(question: "ログインしなくても使えますか？", answer: "はい。今はログインなしでも基本的な学習機能を使えます。")
            }

            Section("お問い合わせ") {
                LabeledContent("メール", value: "support@rikako.jp")
                LabeledContent("受付時間", value: "平日 10:00 - 18:00")
            }
        }
        .navigationTitle("よくある質問・お問い合わせ")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func faqRow(question: String, answer: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(question)
                .font(.headline)
            Text(answer)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        HelpAndSupportView()
    }
}
