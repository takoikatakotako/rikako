import Foundation

struct WorkbookListResponse: Codable {
    let workbooks: [Workbook]
    let total: Int
}
