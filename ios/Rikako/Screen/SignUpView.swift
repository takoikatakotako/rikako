import SwiftUI

struct SignUpView: View {
    var onLoggedIn: () -> Void = {}

    @State private var session = AppContainer.shared.accountSession
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var showConfirmCode = false

    private var canSubmit: Bool {
        !email.isEmpty && !password.isEmpty && !confirmPassword.isEmpty && !isLoading
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.accentColor)
                    .padding(.top, 32)

                Text("入力したメールアドレスに確認コードを送ります。")
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

                    SecureField("パスワード", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.newPassword)

                    SecureField("パスワード（確認）", text: $confirmPassword)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.newPassword)
                }
                .padding(.horizontal, 32)

                Text("パスワードは8文字以上で、大文字・小文字・数字・記号を含めてください。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Button {
                    Task { await signUp() }
                } label: {
                    ZStack {
                        Text("アカウントを作成")
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
            }
            .padding(.bottom, 32)
        }
        .navigationTitle("アカウント作成")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .navigationDestination(isPresented: $showConfirmCode) {
            ConfirmCodeView(email: email, password: password, onLoggedIn: onLoggedIn)
        }
    }

    private func signUp() async {
        guard password == confirmPassword else {
            errorMessage = "パスワードが一致しません。"
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await session.signUp(email: email.trimmingCharacters(in: .whitespaces), password: password)
            showConfirmCode = true
        } catch let error as CognitoError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "通信エラーが発生しました。"
        }
    }
}

#Preview {
    NavigationStack {
        SignUpView()
    }
}
