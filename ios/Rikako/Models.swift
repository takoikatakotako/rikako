import Foundation

struct Question: Identifiable, Codable {
    let id: Int64
    let type: QuestionType
    let text: String
    let choices: [String]
    let correct: Int?
    let explanation: String?
    let images: [String]?

    var correctIndex: Int { correct ?? -1 }

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

// MARK: - Answers

struct AnswerItem: Codable {
    let questionId: Int64
    let selectedChoice: Int
}

struct SubmitAnswersRequest: Codable {
    let workbookId: Int64
    let answers: [AnswerItem]
}

struct SubmitAnswersResponse: Codable {
    let correctCount: Int
    let totalCount: Int
}

struct WrongAnswersResponse: Codable {
    let questions: [Question]
    let total: Int
}
