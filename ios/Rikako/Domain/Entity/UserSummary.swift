import Foundation

struct UserSummary: Codable {
    let totalAnswered: Int
    let totalCorrect: Int
    let weeklyAnswered: Int
    let weeklyCorrect: Int
    let studyDates: [String]
    let weeklyWorkbookIds: [Int64]

    var weeklyAccuracyText: String {
        guard weeklyAnswered > 0 else { return "--%" }
        return "\(Int(Double(weeklyCorrect) / Double(weeklyAnswered) * 100))%"
    }
}
