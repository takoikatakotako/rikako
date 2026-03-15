import SwiftUI

struct LoginView: View {
    @Binding var isLoggedIn: Bool
    @State private var email = ""
    @State private var password = ""
    @State private var showSignUp = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "atom")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.accentColor)

                Text("ログイン")
                    .font(.title)
                    .fontWeight(.bold)

                VStack(spacing: 16) {
                    TextField("メールアドレス", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)

                    SecureField("パスワード", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.password)
                }
                .padding(.horizontal, 32)

                Button {
                    isLoggedIn = true
                } label: {
                    Text("ログイン")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 32)

                Button {
                    showSignUp = true
                } label: {
                    Text("アカウントをお持ちでない方はこちら")
                        .font(.subheadline)
                        .foregroundStyle(Color.accentColor)
                }

                Button {
                    isLoggedIn = true
                } label: {
                    Text("ログインせずに使う")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .navigationDestination(isPresented: $showSignUp) {
                SignUpView(isLoggedIn: $isLoggedIn)
            }
        }
    }
}

#Preview {
    LoginView(isLoggedIn: .constant(false))
}
