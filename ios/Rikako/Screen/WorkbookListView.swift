import SwiftUI

struct WorkbookListView: View {
    @State private var workbooks: [Workbook] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("読み込み中...")
            } else if let errorMessage {
                ContentUnavailableView {
                    Label("読み込みエラー", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("再読み込み") {
                        Task { await loadWorkbooks() }
                    }
                }
            } else if workbooks.isEmpty {
                ContentUnavailableView("問題集がありません", systemImage: "book")
            } else {
                List {
                    ForEach(workbooks) { workbook in
                        NavigationLink(destination: WorkbookDetailView(workbookID: workbook.id)) {
                            WorkbookRow(workbook: workbook)
                        }
                    }
                }
            }
        }
        .navigationTitle("問題集")
        .task {
            await loadWorkbooks()
        }
    }

    private func loadWorkbooks() async {
        isLoading = true
        errorMessage = nil
        do {
            workbooks = try await APIClient.shared.fetchWorkbooks()
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

struct WorkbookRow: View {
    let workbook: Workbook

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(workbook.title)
                .font(.headline)
            Text(workbook.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("\(workbook.questionCount)問")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        WorkbookListView()
    }
}
