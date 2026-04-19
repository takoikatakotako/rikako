import Foundation
import Observation

extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}

@Observable
@MainActor
final class StudyRecordViewModel {
    private let calendar = Calendar(identifier: .iso8601)

    // 連続学習日数（今日または昨日を含む連続した日数）
    func streak(studyDates: Set<String>) -> Int {
        guard !studyDates.isEmpty else { return 0 }

        let formatter = DateFormatter.yyyyMMdd
        var date = Date()
        var count = 0

        // 今日に記録がなければ昨日から遡る
        if !studyDates.contains(formatter.string(from: date)) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: date),
                  studyDates.contains(formatter.string(from: yesterday)) else {
                return 0
            }
            date = yesterday
        }

        while studyDates.contains(formatter.string(from: date)) {
            count += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: date) else { break }
            date = prev
        }
        return count
    }

    // 今週（月〜日）の各曜日に学習したか（index 0=月 ... 6=日）
    func weeklyStudied(studyDates: Set<String>) -> [Bool] {
        let formatter = DateFormatter.yyyyMMdd
        let today = Date()
        // 今週の月曜日を取得
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        components.weekday = 2  // 月曜
        let monday = calendar.date(from: components) ?? today

        return (0..<7).map { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: monday) else { return false }
            return studyDates.contains(formatter.string(from: day))
        }
    }

    // 今週の学習日数合計
    func weeklyStudyCount(studyDates: Set<String>) -> Int {
        weeklyStudied(studyDates: studyDates).filter { $0 }.count
    }

    // 今週のindex番目（0=月...6=日）に対応するDate
    func weeklyDate(at index: Int) -> Date? {
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        components.weekday = 2
        guard let monday = calendar.date(from: components) else { return nil }
        return calendar.date(byAdding: .day, value: index, to: monday)
    }
}

