import SwiftUI

struct QuizView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: QuizViewModel

    private let choiceLabels = ["A", "B", "C", "D"]

    init(questions: [Question], workbookTitle: String, workbookId: Int64) {
        _viewModel = State(initialValue: QuizViewModel(
            questions: questions,
            workbookTitle: workbookTitle,
            workbookId: workbookId
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                progressSection
                questionSection
                choicesSection

                if viewModel.showExplanation {
                    explanationSection
                    nextButton
                }
            }
            .padding()
        }
        .navigationTitle("Q\(viewModel.currentIndex + 1) / \(viewModel.questions.count)")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(viewModel.showExplanation)
        .toolbar(.hidden, for: .tabBar)
        .navigationDestination(isPresented: $viewModel.showResult) {
            ResultView(
                questions: viewModel.questions,
                answers: viewModel.answers,
                workbookTitle: viewModel.workbookTitle,
                workbookId: viewModel.workbookId,
                onBackToWorkbookList: {
                    dismiss()
                }
            )
        }
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.workbookTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text("Q\(viewModel.currentIndex + 1)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Color("main"))
                }

                Spacer()

                Text("\(viewModel.currentIndex + 1) / \(viewModel.questions.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color("main").opacity(0.1))
                    .clipShape(Capsule())
            }

            ProgressView(value: Double(viewModel.currentIndex + 1), total: Double(viewModel.questions.count))
                .tint(Color("main"))
                .scaleEffect(x: 1, y: 1.6, anchor: .center)
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color("main").opacity(0.16), Color("main").opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private var questionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("問題")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color("main"))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color("main").opacity(0.12))
                .clipShape(Capsule())

            Text(viewModel.currentQuestion.text)
                .font(.title3.weight(.semibold))
                .lineSpacing(4)

            if let images = viewModel.currentQuestion.images, !images.isEmpty {
                QuestionImageSection(imageURLs: images)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private var choicesSection: some View {
        VStack(spacing: 12) {
            ForEach(Array(viewModel.currentQuestion.choices.enumerated()), id: \.offset) { index, choice in
                Button {
                    withAnimation {
                        viewModel.selectChoice(index)
                    }
                } label: {
                    HStack(spacing: 14) {
                        Text(choiceLabel(for: index))
                            .font(.headline.bold())
                            .foregroundStyle(choiceBadgeTextColor(for: index))
                            .frame(width: 34, height: 34)
                            .background(choiceBadgeBackground(for: index))
                            .clipShape(Circle())

                        Text(choice)
                            .foregroundStyle(choiceTextColor(for: index))
                            .font(.body.weight(.medium))
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if viewModel.showExplanation {
                            if index == viewModel.currentQuestion.correctIndex {
                                Image("question-correct")
                                    .resizable()
                                    .frame(width: 26, height: 26)
                            } else if index == viewModel.selectedChoice {
                                Image("question-discorrect")
                                    .resizable()
                                    .frame(width: 26, height: 26)
                            }
                        }
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(choiceBackground(for: index))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(choiceBorderColor(for: index), lineWidth: 2)
                    )
                }
                .disabled(viewModel.showExplanation)
            }
        }
    }

    private var explanationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(viewModel.selectedChoice == viewModel.currentQuestion.correctIndex ? "question-correct" : "question-discorrect")
                    .resizable()
                    .frame(width: 28, height: 28)
                Text(viewModel.selectedChoice == viewModel.currentQuestion.correctIndex ? "正解！" : "不正解")
                    .fontWeight(.bold)
            }
            .font(.headline)

            if let explanation = viewModel.currentQuestion.explanation, !explanation.isEmpty {
                Text(explanation)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var nextButton: some View {
        Button {
            withAnimation {
                viewModel.goToNextQuestionOrResult()
            }
        } label: {
            Text(viewModel.isLastQuestion ? "結果を見る" : "次の問題へ")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color("main"))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func choiceLabel(for index: Int) -> String {
        guard index < choiceLabels.count else { return "\(index + 1)" }
        return choiceLabels[index]
    }

    private func choiceTextColor(for index: Int) -> Color {
        if !viewModel.showExplanation { return .primary }
        if index == viewModel.currentQuestion.correctIndex { return Color("main") }
        if index == viewModel.selectedChoice { return Color("correctPink") }
        return .secondary
    }

    private func choiceBackground(for index: Int) -> Color {
        if !viewModel.showExplanation { return Color(.systemBackground) }
        if index == viewModel.currentQuestion.correctIndex { return Color("main").opacity(0.10) }
        if index == viewModel.selectedChoice && index != viewModel.currentQuestion.correctIndex { return Color("correctPink").opacity(0.12) }
        return Color(.systemBackground)
    }

    private func choiceBorderColor(for index: Int) -> Color {
        if !viewModel.showExplanation { return Color(.systemGray4) }
        if index == viewModel.currentQuestion.correctIndex { return Color("main") }
        if index == viewModel.selectedChoice { return Color("correctPink") }
        return Color(.systemGray4)
    }

    private func choiceBadgeBackground(for index: Int) -> Color {
        if !viewModel.showExplanation { return Color(.systemGray6) }
        if index == viewModel.currentQuestion.correctIndex { return Color("main") }
        if index == viewModel.selectedChoice { return Color("correctPink") }
        return Color(.systemGray6)
    }

    private func choiceBadgeTextColor(for index: Int) -> Color {
        if !viewModel.showExplanation { return .primary }
        if index == viewModel.currentQuestion.correctIndex || index == viewModel.selectedChoice { return .white }
        return .primary
    }
}

#Preview {
    NavigationStack {
        QuizView(questions: MockData.questionsWithImages, workbookTitle: "基礎化学", workbookId: 1)
    }
}
