import Foundation

struct Category: Identifiable, Codable {
    let id: Int64
    let title: String
    let description: String?
    let workbookCount: Int?
}

struct CategoryDetail: Identifiable, Codable {
    let id: Int64
    let title: String
    let description: String?
    let workbooks: [Workbook]
}

struct AppDetail: Identifiable, Codable {
    let id: Int64
    let slug: String
    let title: String
    let categories: [Category]
}
