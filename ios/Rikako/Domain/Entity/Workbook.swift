import Foundation

struct Workbook: Identifiable, Codable {
    let id: Int64
    let title: String
    let description: String
    let questionCount: Int
    let categoryId: Int64?
}

struct WorkbookDetail: Identifiable, Codable {
    let id: Int64
    let title: String
    let description: String
    let categoryId: Int64?
    let questions: [Question]
}
