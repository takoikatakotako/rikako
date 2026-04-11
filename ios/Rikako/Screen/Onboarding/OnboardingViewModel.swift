import Foundation
import Observation

@Observable
@MainActor
final class OnboardingViewModel {
    var recommendedWorkbook: Workbook?
    var isLoading = true
    var errorMessage: String?

    private let fetchWorkbooksUseCase: FetchWorkbooksUseCase

    init(fetchWorkbooksUseCase: FetchWorkbooksUseCase) {
        self.fetchWorkbooksUseCase = fetchWorkbooksUseCase
    }

    func loadRecommendedWorkbookIfNeeded() async {
        guard recommendedWorkbook == nil else { return }
        await loadRecommendedWorkbook()
    }

    func loadRecommendedWorkbook() async {
        isLoading = true
        errorMessage = nil
        do {
            recommendedWorkbook = try await fetchWorkbooksUseCase.execute().first
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
