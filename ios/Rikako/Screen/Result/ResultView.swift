import SwiftUI

struct ResultView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: ResultViewModel
    @State private var showContinueQuiz = false
    @State private var showRetryWrongAnswers = false
    private let allSectionsQuestions: [[Question]]
    private let currentSectionIndex: Int

    init(
        questions: [Question],
        answers: [Int?],
        workbookTitle: String,
        workbookId: Int64,
        allSectionsQuestions: [[Question]] = [],
        currentSectionIndex: Int = 0
    ) {
        _viewModel = State(initialValue: ResultViewModel(
            questions: questions,
            answers: answers,
            workbookTitle: workbookTitle,
            workbookId: workbookId
        ))
        self.allSectionsQuestions = allSectionsQuestions
        self.currentSectionIndex = currentSectionIndex
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                scoreCard
                questionResults
                retryWrongAnswersButton
                continueButton
                backButton
            }
            .padding()
        }
        .navigationTitle("結果")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .task {
            await viewModel.recordSessionIfNeeded()
            appState.notifyQuizCompleted()
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
                    .foregroundStyle(viewModel.scoreColor)
                Text("%")
                    .font(.title2.bold())
                    .foregroundStyle(viewModel.scoreColor)
            }

            HStack(spacing: 10) {
                Label(viewModel.summaryText, systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(viewModel.scoreColor)

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
                colors: [Color.white, viewModel.scoreColor.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(viewModel.scoreColor.opacity(0.18), lineWidth: 2)
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
                        Image(row.isCorrect ? .resultCorrect : .resultDiscorrect)
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
                        Image(.resultNext)
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

    private var continueButton: some View {
        let nextIndex = allSectionsQuestions.isEmpty ? 0 : (currentSectionIndex + 1) % allSectionsQuestions.count
        let nextQuestions = allSectionsQuestions.isEmpty ? viewModel.questions : allSectionsQuestions[nextIndex]
        let nextSectionNumber = nextIndex + 1

        return Button {
            showContinueQuiz = true
        } label: {
            Text(allSectionsQuestions.isEmpty ? "次のチャプターを勉強する" : "Chapter \(nextSectionNumber) を勉強する")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.main))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .navigationDestination(isPresented: $showContinueQuiz) {
            QuizView(
                questions: nextQuestions,
                workbookTitle: viewModel.workbookTitle,
                workbookId: viewModel.workbookId,
                allSectionsQuestions: allSectionsQuestions,
                currentSectionIndex: nextIndex
            )
        }
    }

    @ViewBuilder
    private var retryWrongAnswersButton: some View {
        let wrongQuestions = viewModel.questionResults.filter { !$0.isCorrect }.map { $0.question }
        if !wrongQuestions.isEmpty {
            Button {
                showRetryWrongAnswers = true
            } label: {
                Text("間違えた\(wrongQuestions.count)問を解き直す")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.correctPink))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .navigationDestination(isPresented: $showRetryWrongAnswers) {
                QuizView(
                    questions: wrongQuestions,
                    workbookTitle: viewModel.workbookTitle,
                    workbookId: viewModel.workbookId
                )
            }
        }
    }

    private var backButton: some View {
        Button {
            appState.notifyDismissAllQuiz()
        } label: {
            Text("問題集一覧に戻る")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray5))
                .foregroundStyle(.primary)
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
                        Image(row.isCorrect ? .resultCorrect : .resultDiscorrect)
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
                                Image(.questionCorrect)
                                    .resizable()
                                    .frame(width: 24, height: 24)
                            } else if index == row.selectedAnswer {
                                Image(.questionDiscorrect)
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
        if index == row.question.correctIndex { return Color(.main).opacity(0.10) }
        if index == row.selectedAnswer { return Color(.correctPink).opacity(0.12) }
        return Color(.systemBackground)
    }

    private func badgeBackground(for index: Int) -> Color {
        if index == row.question.correctIndex { return Color(.main) }
        if index == row.selectedAnswer { return Color(.correctPink) }
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

#Preview("100% 全問正解") {
    NavigationStack {
        ResultView(questions: MockData.questions, answers: [0, 1, 2, 1, 2], workbookTitle: "基礎化学", workbookId: 1)
            .environment(AppState.shared)
    }
}

#Preview("80%") {
    NavigationStack {
        ResultView(questions: MockData.questions, answers: [0, 1, 2, 0, 2], workbookTitle: "基礎化学", workbookId: 1)
            .environment(AppState.shared)
    }
}

#Preview("60%") {
    NavigationStack {
        ResultView(questions: MockData.questions, answers: [0, 1, 0, 0, 2], workbookTitle: "基礎化学", workbookId: 1)
            .environment(AppState.shared)
    }
}

#Preview("40%") {
    NavigationStack {
        ResultView(questions: MockData.questions, answers: [0, 0, 0, 0, 2], workbookTitle: "基礎化学", workbookId: 1)
            .environment(AppState.shared)
    }
}

#Preview("20%") {
    NavigationStack {
        ResultView(questions: MockData.questions, answers: [0, 0, 0, 0, 0], workbookTitle: "基礎化学", workbookId: 1)
            .environment(AppState.shared)
    }
}
