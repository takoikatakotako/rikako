import SwiftUI

struct QuizView: View {
    let questions: [Question]
    let workbookTitle: String
    let workbookId: Int64

    @State private var currentIndex = 0
    @State private var selectedChoice: Int?
    @State private var showExplanation = false
    @State private var answers: [Int?] = []
    @State private var showResult = false

    private var currentQuestion: Question {
        questions[currentIndex]
    }

    private var isLastQuestion: Bool {
        currentIndex == questions.count - 1
    }

    private let choiceLabels = ["A", "B", "C", "D"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                progressSection
                questionSection
                choicesSection

                if showExplanation {
                    explanationSection
                    nextButton
                }
            }
            .padding()
        }
        .navigationTitle("Q\(currentIndex + 1) / \(questions.count)")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(showExplanation)
        .toolbar(.hidden, for: .tabBar)
        .navigationDestination(isPresented: $showResult) {
            ResultView(questions: questions, answers: answers, workbookTitle: workbookTitle, workbookId: workbookId)
        }
        .onAppear {
            answers = Array(repeating: nil, count: questions.count)
        }
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(workbookTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text("Q\(currentIndex + 1)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Color("main"))
                }

                Spacer()

                Text("\(currentIndex + 1) / \(questions.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color("main").opacity(0.1))
                    .clipShape(Capsule())
            }

            ProgressView(value: Double(currentIndex + 1), total: Double(questions.count))
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

            Text(currentQuestion.text)
                .font(.title3.weight(.semibold))
                .lineSpacing(4)

            if let images = currentQuestion.images, !images.isEmpty {
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
            ForEach(Array(currentQuestion.choices.enumerated()), id: \.offset) { index, choice in
                Button {
                    guard !showExplanation else { return }
                    selectedChoice = index
                    answers[currentIndex] = index
                    withAnimation {
                        showExplanation = true
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
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if showExplanation {
                            if index == currentQuestion.correctIndex {
                                Image("question-correct")
                                    .resizable()
                                    .frame(width: 26, height: 26)
                            } else if index == selectedChoice {
                                Image("question-discorrect")
                                    .resizable()
                                    .frame(width: 26, height: 26)
                            }
                        }
                    }
                    .padding(18)
                    .background(choiceBackground(for: index))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(choiceBorderColor(for: index), lineWidth: 2)
                    )
                }
                .disabled(showExplanation)
            }
        }
    }

    private var explanationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(selectedChoice == currentQuestion.correctIndex ? "question-correct" : "question-discorrect")
                    .resizable()
                    .frame(width: 28, height: 28)
                Text(selectedChoice == currentQuestion.correctIndex ? "正解！" : "不正解")
                    .fontWeight(.bold)
            }
            .font(.headline)

            if let explanation = currentQuestion.explanation, !explanation.isEmpty {
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
            if isLastQuestion {
                showResult = true
            } else {
                withAnimation {
                    currentIndex += 1
                    selectedChoice = nil
                    showExplanation = false
                }
            }
        } label: {
            Text(isLastQuestion ? "結果を見る" : "次の問題へ")
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
        if !showExplanation { return .primary }
        if index == currentQuestion.correctIndex { return Color("main") }
        if index == selectedChoice { return Color("correctPink") }
        return .secondary
    }

    private func choiceBackground(for index: Int) -> Color {
        if !showExplanation { return Color(.systemBackground) }
        if index == currentQuestion.correctIndex { return Color("main").opacity(0.10) }
        if index == selectedChoice && index != currentQuestion.correctIndex { return Color("correctPink").opacity(0.12) }
        return Color(.systemBackground)
    }

    private func choiceBorderColor(for index: Int) -> Color {
        if !showExplanation { return Color(.systemGray4) }
        if index == currentQuestion.correctIndex { return Color("main") }
        if index == selectedChoice { return Color("correctPink") }
        return Color(.systemGray4)
    }

    private func choiceBadgeBackground(for index: Int) -> Color {
        if !showExplanation { return Color(.systemGray6) }
        if index == currentQuestion.correctIndex { return Color("main") }
        if index == selectedChoice { return Color("correctPink") }
        return Color(.systemGray6)
    }

    private func choiceBadgeTextColor(for index: Int) -> Color {
        if !showExplanation { return .primary }
        if index == currentQuestion.correctIndex || index == selectedChoice { return .white }
        return .primary
    }
}

#Preview {
    NavigationStack {
        QuizView(questions: MockData.questions, workbookTitle: "基礎化学", workbookId: 1)
    }
}
