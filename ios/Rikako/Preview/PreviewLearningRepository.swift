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

    func fetchWrongAnswers(limit: Int, offset: Int) async throws -> WrongAnswerListResponse {
        WrongAnswerListResponse(
            questions: Array(MockData.questions.prefix(limit)),
            total: min(limit, MockData.questions.count)
        )
    }
}

enum PreviewAppContainer {
    private static let learningUseCases = LearningUseCases(repository: PreviewLearningRepository())

    static func makeLearningUseCases() -> LearningUseCases {
        learningUseCases
    }

    static func makeOnboardingViewModel() -> OnboardingViewModel {
        OnboardingViewModel(fetchWorkbooksUseCase: learningUseCases.fetchWorkbooks)
    }
}
