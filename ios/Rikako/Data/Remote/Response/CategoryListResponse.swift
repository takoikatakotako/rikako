import Foundation

struct CategoryListResponse: Codable {
    let categories: [Category]
    let total: Int
}

struct WrongAnswerListResponse: Codable {
    let questions: [Question]
    let total: Int
}
