import Foundation
import Observation

@Observable
@MainActor
final class StudyHomeViewModel {
    struct Chapter: Identifiable {
        let id: Int
        let title: String
        let questionCount: Int
        let isLocked: Bool
    }

    var workbooks: [Workbook] = []
    var workbookDetail: WorkbookDetail?
    var isLoading = true
    var isDetailLoading = false
    var errorMessage: String?
    var isShowingWorkbookPicker = false

    private let fetchWorkbooksUseCase: FetchWorkbooksUseCase
    private let fetchWorkbookDetailUseCase: FetchWorkbookDetailUseCase

    init(fetchWorkbooksUseCase: FetchWorkbooksUseCase, fetchWorkbookDetailUseCase: FetchWorkbookDetailUseCase) {
        self.fetchWorkbooksUseCase = fetchWorkbooksUseCase
        self.fetchWorkbookDetailUseCase = fetchWorkbookDetailUseCase
    }

    func selectedWorkbook(selectedWorkbookID: Int64?) -> Workbook? {
        guard let selectedWorkbookID else { return workbooks.first }
        return workbooks.first(where: { $0.id == selectedWorkbookID }) ?? workbooks.first
    }

    func loadInitialState(selectedWorkbookID: Int64?) async throws -> Int64? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            workbooks = try await fetchWorkbooksUseCase.execute()
            if let selectedWorkbookID {
                return selectedWorkbookID
            }
            return workbooks.first?.id
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func loadSelectedWorkbookDetail(selectedWorkbookID: Int64?) async {
        guard let selectedWorkbookID else {
            workbookDetail = nil
            return
        }

        isDetailLoading = true
        defer { isDetailLoading = false }

        do {
            workbookDetail = try await fetchWorkbookDetailUseCase.execute(id: selectedWorkbookID)
        } catch {
            workbookDetail = nil
        }
    }

    func chapters() -> [Chapter] {
        guard let workbookDetail else { return [] }
        let size = 10
        let total = workbookDetail.questions.count
        let chunkCount = Int(ceil(Double(total) / Double(size)))
        return (0..<chunkCount).map { index in
            let start = index * size
            let end = min(start + size, total)
            return Chapter(
                id: index + 1,
                title: "第\(index + 1)章 Lesson \(index + 1)",
                questionCount: max(end - start, 0),
                isLocked: index > 0
            )
        }
    }
}
