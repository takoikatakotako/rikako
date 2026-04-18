import SwiftUI

struct DebugLearningLogView: View {
    @Environment(AppState.self) private var appState
    @State private var visibleCount = 50

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM/dd HH:mm:ss"
        return f
    }()

    private var sortedQuestionResults: [(id: String, result: AppState.QuestionResult)] {
        appState.questionResults
            .map { (id: $0.key, result: $0.value) }
            .sorted { $0.result.date > $1.result.date }
    }

    var body: some View {
        List {
            if appState.questionResults.isEmpty {
                ContentUnavailableView("まだ解いた問題がありません", systemImage: "square.and.pencil")
            } else {
                ForEach(sortedQuestionResults.prefix(visibleCount), id: \.id) { entry in
                    HStack(spacing: 10) {
                        Image(systemName: entry.result.isCorrect ? "circle" : "xmark")
                            .foregroundStyle(entry.result.isCorrect ? .green : .red)
                            .frame(width: 16)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("問題 ID: \(entry.id)")
                                .font(.caption)
                            Text(Self.dateFormatter.string(from: entry.result.date))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(entry.result.isCorrect ? "正解" : "不正解")
                            .font(.caption)
                            .foregroundStyle(entry.result.isCorrect ? .green : .red)
                    }
                }
                if visibleCount < sortedQuestionResults.count {
                    Button("もっと見る (\(sortedQuestionResults.count - visibleCount)件)") {
                        visibleCount += 50
                    }
                    .font(.caption)
                }
            }
        }
        .navigationTitle("学習ログ (\(appState.questionResults.count)問)")
        .navigationBarTitleDisplayMode(.inline)
    }
}
