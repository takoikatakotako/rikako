import SwiftUI

struct WorkbookListView: View {
    @State private var selectedCategoryRaw = ""

    private var selectedCategory: Category? {
        Category(rawValue: selectedCategoryRaw)
    }

    private var workbooks: [Workbook] {
        if let category = selectedCategory {
            return MockData.workbooks(for: category)
        }
        return MockData.workbooks
    }

    var body: some View {
        List {
            if let category = selectedCategory {
                Section {
                    HStack {
                        Image(systemName: category.icon)
                            .foregroundStyle(Color.accentColor)
                        Text(category.displayName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                ForEach(workbooks) { workbook in
                    NavigationLink(destination: WorkbookDetailView(workbookID: workbook.id)) {
                        WorkbookRow(workbook: workbook)
                    }
                }
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
