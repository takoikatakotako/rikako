import Foundation

/// クイズの出題元。回答をどの問題集に記録するかを決める。
/// - workbook: 通常プレイ。全問が同じ問題集に属する。
/// - review: 復習。問題ごとに出身問題集が異なるため、問題ID→問題集IDのマップを持つ。
enum QuizSource {
    case workbook(id: Int64)
    case review(workbookIds: [Int64: Int64])

    var isReview: Bool {
        if case .review = self { return true }
        return false
    }

    func workbookId(for questionId: Int64) -> Int64 {
        switch self {
        case .workbook(let id): return id
        case .review(let map): return map[questionId] ?? 0
        }
    }

    /// 回答を問題集ごとにまとめる。2つの送信経路（中断保存・結果画面）で共通利用する。
    func groupedAnswers(questions: [Question], answers: [Int?]) -> [Int64: [AnswerItem]] {
        var byWorkbook: [Int64: [AnswerItem]] = [:]
        for (question, answer) in zip(questions, answers) {
            guard let choice = answer else { continue }
            let item = AnswerItem(questionId: question.id, selectedChoice: choice)
            byWorkbook[workbookId(for: question.id), default: []].append(item)
        }
        return byWorkbook
    }
}
