import Foundation

struct AnswerSubmissionRequest: Codable {
    let workbookId: Int64
    let answers: [AnswerItem]
}
