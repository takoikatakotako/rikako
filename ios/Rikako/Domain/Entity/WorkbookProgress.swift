import Foundation

struct QuestionProgressItem: Codable {
    let questionId: Int64
    let isCorrect: Bool
}

struct WorkbookProgressResponse: Codable {
    let results: [QuestionProgressItem]
}
