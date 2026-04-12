import Foundation
import Observation

@Observable
@MainActor
final class OnboardingViewModel {
    var workbooks: [Workbook] = []
    var recommendedWorkbook: Workbook?
    var isLoading = true
    var errorMessage: String?

    private let fetchWorkbooksUseCase: FetchWorkbooksUseCase

    init(fetchWorkbooksUseCase: FetchWorkbooksUseCase) {
        self.fetchWorkbooksUseCase = fetchWorkbooksUseCase
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

    func start(appState: AppState) {
        let anonymousUserId = appState.anonymousUserId ?? "mock-anonymous-\(UUID().uuidString)"
        appState.completeOnboarding(anonymousUserId: anonymousUserId)
    }
}
