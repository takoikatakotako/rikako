import Foundation
import Testing
@testable import Rikako

struct AnalyticsEventTests {
    /// 値付きも含めた代表的な全イベント。新しい case を追加したらここにも足す。
    private static let samples: [AnalyticsEvent] = [
        .appOpen,
        .onboardingStarted,
        .onboardingStepViewed(step: 3),
        .onboardingCompleted,
        .workbookStarted(workbookID: 42),
        .workbookCompleted(workbookID: 42),
        .answersSubmitted(workbookID: 42, count: 10),
        .answersSubmitted(workbookID: nil, count: 5),
        .answersSubmissionFailed(reason: .network),
        .aiChatStarted,
        .aiChatSucceeded,
        .aiChatFailed(reason: .server),
        .transferStarted,
        .transferCompleted,
        .transferFailed(reason: .unknown),
    ]

    /// イベント名は Firebase の制約（英字始まり・英数字と `_`・40 文字以内）を満たす。
    @Test func eventNamesAreFirebaseSafe() {
        let pattern = try! NSRegularExpression(pattern: "^[A-Za-z][A-Za-z0-9_]{0,39}$")
        for event in Self.samples {
            let name = event.name
            let range = NSRange(name.startIndex..., in: name)
            #expect(
                pattern.firstMatch(in: name, range: range) != nil,
                "イベント名がFirebase制約違反: \(name)"
            )
        }
    }

    /// パラメータのキーは既知の非PIIキーのみ。自由入力キーが紛れ込まないことを担保する。
    @Test func parameterKeysAreAllowlisted() {
        let allowedKeys: Set<String> = ["step", "workbook_id", "count", "reason"]
        for event in Self.samples {
            for key in event.parameters.keys {
                #expect(allowedKeys.contains(key), "許可されていないパラメータキー: \(key) in \(event.name)")
            }
        }
    }

    /// パラメータ値は Int か、有限集合の reason 文字列のみ。ユーザー入力等の自由文字列を載せない。
    @Test func parameterValuesCarryNoFreeformText() {
        let allowedReasons = Set(
            [AnalyticsFailureReason.network, .server, .decoding, .cancelled, .unauthorized, .unknown]
                .map(\.rawValue)
        )
        for event in Self.samples {
            for (key, value) in event.parameters {
                switch value {
                case is Int, is Int64:
                    continue
                case let string as String:
                    // 文字列は reason（有限カテゴリ）だけ許可する。
                    #expect(key == "reason", "文字列値は reason のみ許可: \(key)=\(string)")
                    #expect(allowedReasons.contains(string), "未知の reason 値: \(string)")
                default:
                    Issue.record("想定外の値型: \(key)=\(value) (\(type(of: value)))")
                }
            }
        }
    }

    /// エラーは機微情報を捨てて有限カテゴリに畳み込まれる。
    @Test func failureReasonMapsErrorsToCategories() {
        #expect(AnalyticsFailureReason(URLError(.notConnectedToInternet)) == .network)
        #expect(AnalyticsFailureReason(URLError(.cancelled)) == .cancelled)
        #expect(AnalyticsFailureReason(CancellationError()) == .cancelled)
        #expect(AnalyticsFailureReason(NSError(domain: "x", code: 1)) == .unknown)
    }
}
