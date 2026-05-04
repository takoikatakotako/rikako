import Foundation

struct ChatResponse: Decodable {
    let reply: String
    let turnCount: Int
    let remainingTurns: Int
}
