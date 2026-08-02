import Foundation

/// 非クラッシュ失敗の分類。生のエラーメッセージ（PII やパスを含みうる）ではなく、
/// この有限集合のカテゴリだけをイベントに載せる。
enum AnalyticsFailureReason: String {
    case network
    case server
    case decoding
    case cancelled
    case unauthorized
    case unknown

    /// 任意の Error を、機微情報を捨ててカテゴリに畳み込む。
    init(_ error: Error) {
        switch error {
        case is CancellationError:
            self = .cancelled
        case let urlError as URLError:
            self = urlError.code == .cancelled ? .cancelled : .network
        default:
            self = .unknown
        }
    }
}

/// アプリ内の利用イベント。意思決定に必要な最小集合だけを定義する。
///
/// - 重要: associated value には**識別子・件数・カテゴリのような非 PII のスカラーのみ**を持たせる。
///   ユーザー入力本文・問題文・メールアドレス・Cognito Identity ID などは絶対に含めない。
///   （`parameters` が非 PII であることは `AnalyticsEventTests` で検証している）
enum AnalyticsEvent {
    case appOpen
    case onboardingStarted
    case onboardingStepViewed(step: Int)
    case onboardingCompleted
    case workbookStarted(workbookID: Int64)
    case workbookCompleted(workbookID: Int64)
    case answersSubmitted(workbookID: Int64?, count: Int)
    case answersSubmissionFailed(reason: AnalyticsFailureReason)
    case aiChatStarted
    case aiChatSucceeded
    case aiChatFailed(reason: AnalyticsFailureReason)
    case transferStarted
    case transferCompleted
    case transferFailed(reason: AnalyticsFailureReason)

    /// Firebase のイベント名制約に合わせた snake_case 名（英数字と `_`、40 文字以内、先頭は英字）。
    var name: String {
        switch self {
        case .appOpen: return "app_open"
        case .onboardingStarted: return "onboarding_started"
        case .onboardingStepViewed: return "onboarding_step_viewed"
        case .onboardingCompleted: return "onboarding_completed"
        case .workbookStarted: return "workbook_started"
        case .workbookCompleted: return "workbook_completed"
        case .answersSubmitted: return "answers_submitted"
        case .answersSubmissionFailed: return "answers_submission_failed"
        case .aiChatStarted: return "ai_chat_started"
        case .aiChatSucceeded: return "ai_chat_succeeded"
        case .aiChatFailed: return "ai_chat_failed"
        case .transferStarted: return "transfer_started"
        case .transferCompleted: return "transfer_completed"
        case .transferFailed: return "transfer_failed"
        }
    }

    /// イベントに添付するパラメータ。値は Int / String（有限カテゴリ）のみ。
    var parameters: [String: Any] {
        switch self {
        case .onboardingStepViewed(let step):
            return ["step": step]
        case .workbookStarted(let id), .workbookCompleted(let id):
            return ["workbook_id": id]
        case .answersSubmitted(let workbookID, let count):
            var params: [String: Any] = ["count": count]
            if let workbookID { params["workbook_id"] = workbookID }
            return params
        case .answersSubmissionFailed(let reason),
             .aiChatFailed(let reason),
             .transferFailed(let reason):
            return ["reason": reason.rawValue]
        case .appOpen, .onboardingStarted, .onboardingCompleted,
             .aiChatStarted, .aiChatSucceeded,
             .transferStarted, .transferCompleted:
            return [:]
        }
    }
}
