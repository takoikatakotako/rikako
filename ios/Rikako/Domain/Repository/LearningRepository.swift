import Foundation

protocol LearningRepository {
    func fetchWorkbooks() async throws -> [Workbook]
    func fetchWorkbookDetail(id: Int64) async throws -> WorkbookDetail
    func fetchCategories(limit: Int, offset: Int) async throws -> [Category]
    func fetchCategoryDetail(id: Int64) async throws -> CategoryDetail
    func submitAnswers(workbookId: Int64, answers: [AnswerItem]) async throws -> AnswerSubmissionResponse
    func fetchWrongAnswers(limit: Int, offset: Int) async throws -> WrongAnswerListResponse
    func anonymousSignIn() async throws -> String
}
