import SwiftUI

struct DebugLearningLogView: View {
    @Environment(AppState.self) private var appState
    @State private var logs: [AnswerLog] = []
    @State private var total = 0
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let pageSize = 50

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM/dd HH:mm:ss"
        return f
    }()

    var body: some View {
        Group {
            if isLoading && logs.isEmpty {
                ProgressView("読み込み中...")
            } else if let errorMessage, logs.isEmpty {
                ContentUnavailableView {
                    Label("読み込みエラー", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("再読み込み") { Task { await load(reset: true) } }
                }
            } else if logs.isEmpty {
                ContentUnavailableView("まだ解いた問題がありません", systemImage: "square.and.pencil")
            } else {
                List {
                    ForEach(logs) { log in
                        HStack(spacing: 10) {
                            Image(systemName: log.isCorrect ? "circle" : "xmark")
                                .foregroundStyle(log.isCorrect ? .green : .red)
                                .frame(width: 16)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(log.questionText)
                                    .font(.caption)
                                    .lineLimit(1)
                                Text(log.workbookTitle)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(Self.dateFormatter.string(from: log.answeredAt))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(log.isCorrect ? "正解" : "不正解")
                                .font(.caption)
                                .foregroundStyle(log.isCorrect ? .green : .red)
                        }
                    }

                    if logs.count < total {
                        Button("もっと見る (\(total - logs.count)件)") {
                            Task { await load(reset: false) }
                        }
                        .font(.caption)
                        .disabled(isLoading)
                    }
                }
            }
        }
        .navigationTitle("学習ログ (\(total)件)")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load(reset: true) }
    }

    private func load(reset: Bool) async {
        isLoading = true
        errorMessage = nil
        let offset = reset ? 0 : logs.count
        do {
            let response = try await AppContainer.shared.learningUseCases.fetchAnswerLogs.execute(limit: pageSize, offset: offset)
            if reset {
                logs = response.logs
            } else {
                logs.append(contentsOf: response.logs)
            }
            total = response.total
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
