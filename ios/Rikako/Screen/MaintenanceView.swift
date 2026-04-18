import SwiftUI

struct MaintenanceView: View {
    let message: String

    var body: some View {
        ZStack {
            Color(.main)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "wrench.and.screwdriver.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundStyle(.white)

                VStack(spacing: 12) {
                    Text("メンテナンス中")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    Text(message.isEmpty ? "現在メンテナンス中です。\nしばらく時間をおいてから再度お試しください。" : message)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()
            }
        }
    }
}

#Preview {
    MaintenanceView(message: "")
}

#Preview("カスタムメッセージ") {
    MaintenanceView(message: "システムの改善のため、メンテナンスを実施中です。")
}
