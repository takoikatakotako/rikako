import SwiftUI

struct SignUpView: View {
    @Binding var isLoggedIn: Bool
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "person.badge.plus")
                .font(.system(size: 60))
                .foregroundStyle(Color.accentColor)

            Text("アカウント作成")
                .font(.title)
                .fontWeight(.bold)

            VStack(spacing: 16) {
                TextField("メールアドレス", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)

                SecureField("パスワード", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.newPassword)

                SecureField("パスワード（確認）", text: $confirmPassword)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.newPassword)
            }
            .padding(.horizontal, 32)

            Button {
                isLoggedIn = true
            } label: {
                Text("アカウントを作成")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .navigationTitle("新規登録")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SignUpView(isLoggedIn: .constant(false))
    }
}
