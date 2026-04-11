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
        .navigationDestination(isPresented: $showResult) {
            ResultView(questions: questions, answers: answers, workbookTitle: workbookTitle, workbookId: workbookId)
        }
        .onAppear {
            answers = Array(repeating: nil, count: questions.count)
        }
    }

    private var progressSection: some View {
        ProgressView(value: Double(currentIndex + 1), total: Double(questions.count))
            .tint(.accentColor)
    }

    private var questionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(currentQuestion.text)
                .font(.title3)
                .fontWeight(.semibold)

            if let images = currentQuestion.images, !images.isEmpty {
                QuestionImageSection(imageURLs: images)
            }
        }
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
                    HStack {
                        Text(choice)
                            .foregroundStyle(choiceTextColor(for: index))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if showExplanation {
                            if index == currentQuestion.correctIndex {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else if index == selectedChoice {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    .padding()
                    .background(choiceBackground(for: index))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
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
                Image(systemName: selectedChoice == currentQuestion.correctIndex ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(selectedChoice == currentQuestion.correctIndex ? .green : .red)
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
        .background(Color(.systemGray6))
        .cornerRadius(12)
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
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .cornerRadius(12)
        }
    }

    private func choiceTextColor(for index: Int) -> Color {
        if !showExplanation { return .primary }
        if index == currentQuestion.correctIndex { return .green }
        if index == selectedChoice { return .red }
        return .secondary
    }

    private func choiceBackground(for index: Int) -> Color {
        if !showExplanation { return Color(.systemBackground) }
        if index == currentQuestion.correctIndex { return Color.green.opacity(0.1) }
        if index == selectedChoice && index != currentQuestion.correctIndex { return Color.red.opacity(0.1) }
        return Color(.systemBackground)
    }

    private func choiceBorderColor(for index: Int) -> Color {
        if !showExplanation { return Color(.systemGray4) }
        if index == currentQuestion.correctIndex { return .green }
        if index == selectedChoice { return .red }
        return Color(.systemGray4)
    }
}

#Preview {
    NavigationStack {
        QuizView(questions: MockData.questions, workbookTitle: "基礎化学", workbookId: 1)
    }
}
