import Foundation

struct LearningUseCases {
    let fetchAppStatus: FetchAppStatusUseCase
    let fetchWorkbooks: FetchWorkbooksUseCase
    let fetchWorkbookDetail: FetchWorkbookDetailUseCase
    let fetchCategories: FetchCategoriesUseCase
    let fetchCategoryDetail: FetchCategoryDetailUseCase
    let submitAnswers: SubmitAnswersUseCase
    let fetchWrongAnswers: FetchWrongAnswersUseCase
    let fetchAnswerLogs: FetchAnswerLogsUseCase
    let fetchWorkbookProgress: FetchWorkbookProgressUseCase
    let fetchUserSummary: FetchUserSummaryUseCase
    let fetchUserProfile: FetchUserProfileUseCase
    let updateUserProfile: UpdateUserProfileUseCase
    let fetchAnnouncements: FetchAnnouncementsUseCase
    let fetchTransferToken: FetchTransferTokenUseCase
    let refreshTransferToken: RefreshTransferTokenUseCase
    let applyTransferToken: ApplyTransferTokenUseCase
    let chatWithQuestion: ChatWithQuestionUseCase
    let submitContact: SubmitContactUseCase

    init(repository: LearningRepository) {
        self.fetchAppStatus = FetchAppStatusUseCase(repository: repository)
        self.fetchWorkbooks = FetchWorkbooksUseCase(repository: repository)
        self.fetchWorkbookDetail = FetchWorkbookDetailUseCase(repository: repository)
        self.fetchCategories = FetchCategoriesUseCase(repository: repository)
        self.fetchCategoryDetail = FetchCategoryDetailUseCase(repository: repository)
        self.submitAnswers = SubmitAnswersUseCase(repository: repository)
        self.fetchWrongAnswers = FetchWrongAnswersUseCase(repository: repository)
        self.fetchAnswerLogs = FetchAnswerLogsUseCase(repository: repository)
        self.fetchWorkbookProgress = FetchWorkbookProgressUseCase(repository: repository)
        self.fetchUserSummary = FetchUserSummaryUseCase(repository: repository)
        self.fetchUserProfile = FetchUserProfileUseCase(repository: repository)
        self.updateUserProfile = UpdateUserProfileUseCase(repository: repository)
        self.fetchAnnouncements = FetchAnnouncementsUseCase(repository: repository)
        self.fetchTransferToken = FetchTransferTokenUseCase(repository: repository)
        self.refreshTransferToken = RefreshTransferTokenUseCase(repository: repository)
        self.applyTransferToken = ApplyTransferTokenUseCase(repository: repository)
        self.chatWithQuestion = ChatWithQuestionUseCase(repository: repository)
        self.submitContact = SubmitContactUseCase(repository: repository)
    }
}

struct FetchTransferTokenUseCase {
    private let repository: LearningRepository
    init(repository: LearningRepository) { self.repository = repository }
    func execute() async throws -> TransferToken {
        try await repository.fetchTransferToken()
    }
}

struct RefreshTransferTokenUseCase {
    private let repository: LearningRepository
    init(repository: LearningRepository) { self.repository = repository }
    func execute() async throws -> TransferToken {
        try await repository.refreshTransferToken()
    }
}

struct ApplyTransferTokenUseCase {
    private let repository: LearningRepository
    init(repository: LearningRepository) { self.repository = repository }
    func execute(token: String) async throws -> String {
        try await repository.applyTransferToken(token)
    }
}

struct FetchAnnouncementsUseCase {
    private let repository: LearningRepository

    init(repository: LearningRepository) {
        self.repository = repository
    }

    func execute() async throws -> [Announcement] {
        try await repository.fetchAnnouncements()
    }
}

struct ChatWithQuestionUseCase {
    private let repository: LearningRepository
    init(repository: LearningRepository) { self.repository = repository }
    func execute(questionId: Int64, messages: [ChatMessageRequest], selectedChoice: Int) async throws -> ChatResponse {
        try await repository.chatWithQuestion(questionId: questionId, messages: messages, selectedChoice: selectedChoice)
    }
}

struct SubmitContactUseCase {
    private let repository: LearningRepository
    init(repository: LearningRepository) { self.repository = repository }
    func execute(subject: String?, body: String, email: String?, userId: String?, deviceModel: String?, osVersion: String?, appVersion: String?) async throws {
        try await repository.submitContact(subject: subject, body: body, email: email, userId: userId, deviceModel: deviceModel, osVersion: osVersion, appVersion: appVersion)
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

struct FetchWorkbookProgressUseCase {
    private let repository: LearningRepository
    init(repository: LearningRepository) { self.repository = repository }
    func execute(workbookId: Int64) async throws -> WorkbookProgressResponse {
        try await repository.fetchWorkbookProgress(workbookId: workbookId)
    }
}

struct FetchUserSummaryUseCase {
    private let repository: LearningRepository
    init(repository: LearningRepository) { self.repository = repository }
    func execute() async throws -> UserSummary {
        try await repository.fetchUserSummary()
    }
}

struct FetchAnswerLogsUseCase {
    private let repository: LearningRepository

    init(repository: LearningRepository) {
        self.repository = repository
    }

    func execute(limit: Int = 50, offset: Int = 0) async throws -> AnswerLogsResponse {
        try await repository.fetchAnswerLogs(limit: limit, offset: offset)
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
