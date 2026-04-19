import Foundation

struct UserProfile: Codable {
    var userId: Int64?
    let identityId: String
    var displayName: String?
    var selectedWorkbookId: Int64?
}

struct UpdateUserProfileRequest: Encodable {
    var displayName: String?
    var selectedWorkbookId: Int64?
}

protocol LearningRepository {
    func fetchAppStatus() async throws -> AppStatusResponse
    func fetchWorkbooks() async throws -> [Workbook]
    func fetchWorkbookDetail(id: Int64) async throws -> WorkbookDetail
    func fetchCategories(limit: Int, offset: Int) async throws -> [Category]
    func fetchCategoryDetail(id: Int64) async throws -> CategoryDetail
    func submitAnswers(workbookId: Int64, answers: [AnswerItem]) async throws -> AnswerSubmissionResponse
    func fetchWrongAnswers(limit: Int, offset: Int) async throws -> WrongAnswerListResponse
    func fetchAnswerLogs(limit: Int, offset: Int) async throws -> AnswerLogsResponse
    func fetchWorkbookProgress(workbookId: Int64) async throws -> WorkbookProgressResponse
    func fetchUserSummary() async throws -> UserSummary
    func anonymousSignIn() async throws -> String
    func fetchUserProfile(appSlug: String) async throws -> UserProfile
    func updateUserProfile(appSlug: String, request: UpdateUserProfileRequest) async throws -> UserProfile
}
