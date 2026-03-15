import SwiftUI

struct WorkbookListView: View {
    let workbooks = MockData.workbooks

    var body: some View {
        List(workbooks) { workbook in
            NavigationLink(destination: WorkbookDetailView(workbookID: workbook.id)) {
                WorkbookRow(workbook: workbook)
            }
        }
        .navigationTitle("問題集")
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
