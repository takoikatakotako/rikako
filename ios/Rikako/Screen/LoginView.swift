import SwiftUI

struct LoginView: View {
    @Environment(AppState.self) private var appState
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
                    appState.setLoggedIn(true)
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
                    appState.setLoggedIn(true)
                } label: {
                    Text("ログインせずに使う")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .navigationDestination(isPresented: $showSignUp) {
                SignUpView(
                    isLoggedIn: Binding(
                        get: { appState.isLoggedIn },
                        set: { appState.setLoggedIn($0) }
                    )
                )
            }
        }
    }
}

#Preview {
    LoginView()
        .environment(AppState.shared)
}
