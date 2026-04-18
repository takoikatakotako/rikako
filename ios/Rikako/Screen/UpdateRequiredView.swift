import SwiftUI

struct UpdateRequiredView: View {
    var body: some View {
        ZStack {
            Color(.main)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "arrow.down.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundStyle(.white)

                VStack(spacing: 12) {
                    Text("アップデートが必要です")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    Text("最新バージョンのアプリをインストールしてご利用ください。")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Button {
                    if let url = URL(string: Links.appStore) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("App Storeを開く")
                        .font(.headline)
                        .foregroundStyle(Color(.main))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 40)

                Spacer()
            }
        }
    }
}

#Preview {
    UpdateRequiredView()
}
