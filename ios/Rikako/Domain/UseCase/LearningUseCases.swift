import Foundation

struct LearningUseCases {
    let fetchAppStatus: FetchAppStatusUseCase
    let fetchWorkbooks: FetchWorkbooksUseCase
    let fetchWorkbookDetail: FetchWorkbookDetailUseCase
    let fetchCategories: FetchCategoriesUseCase
    let fetchCategoryDetail: FetchCategoryDetailUseCase
    let submitAnswers: SubmitAnswersUseCase
    let fetchWrongAnswers: FetchWrongAnswersUseCase
    let fetchUserProfile: FetchUserProfileUseCase
    let updateUserProfile: UpdateUserProfileUseCase

    init(repository: LearningRepository) {
        self.fetchAppStatus = FetchAppStatusUseCase(repository: repository)
        self.fetchWorkbooks = FetchWorkbooksUseCase(repository: repository)
        self.fetchWorkbookDetail = FetchWorkbookDetailUseCase(repository: repository)
        self.fetchCategories = FetchCategoriesUseCase(repository: repository)
        self.fetchCategoryDetail = FetchCategoryDetailUseCase(repository: repository)
        self.submitAnswers = SubmitAnswersUseCase(repository: repository)
        self.fetchWrongAnswers = FetchWrongAnswersUseCase(repository: repository)
        self.fetchUserProfile = FetchUserProfileUseCase(repository: repository)
        self.updateUserProfile = UpdateUserProfileUseCase(repository: repository)
    }
}

struct FetchAppStatusUseCase {
    private let repository: LearningRepository

    init(repository: LearningRepository) {
        self.repository = repository
    }

    func execute() async throws -> AppStatusResponse {
        try await repository.fetchAppStatus()
    }
}

struct FetchWorkbooksUseCase {
    private let repository: LearningRepository

    init(repository: LearningRepository) {
        self.repository = repository
    }

    func execute() async throws -> [Workbook] {
        try await repository.fetchWorkbooks()
    }
}

struct FetchWorkbookDetailUseCase {
    private let repository: LearningRepository

    init(repository: LearningRepository) {
        self.repository = repository
    }

    func execute(id: Int64) async throws -> WorkbookDetail {
        try await repository.fetchWorkbookDetail(id: id)
    }
}

struct FetchCategoriesUseCase {
    private let repository: LearningRepository

    init(repository: LearningRepository) {
        self.repository = repository
    }

    func execute(limit: Int = 50, offset: Int = 0) async throws -> [Category] {
        try await repository.fetchCategories(limit: limit, offset: offset)
    }
}

struct FetchCategoryDetailUseCase {
    private let repository: LearningRepository

    init(repository: LearningRepository) {
        self.repository = repository
    }

    func execute(id: Int64) async throws -> CategoryDetail {
        try await repository.fetchCategoryDetail(id: id)
    }
}

struct SubmitAnswersUseCase {
    private let repository: LearningRepository

    init(repository: LearningRepository) {
        self.repository = repository
    }

    func execute(workbookId: Int64, answers: [AnswerItem]) async throws -> AnswerSubmissionResponse {
        try await repository.submitAnswers(workbookId: workbookId, answers: answers)
    }
}

struct FetchWrongAnswersUseCase {
    private let repository: LearningRepository

    init(repository: LearningRepository) {
        self.repository = repository
    }

    func execute(limit: Int = 50, offset: Int = 0) async throws -> WrongAnswerListResponse {
        try await repository.fetchWrongAnswers(limit: limit, offset: offset)
    }
}

struct FetchUserProfileUseCase {
    private let repository: LearningRepository

    init(repository: LearningRepository) {
        self.repository = repository
    }

    func execute(appSlug: String) async throws -> UserProfile {
        try await repository.fetchUserProfile(appSlug: appSlug)
    }
}

struct UpdateUserProfileUseCase {
    private let repository: LearningRepository

    init(repository: LearningRepository) {
        self.repository = repository
    }

    func execute(appSlug: String, request: UpdateUserProfileRequest) async throws -> UserProfile {
        try await repository.updateUserProfile(appSlug: appSlug, request: request)
    }
}
