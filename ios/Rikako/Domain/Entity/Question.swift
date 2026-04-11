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
