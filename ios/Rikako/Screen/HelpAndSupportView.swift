import SwiftUI

struct HelpAndSupportView: View {
    @State private var showContactForm = false

    var body: some View {
        List {
            Section("よくある質問") {
                faqRow(question: "学習記録はどこで見られますか？", answer: "下部タブの「学習記録」から確認できます。")
                faqRow(question: "選ぶ問題集は後から変更できますか？", answer: "マイページではなく、学習タブの「教材を切り替える」から変更できます。")
                faqRow(question: "ログインしなくても使えますか？", answer: "はい。今はログインなしでも基本的な学習機能を使えます。")
            }

            Section("お問い合わせ") {
                Button {
                    showContactForm = true
                } label: {
                    Label("お問い合わせフォーム", systemImage: "envelope")
                }
            }
        }
        .navigationTitle("よくある質問・お問い合わせ")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showContactForm) {
            ContactFormView()
        }
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

private struct ContactFormView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var subject = ""
    @State private var messageBody = ""
    @State private var isSending = false
    @State private var showSuccessAlert = false
    @State private var errorMessage: String?

    private var canSend: Bool {
        !messageBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("件名（任意）") {
                    TextField("件名を入力", text: $subject)
                }

                Section("お問い合わせ内容") {
                    TextEditor(text: $messageBody)
                        .frame(minHeight: 160)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("お問い合わせ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSending {
                        ProgressView()
                    } else {
                        Button("送信") { sendContact() }
                            .disabled(!canSend)
                    }
                }
            }
            .alert("送信完了", isPresented: $showSuccessAlert) {
                Button("OK") { dismiss() }
            } message: {
                Text("お問い合わせを受け付けました。内容を確認の上、ご連絡いたします。")
            }
        }
    }

    private func sendContact() {
        let trimmedSubject = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = messageBody.trimmingCharacters(in: .whitespacesAndNewlines)

        isSending = true
        errorMessage = nil

        Task {
            do {
                try await AppContainer.shared.learningUseCases.submitContact.execute(
                    subject: trimmedSubject.isEmpty ? nil : trimmedSubject,
                    body: trimmedBody
                )
                await MainActor.run {
                    isSending = false
                    showSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    isSending = false
                    errorMessage = "送信に失敗しました。時間をおいて再度お試しください。"
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        HelpAndSupportView()
    }
}
