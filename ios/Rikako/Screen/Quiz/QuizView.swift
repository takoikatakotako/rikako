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
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    progressSection
                        .id("top")
                    questionSection
                    choicesSection

                    if viewModel.showExplanation {
                        explanationSection
                        nextButton(scrollProxy: proxy)
                    }
                }
                .padding()
            }
        }
        .navigationTitle(viewModel.workbookTitle)
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
        VStack(spacing: 8) {
            HStack {
                Text("Q\(viewModel.currentIndex + 1)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color("main"))

                Spacer()

                Text("\(viewModel.currentIndex + 1) / \(viewModel.questions.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: Double(viewModel.currentIndex + 1), total: Double(viewModel.questions.count))
                .tint(Color("main"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color("main").opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var questionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
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

    private func nextButton(scrollProxy proxy: ScrollViewProxy) -> some View {
        Button {
            withAnimation {
                viewModel.goToNextQuestionOrResult()
                proxy.scrollTo("top", anchor: .top)
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
