import SwiftUI

/// パスワード再設定。コード送信 → コード + 新パスワードで確定、の2段階を1画面で行う。
struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var session = AppContainer.shared.accountSession
    @State private var email: String
    @State private var code = ""
    @State private var newPassword = ""
    @State private var hasSentCode = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?
    @State private var isLoading = false

    init(email: String = "") {
        _email = State(initialValue: email)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "key")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.accentColor)
                    .padding(.top, 32)

                Text(hasSentCode
                     ? "メールに届いた確認コードと、新しいパスワードを入力してください。"
                     : "登録済みのメールアドレスに確認コードを送ります。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                VStack(spacing: 16) {
                    TextField("メールアドレス", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .disabled(hasSentCode)

                    if hasSentCode {
                        TextField("確認コード", text: $code)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)

                        SecureField("新しいパスワード", text: $newPassword)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.newPassword)
                    }
                }
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
                    Task { hasSentCode ? await confirmReset() : await sendCode() }
                } label: {
                    ZStack {
                        Text(hasSentCode ? "パスワードを変更する" : "確認コードを送る")
                            .font(.headline)
                            .opacity(isLoading ? 0 : 1)
                        if isLoading {
                            ProgressView().tint(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isLoading ? Color.gray.opacity(0.4) : Color.accentColor)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
                }
                .disabled(isLoading)
                .padding(.horizontal, 32)
            }
            .padding(.bottom, 32)
        }
        .navigationTitle("パスワードの再設定")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
    }

    private func sendCode() async {
        isLoading = true
        errorMessage = nil
        infoMessage = nil
        defer { isLoading = false }

        do {
            try await session.forgotPassword(email: email.trimmingCharacters(in: .whitespaces))
            hasSentCode = true
            infoMessage = "確認コードを送信しました。"
        } catch let error as CognitoError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "通信エラーが発生しました。"
        }
    }

    private func confirmReset() async {
        isLoading = true
        errorMessage = nil
        infoMessage = nil
        defer { isLoading = false }

        do {
            try await session.confirmForgotPassword(
                email: email.trimmingCharacters(in: .whitespaces),
                code: code.trimmingCharacters(in: .whitespaces),
                newPassword: newPassword
            )
            dismiss()
        } catch let error as CognitoError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "通信エラーが発生しました。"
        }
    }
}

#Preview {
    NavigationStack {
        ForgotPasswordView()
    }
}
