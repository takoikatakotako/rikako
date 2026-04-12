import Foundation

final class PreviewLearningRepository: LearningRepository {
    private let workbooks: [Workbook] = [
        Workbook(
            id: 1,
            title: "基礎化学のはじめの一歩",
            description: "まずは化学の基本用語と考え方に慣れるための問題集です。",
            questionCount: 12,
            categoryId: 1
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

    static func makeOnboardingViewModel() -> OnboardingViewModel {
        OnboardingViewModel(fetchWorkbooksUseCase: learningUseCases.fetchWorkbooks)
    }
}
