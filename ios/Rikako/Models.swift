import Foundation

struct Question: Identifiable, Codable {
    let id: Int64
    let type: QuestionType
    let text: String
    let choices: [String]
    let correct: Int
    let explanation: String
    let images: [String]

    enum QuestionType: String, Codable {
        case singleChoice = "single_choice"
    }
}

struct Workbook: Identifiable, Codable {
    let id: Int64
    let title: String
    let description: String
    let questionCount: Int
    let categoryId: Int64
}

struct WorkbookDetail: Identifiable, Codable {
    let id: Int64
    let title: String
    let description: String
    let categoryId: Int64
    let questions: [Question]
}

struct WorkbooksResponse: Codable {
    let workbooks: [Workbook]
    let total: Int
}
