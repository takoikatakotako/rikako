import Foundation

struct Question: Identifiable {
    let id: Int64
    let type: QuestionType
    let text: String
    let choices: [String]
    let correct: Int
    let explanation: String
    let images: [String]

    enum QuestionType: String {
        case singleChoice = "single_choice"
    }
}

struct Workbook: Identifiable {
    let id: Int64
    let title: String
    let description: String
    let questionCount: Int
}

struct WorkbookDetail: Identifiable {
    let id: Int64
    let title: String
    let description: String
    let questions: [Question]
}
