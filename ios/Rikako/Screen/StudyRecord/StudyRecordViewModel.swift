import Foundation
import Observation

@Observable
@MainActor
final class StudyRecordViewModel {
    func activeDays(completedWorkbookIDs: Set<Int64>) -> Int {
        min(7, max(1, completedWorkbookIDs.count))
    }

    func streakText(completedWorkbookIDs: Set<Int64>) -> String {
        "\(completedWorkbookIDs.count)"
    }

    func chartValue(totalAnswered: Int) -> Int {
        min(totalAnswered, 30)
    }
}
