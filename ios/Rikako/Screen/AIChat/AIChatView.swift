import SwiftUI

struct AIChatView: View {
    @State private var viewModel: AIChatViewModel
    @FocusState private var isInputFocused: Bool

    init(question: Question) {
        _viewModel = State(initialValue: AIChatViewModel(question: question))
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
                    proxy.scrollTo(viewModel.messages.last?.id ?? "typing", anchor: .bottom)
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
        VStack(alignment: .leading, spacing: 6) {
            Text("この問題について質問できます")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(viewModel.question.text)
                .font(.subheadline)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.main).opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
        AIChatView(question: MockData.questions[0])
    }
}
