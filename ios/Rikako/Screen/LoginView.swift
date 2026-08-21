import SwiftUI

struct LoginView: View {
    /// ログイン完了時に呼ばれる。呼び出し側で画面を閉じる。
    var onLoggedIn: () async -> Void = {}

    @State private var session = AppContainer.shared.accountSession
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var pendingConfirmation = false
    @State private var showSignUp = false
    @State private var showForgotPassword = false

    private var canSubmit: Bool {
        !email.isEmpty && !password.isEmpty && !isLoading
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.accentColor)
                    .padding(.top, 32)

                Text("ログインすると、機種変更しても学習記録を引き継げます。")
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
                        .textContentType(.password)
                }
                .padding(.horizontal, 32)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Button {
                    Task { await login() }
                } label: {
                    ZStack {
                        Text("ログイン")
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

                Button("パスワードをお忘れですか？") {
                    showForgotPassword = true
                }
                .font(.subheadline)

                Button("アカウントをお持ちでない方はこちら") {
                    showSignUp = true
                }
                .font(.subheadline)
            }
            .padding(.bottom, 32)
        }
        .navigationTitle("ログイン")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .navigationDestination(isPresented: $showSignUp) {
            SignUpView(onLoggedIn: onLoggedIn)
        }
        .navigationDestination(isPresented: $showForgotPassword) {
            ForgotPasswordView(email: email)
        }
        // 未確認ユーザーがログインを試みた場合は、確認コード入力へ送る。
        .navigationDestination(isPresented: $pendingConfirmation) {
            ConfirmCodeView(email: email, password: password, onLoggedIn: onLoggedIn)
        }
    }

    private func login() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await session.signIn(email: email.trimmingCharacters(in: .whitespaces), password: password)
            await onLoggedIn()
        } catch let error as CognitoError {
            if error.code == "UserNotConfirmedException" {
                pendingConfirmation = true
            } else {
                errorMessage = error.errorDescription
            }
        } catch {
            errorMessage = "通信エラーが発生しました。"
        }
    }
}

#Preview {
    NavigationStack {
        LoginView()
    }
}
