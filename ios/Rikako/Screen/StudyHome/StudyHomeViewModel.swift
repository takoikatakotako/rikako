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
        let chunkSize = 10
        let total = workbookDetail.questions.count
        let chunkCount = Int(ceil(Double(total) / Double(chunkSize)))
        return (0..<chunkCount).map { index in
            let start = index * chunkSize
            let end = min(start + chunkSize, total)
            return Chapter(
                id: index + 1,
                title: "第\(index + 1)章 Lesson \(index + 1)",
                questionCount: max(end - start, 0),
                isLocked: index > 0
            )
        }
    }

    func questions(for chapter: Chapter) -> [Question] {
        guard let workbookDetail else { return [] }
        let chunkSize = 10
        let start = max((chapter.id - 1) * chunkSize, 0)
        let end = min(start + chunkSize, workbookDetail.questions.count)
        guard start < end else { return [] }
        return Array(workbookDetail.questions[start..<end])
    }

    func firstChapterQuestions() -> [Question] {
        guard let firstChapter = chapters().first else { return [] }
        return questions(for: firstChapter)
    }

    #if DEBUG
    static func previewLoading() -> StudyHomeViewModel {
        let vm = StudyHomeViewModel(
            fetchWorkbooksUseCase: PreviewAppContainer.makeLearningUseCases().fetchWorkbooks,
            fetchWorkbookDetailUseCase: PreviewAppContainer.makeLearningUseCases().fetchWorkbookDetail
        )
        vm.isLoading = true
        return vm
    }

    static func previewError() -> StudyHomeViewModel {
        let vm = StudyHomeViewModel(
            fetchWorkbooksUseCase: PreviewAppContainer.makeLearningUseCases().fetchWorkbooks,
            fetchWorkbookDetailUseCase: PreviewAppContainer.makeLearningUseCases().fetchWorkbookDetail
        )
        vm.isLoading = false
        vm.errorMessage = "ネットワーク接続を確認してください。"
        return vm
    }
    #endif
}
