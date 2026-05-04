import Foundation
import Observation

struct AIChatMessage: Identifiable {
    let id = UUID()
    let role: ChatMessageRole
    let content: String

    enum ChatMessageRole {
        case user, assistant
    }
}

@Observable
@MainActor
final class AIChatViewModel {
    let question: Question
    let selectedChoice: Int
    private(set) var messages: [AIChatMessage] = []
    private(set) var remainingTurns: Int = 10
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    var inputText: String = ""

    private var apiMessages: [ChatMessageRequest] = []

    init(question: Question, selectedChoice: Int) {
        self.question = question
        self.selectedChoice = selectedChoice
    }

    var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespaces).isEmpty && !isLoading && remainingTurns > 0
    }

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, remainingTurns > 0 else { return }

        inputText = ""
        errorMessage = nil

        let userMessage = AIChatMessage(role: .user, content: text)
        messages.append(userMessage)
        apiMessages.append(ChatMessageRequest(role: "user", content: text))

        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await AppContainer.shared.learningUseCases.chatWithQuestion.execute(
                questionId: question.id,
                messages: apiMessages,
                selectedChoice: selectedChoice
            )
            let assistantMessage = AIChatMessage(role: .assistant, content: response.reply)
            messages.append(assistantMessage)
            apiMessages.append(ChatMessageRequest(role: "assistant", content: response.reply))
            remainingTurns = response.remainingTurns
        } catch {
            messages.removeLast()
            apiMessages.removeLast()
            errorMessage = "エラーが発生しました。もう一度お試しください。"
        }
    }
}
