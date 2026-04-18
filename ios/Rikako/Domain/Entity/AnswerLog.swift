import Foundation

struct AnswerLog: Identifiable, Codable {
    let id: Int64
    let questionId: Int64
    let questionText: String
    let workbookId: Int64
    let workbookTitle: String
    let selectedChoice: Int
    let isCorrect: Bool
    let answeredAt: Date
}

struct AnswerLogsResponse: Codable {
    let logs: [AnswerLog]
    let total: Int
}
