import Foundation

final class PreviewLearningRepository: LearningRepository {
    private let workbooks: [Workbook] = [
        Workbook(
            id: 1,
            title: "基礎化学のはじめの一歩",
            description: "まずは化学の基本用語と考え方に慣れるための問題集です。",
            questionCount: 12,
            categoryId: 1
        ),
        Workbook(
            id: 2,
            title: "化学結合の基礎",
            description: "イオン結合や共有結合など、化学結合の基本を確認する問題集です。",
            questionCount: 18,
            categoryId: 1
        ),
        Workbook(
            id: 3,
            title: "酸と塩基の入門",
            description: "pH、電離、酸と塩基の考え方をやさしく学ぶ問題集です。",
            questionCount: 15,
            categoryId: 2
        ),
        Workbook(
            id: 4,
            title: "物質量とモル計算",
            description: "mol の考え方と計算に慣れるための問題集です。",
            questionCount: 20,
            categoryId: 2
        ),
        Workbook(
            id: 5,
            title: "酸化還元の基礎",
            description: "酸化数や電子のやり取りを基礎から確認する問題集です。",
            questionCount: 16,
            categoryId: 3
        ),
        Workbook(
            id: 6,
            title: "有機化学のさわり",
            description: "炭化水素や官能基の最初の理解に向いた問題集です。",
            questionCount: 14,
            categoryId: 4
        ),
        Workbook(
            id: 7,
            title: "無機化学の基本整理",
            description: "金属元素や気体の性質を整理しながら学ぶ問題集です。",
            questionCount: 19,
            categoryId: 5
        )
    ]

    func fetchAppStatus() async throws -> AppStatusResponse {
        AppStatusResponse(minimumVersion: "1.0.0", latestVersion: "1.0.0", isMaintenance: false, maintenanceMessage: "")
    }

    func fetchWorkbooks() async throws -> [Workbook] {
        workbooks
    }

    func fetchWorkbookDetail(id: Int64) async throws -> WorkbookDetail {
        WorkbookDetail(
            id: id,
            title: workbooks.first?.title ?? "プレビュー問題集",
            description: workbooks.first?.description ?? "プレビュー用の問題集です。",
            categoryId: workbooks.first?.categoryId,
            questions: MockData.questions
        )
    }

    func fetchCategories(limit: Int, offset: Int) async throws -> [Category] {
        [
            Category(
                id: 1,
                title: "基礎化学",
                description: "化学の最初の一歩を学ぶカテゴリです。",
                workbookCount: workbooks.count
            )
        ]
    }

    func fetchCategoryDetail(id: Int64) async throws -> CategoryDetail {
        CategoryDetail(
            id: id,
            title: "基礎化学",
            description: "化学の最初の一歩を学ぶカテゴリです。",
            workbooks: workbooks
        )
    }

    func submitAnswers(workbookId: Int64, answers: [AnswerItem]) async throws -> AnswerSubmissionResponse {
        AnswerSubmissionResponse(
            correctCount: answers.filter { answer in
                MockData.questions.first(where: { $0.id == answer.questionId })?.correctIndex == answer.selectedChoice
            }.count,
            totalCount: answers.count
        )
    }

    func anonymousSignIn() async throws -> String {
        "preview-anonymous-\(UUID().uuidString)"
    }

    func fetchUserProfile(appSlug: String) async throws -> UserProfile {
        UserProfile(identityId: "preview-identity", displayName: "理科子", selectedWorkbookId: 1)
    }

    func updateUserProfile(appSlug: String, request: UpdateUserProfileRequest) async throws -> UserProfile {
        UserProfile(identityId: "preview-identity", displayName: request.displayName, selectedWorkbookId: request.selectedWorkbookId)
    }

    func fetchAnswerLogs(limit: Int, offset: Int) async throws -> AnswerLogsResponse {
        AnswerLogsResponse(logs: [], total: 0)
    }

    func fetchWorkbookProgress(workbookId: Int64) async throws -> WorkbookProgressResponse {
        WorkbookProgressResponse(results: [])
    }

    func fetchUserSummary() async throws -> UserSummary {
        UserSummary(
            totalAnswered: 156,
            totalCorrect: 132,
            weeklyAnswered: 42,
            weeklyCorrect: 35,
            studyDates: Self.previewStudyDates(),
            weeklyWorkbookIds: [5, 6]
        )
    }

    /// スクショ/プレビュー用の学習日データ。撮影日を基準に、直近を連続学習（連続日数）にしつつ
    /// 過去60日を程よく埋めてヒートマップが映えるようにする。
    private static func previewStudyDates() -> [String] {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Asia/Tokyo")
        let cal = Calendar(identifier: .gregorian)
        let today = Date()
        var dates: [String] = []
        for offset in 0..<60 {
            guard let d = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            // 直近12日は連続（streak確保）、それ以前は大半を学習済みにして適度に穴を空ける。
            if offset < 12 || (offset % 7 != 3 && offset % 5 != 2) {
                dates.append(f.string(from: d))
            }
        }
        return dates
    }

    func fetchWrongAnswers(limit: Int, offset: Int) async throws -> WrongAnswerListResponse {
        let waq = MockData.questions.prefix(limit).map {
            WrongAnswerQuestion(id: $0.id, type: $0.type, text: $0.text, choices: $0.choices, correct: $0.correct, explanation: $0.explanation, images: $0.images, workbookId: 1)
        }
        return WrongAnswerListResponse(questions: Array(waq), total: min(limit, MockData.questions.count))
    }

    func fetchAnnouncements() async throws -> [Announcement] {
        let now = Date()
        return [
            Announcement(
                id: 1,
                title: "春のチャレンジ応援キャンペーン",
                body: "# キャンペーン開催\n期間限定で学習を続けやすい企画を実施中です。\n\n- ログインボーナス\n- 連続学習バッジ",
                category: "info",
                publishedAt: now.addingTimeInterval(-60 * 60 * 3)
            ),
            Announcement(
                id: 2,
                title: "新しい問題集を追加しました",
                body: "基礎化学の復習に使いやすい問題集を追加しました。",
                category: "release",
                publishedAt: now.addingTimeInterval(-60 * 60 * 24 * 2)
            ),
            Announcement(
                id: 3,
                title: "メンテナンスのお知らせ",
                body: "一時的にサービスが利用できなくなる可能性があります。",
                category: "maintenance",
                publishedAt: now.addingTimeInterval(-60 * 60 * 24 * 10)
            )
        ]
    }
}

extension PreviewLearningRepository {
    func fetchTransferToken() async throws -> TransferToken {
        TransferToken(token: "preview-token-abcdef1234567890", expiresAt: Date().addingTimeInterval(3 * 365 * 24 * 3600))
    }
    func refreshTransferToken() async throws -> TransferToken {
        TransferToken(token: "preview-token-new-\(UUID().uuidString.prefix(8))", expiresAt: Date().addingTimeInterval(3 * 365 * 24 * 3600))
    }
    func applyTransferToken(_ token: String) async throws -> String {
        "preview-identity-id-from-transfer"
    }
    func chatWithQuestion(questionId: Int64, messages: [ChatMessageRequest], selectedChoice: Int) async throws -> ChatResponse {
        let reply = "いい質問だね！水分子は酸素原子1個と水素原子2個が結びついてできているから、化学式は H₂O と書くよ。\n\nCO₂ は二酸化炭素、NaCl は塩化ナトリウム（食塩）、O₂ は酸素だから、どれも水とは別の物質なんだ。まずは「H＝水素」「O＝酸素」と覚えるのがコツだよ！"
        return ChatResponse(reply: reply, turnCount: messages.filter { $0.role == "user" }.count, remainingTurns: 10 - messages.filter { $0.role == "user" }.count)
    }

    func submitContact(subject: String?, body: String, email: String?, userId: String?, deviceModel: String?, osVersion: String?, appVersion: String?) async throws {}
}

final class PreviewDeviceIdentityProvider: DeviceIdentityProviding {
    private(set) var identityId = "preview-identity-id"
    func getIdentityId() async throws -> String { identityId }
    func overrideIdentityId(_ id: String) { identityId = id }
}

enum PreviewAppContainer {
    private static let learningUseCases = LearningUseCases(repository: PreviewLearningRepository())

    static func makeLearningUseCases() -> LearningUseCases {
        learningUseCases
    }

    static func makeOnboardingViewModel() -> OnboardingViewModel {
        OnboardingViewModel(
            fetchWorkbooksUseCase: learningUseCases.fetchWorkbooks,
            anonymousSignIn: { "preview-anonymous-\(UUID().uuidString)" },
            analytics: NoopAnalyticsClient()
        )
    }
}
