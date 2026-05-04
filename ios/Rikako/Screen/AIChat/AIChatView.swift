import SwiftUI

struct AIChatView: View {
    @State private var viewModel: AIChatViewModel
    @FocusState private var isInputFocused: Bool

    private let selectedChoice: Int

    init(question: Question, selectedChoice: Int) {
        _viewModel = State(initialValue: AIChatViewModel(question: question))
        self.selectedChoice = selectedChoice
    }

    var body: some View {
        VStack(spacing: 0) {
            messageList
            Divider()
            inputArea
        }
        .navigationTitle("AIに質問する")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text("AIに質問する")
                        .font(.headline)
                    Text("残り\(viewModel.remainingTurns)回")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .toolbar(.hidden, for: .tabBar)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    questionBubble
                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                    if viewModel.isLoading {
                        TypingIndicator()
                            .id("typing")
                    }
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }
                }
                .padding()
            }
            .onChange(of: viewModel.messages.count) {
                withAnimation {
                    if let lastId = viewModel.messages.last?.id {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
            .onChange(of: viewModel.isLoading) {
                if viewModel.isLoading {
                    withAnimation { proxy.scrollTo("typing", anchor: .bottom) }
                }
            }
        }
    }

    private var questionBubble: some View {
        let q = viewModel.question
        let isCorrect = selectedChoice == q.correctIndex

        return VStack(alignment: .leading, spacing: 10) {
            Text(q.text)
                .font(.subheadline.weight(.semibold))
                .lineSpacing(3)

            Divider()

            if !isCorrect, selectedChoice < q.choices.count {
                answerRow(
                    label: "あなたの回答",
                    text: q.choices[selectedChoice],
                    color: Color(.correctPink)
                )
            }

            if q.correctIndex < q.choices.count {
                answerRow(
                    label: "正解",
                    text: q.choices[q.correctIndex],
                    color: Color(.main)
                )
            }

            if let explanation = q.explanation, !explanation.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("解説")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(explanation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                }
            }

            Divider()

            Text("この問題についてAIに質問できます")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func answerRow(label: String, text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 80, alignment: .leading)
            Text(text)
                .font(.caption)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var inputArea: some View {
        HStack(spacing: 10) {
            if viewModel.remainingTurns == 0 {
                Text("最大回数に達しました")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                TextField("質問を入力...", text: $viewModel.inputText, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .focused($isInputFocused)
                    .onSubmit {
                        guard viewModel.canSend else { return }
                        Task { await viewModel.sendMessage() }
                    }

                Button {
                    Task { await viewModel.sendMessage() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(viewModel.canSend ? Color(.main) : Color(.systemGray3))
                }
                .disabled(!viewModel.canSend)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

private struct MessageBubble: View {
    let message: AIChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 60) }
            Text(message.content)
                .font(.body)
                .padding(14)
                .background(message.role == .user ? Color(.main) : Color(.secondarySystemBackground))
                .foregroundStyle(message.role == .user ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 18))
            if message.role == .assistant { Spacer(minLength: 60) }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }
}

private struct TypingIndicator: View {
    @State private var dotOffset: CGFloat = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color(.systemGray3))
                    .frame(width: 7, height: 7)
                    .offset(y: dotOffset)
                    .animation(
                        .easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.15),
                        value: dotOffset
                    )
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { dotOffset = -4 }
    }
}

#Preview {
    NavigationStack {
        AIChatView(question: MockData.questions[0], selectedChoice: 1)
    }
}
