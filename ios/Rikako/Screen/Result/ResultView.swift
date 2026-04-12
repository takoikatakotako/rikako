import SwiftUI

struct ResultView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var viewModel: ResultViewModel
    private let onBackToWorkbookList: () -> Void

    init(
        questions: [Question],
        answers: [Int?],
        workbookTitle: String,
        workbookId: Int64,
        onBackToWorkbookList: @escaping () -> Void = {}
    ) {
        _viewModel = State(initialValue: ResultViewModel(
            questions: questions,
            answers: answers,
            workbookTitle: workbookTitle,
            workbookId: workbookId
        ))
        self.onBackToWorkbookList = onBackToWorkbookList
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                scoreCard
                questionResults
                backButton
            }
            .padding()
        }
        .navigationTitle("結果")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .task {
            viewModel.recordSessionIfNeeded(appState: appState)
        }
    }

    private var scoreCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("学習結果")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    Text(viewModel.workbookTitle)
                        .font(.title3.weight(.bold))

                    Text(viewModel.resultMessage)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Image(viewModel.legacyResultImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
            }

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(Int(viewModel.scorePercentage))")
                    .font(.system(size: 54, weight: .black))
                    .foregroundStyle(Color(viewModel.scoreColorName))
                Text("%")
                    .font(.title2.bold())
                    .foregroundStyle(Color(viewModel.scoreColorName))
            }

            HStack(spacing: 10) {
                Label(viewModel.summaryText, systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(viewModel.scoreColorName))

                Spacer()

                Text("10問ずつコツコツ進めよう")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color.white, Color(viewModel.scoreColorName).opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color(viewModel.scoreColorName).opacity(0.18), lineWidth: 2)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 14, x: 0, y: 6)
    }

    private var questionResults: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("解答一覧")
                    .font(.headline.bold())
                Spacer()
                Text("\(viewModel.questionResults.count)問")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
            }

            ForEach(viewModel.questionResults) { row in
                NavigationLink {
                    ResultQuestionDetailView(row: row)
                } label: {
                    HStack {
                        Image(row.isCorrect ? "result-correct" : "result-discorrect")
                            .resizable()
                            .frame(width: 28, height: 28)
                            .opacity(0.8)
                        Text("Q\(row.index + 1)")
                            .font(.subheadline.bold())
                            .frame(width: 32)
                        Text(row.question.text)
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image("result-next")
                            .resizable()
                            .frame(width: 18, height: 18)
                            .opacity(0.4)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var backButton: some View {
        Button {
            dismiss()
            DispatchQueue.main.async {
                onBackToWorkbookList()
            }
        } label: {
            Text("問題集一覧に戻る")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color("main"))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

private struct ResultQuestionDetailView: View {
    let row: ResultViewModel.QuestionResultRow

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Image(row.isCorrect ? "result-correct" : "result-discorrect")
                            .resizable()
                            .frame(width: 28, height: 28)

                        Text(row.isCorrect ? "正解した問題" : "復習したい問題")
                            .font(.headline.bold())
                    }

                    Text(row.question.text)
                        .font(.title3.weight(.semibold))
                        .lineSpacing(4)

                    if let images = row.question.images, !images.isEmpty {
                        QuestionImageSection(imageURLs: images)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))

                VStack(alignment: .leading, spacing: 12) {
                    Text("選択肢")
                        .font(.headline.bold())

                    ForEach(Array(row.question.choices.enumerated()), id: \.offset) { index, choice in
                        HStack(spacing: 12) {
                            Text(["A", "B", "C", "D"][safe: index] ?? "\(index + 1)")
                                .font(.subheadline.bold())
                                .frame(width: 28, height: 28)
                                .background(badgeBackground(for: index))
                                .foregroundStyle(badgeForeground(for: index))
                                .clipShape(Circle())

                            Text(choice)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if index == row.question.correctIndex {
                                Image("question-correct")
                                    .resizable()
                                    .frame(width: 24, height: 24)
                            } else if index == row.selectedAnswer {
                                Image("question-discorrect")
                                    .resizable()
                                    .frame(width: 24, height: 24)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(backgroundColor(for: index))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }

                if let explanation = row.question.explanation, !explanation.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("解説")
                            .font(.headline.bold())
                        Text(explanation)
                            .foregroundStyle(.secondary)
                            .lineSpacing(4)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }
            }
            .padding()
        }
        .navigationTitle("Q\(row.index + 1)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func backgroundColor(for index: Int) -> Color {
        if index == row.question.correctIndex { return Color("main").opacity(0.10) }
        if index == row.selectedAnswer { return Color("correctPink").opacity(0.12) }
        return Color(.systemBackground)
    }

    private func badgeBackground(for index: Int) -> Color {
        if index == row.question.correctIndex { return Color("main") }
        if index == row.selectedAnswer { return Color("correctPink") }
        return Color(.systemGray5)
    }

    private func badgeForeground(for index: Int) -> Color {
        if index == row.question.correctIndex || index == row.selectedAnswer { return .white }
        return .primary
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    NavigationStack {
        ResultView(
            questions: MockData.questions,
            answers: [0, 1, 2, 0, 2],
            workbookTitle: "基礎化学",
            workbookId: 1
        )
        .environment(AppState.shared)
    }
}
