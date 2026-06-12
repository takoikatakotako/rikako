import Foundation

struct CategoryListResponse: Codable {
    let categories: [Category]
    let total: Int
}

struct WrongAnswerQuestion: Codable {
    let id: Int64
    let type: Question.QuestionType
    let text: String
    let choices: [String]
    let correct: Int?
    let explanation: String?
    let images: [String]?
    // workbookId を返さない旧APIでもデコードが失敗してリストが空にならないよう optional にする。
    // 値が無い場合、復習の回答はその問題集へ正しく帰属できない（旧API配信中の一時的なデグレード）。
    let workbookId: Int64?

    var asQuestion: Question {
        Question(id: id, type: type, text: text, choices: choices, correct: correct, explanation: explanation, images: images)
    }
}

struct WrongAnswerListResponse: Codable {
    let questions: [WrongAnswerQuestion]
    let total: Int
}
