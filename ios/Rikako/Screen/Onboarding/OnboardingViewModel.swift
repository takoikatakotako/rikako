import Foundation
import Observation

@Observable
@MainActor
final class OnboardingViewModel {
    var workbooks: [Workbook] = []
    var recommendedWorkbook: Workbook?
    var isLoading = true
    var errorMessage: String?
    var isStarting = false
    var startErrorMessage: String?

    private let fetchWorkbooksUseCase: FetchWorkbooksUseCase
    private let anonymousSignIn: () async throws -> String

    init(fetchWorkbooksUseCase: FetchWorkbooksUseCase, anonymousSignIn: @escaping () async throws -> String) {
        self.fetchWorkbooksUseCase = fetchWorkbooksUseCase
        self.anonymousSignIn = anonymousSignIn
    }

    var otherWorkbooks: [Workbook] {
        guard let recommendedWorkbook else { return workbooks }
        return workbooks.filter { $0.id != recommendedWorkbook.id }
    }

    func loadRecommendedWorkbookIfNeeded() async {
        guard workbooks.isEmpty else { return }
        await loadRecommendedWorkbook()
    }

    func loadRecommendedWorkbook() async {
        isLoading = true
        errorMessage = nil
        do {
            let fetchedWorkbooks = try await fetchWorkbooksUseCase.execute()
            workbooks = fetchedWorkbooks
            recommendedWorkbook = fetchedWorkbooks.first
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func start(appState: AppState) async {
        isStarting = true
        startErrorMessage = nil
        do {
            let identityId = try await anonymousSignIn()
            appState.completeOnboarding(anonymousUserId: identityId)
        } catch {
            startErrorMessage = error.localizedDescription
        }
        isStarting = false
    }
}
