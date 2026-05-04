import Foundation

struct ChatMessageRequest: Encodable {
    let role: String
    let content: String
}

struct ChatRequest: Encodable {
    let messages: [ChatMessageRequest]
    let selectedChoice: Int?
}
