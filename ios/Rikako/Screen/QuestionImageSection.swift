import SwiftUI

struct QuestionImageSection: View {
    let imageURLs: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(imageURLs, id: \.self) { url in
                AsyncImage(url: URL(string: url)) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemGray6))
                            ProgressView()
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    case .failure:
                        ContentUnavailableView {
                            Label("画像を読み込めません", systemImage: "photo")
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    @unknown default:
                        EmptyView()
                    }
                }
            }
        }
    }
}
