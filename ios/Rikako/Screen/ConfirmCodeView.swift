import SwiftUI

/// メール確認コードの入力画面。確認が通ったらそのままログインまで済ませる
/// （パスワードは直前の画面から引き継ぐ。持っていない場合はログイン画面に戻す）。
struct ConfirmCodeView: View {
    let email: String
    /// サインアップ/ログイン画面から引き継いだパスワード。確認後の自動ログインに使う。
    var password: String?
    var onLoggedIn: () -> Void = {}

    @State private var session = AppContainer.shared.accountSession
    @State private var code = ""
    @State private var errorMessage: String?
    @State private var infoMessage: String?
    @State private var isLoading = false
    @State private var isResending = false

    private var canSubmit: Bool { !code.isEmpty && !isLoading }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "envelope.badge")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.accentColor)
                    .padding(.top, 32)

                Text("\(email) に送られた確認コードを入力してください。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                TextField("確認コード", text: $code)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .padding(.horizontal, 32)

                if let infoMessage {
                    Text(infoMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Button {
                    Task { await confirm() }
                } label: {
                    ZStack {
                        Text("確認する")
                            .font(.headline)
                            .opacity(isLoading ? 0 : 1)
                        if isLoading {
                            ProgressView().tint(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canSubmit ? Color.accentColor : Color.gray.opacity(0.4))
                    .foregroundStyle(.white)
                    .cornerRadius(12)
                }
                .disabled(!canSubmit)
                .padding(.horizontal, 32)

                Button {
                    Task { await resend() }
                } label: {
                    if isResending {
                        ProgressView()
                    } else {
                        Text("確認コードを再送する")
                    }
                }
                .font(.subheadline)
                .disabled(isResending)
            }
            .padding(.bottom, 32)
        }
        .navigationTitle("メールの確認")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
    }

    private func confirm() async {
        isLoading = true
        errorMessage = nil
        infoMessage = nil
        defer { isLoading = false }

        do {
            try await session.confirmSignUp(email: email, code: code.trimmingCharacters(in: .whitespaces))
        } catch let error as CognitoError {
            errorMessage = error.errorDescription
            return
        } catch {
            errorMessage = "通信エラーが発生しました。"
            return
        }

        // 確認が通ったので、そのままログインまで済ませる。
        guard let password, !password.isEmpty else {
            infoMessage = "確認が完了しました。ログイン画面からログインしてください。"
            return
        }

        do {
            try await session.signIn(email: email, password: password)
            onLoggedIn()
        } catch {
            infoMessage = "確認が完了しました。ログイン画面からログインしてください。"
        }
    }

    private func resend() async {
        isResending = true
        errorMessage = nil
        infoMessage = nil
        defer { isResending = false }

        do {
            try await session.resendConfirmationCode(email: email)
            infoMessage = "確認コードを再送しました。"
        } catch let error as CognitoError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "通信エラーが発生しました。"
        }
    }
}

#Preview {
    NavigationStack {
        ConfirmCodeView(email: "test@example.com", password: nil)
    }
}
