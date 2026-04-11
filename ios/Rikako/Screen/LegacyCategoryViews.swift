import SwiftUI

struct LegacyCategoryListView: View {
    @State private var categories: [Category] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
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
                            Task { await loadCategories() }
                        }
                    }
                } else {
                    List(categories) { category in
                        NavigationLink(destination: LegacyCategoryDetailView(category: category)) {
                            LegacyCategoryRow(
                                symbol: "books.vertical.fill",
                                title: category.title,
                                subtitle: category.description,
                                count: category.workbookCount
                            )
                        }
                    }
                }
            }
            .navigationTitle("カテゴリ一覧")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await loadCategories()
        }
    }

    private func loadCategories() async {
        isLoading = true
        errorMessage = nil
        do {
            categories = try await APIClient.shared.fetchCategories()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct LegacyCategoryDetailView: View {
    let category: Category

    @State private var detail: CategoryDetail?
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
                        Task { await loadDetail() }
                    }
                }
            } else if let detail {
                List {
                    if let description = detail.description, !description.isEmpty {
                        Section {
                            Text(description)
                                .foregroundStyle(.secondary)
                        }
                    }

                    ForEach(detail.workbooks) { workbook in
                        NavigationLink(destination: WorkbookDetailView(workbookID: workbook.id)) {
                            LegacyCategoryRow(
                                symbol: "doc.text.image",
                                title: workbook.title,
                                subtitle: workbook.description,
                                count: workbook.questionCount
                            )
                        }
                    }
                }
            } else {
                ContentUnavailableView("カテゴリが見つかりません", systemImage: "books.vertical")
            }
        }
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadDetail()
        }
    }

    private func loadDetail() async {
        isLoading = true
        errorMessage = nil
        do {
            detail = try await APIClient.shared.fetchCategoryDetail(id: category.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct LegacyCategoryRow: View {
    let symbol: String
    let title: String
    let subtitle: String?
    let count: Int?

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color("correctPink").opacity(0.18))
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(Color("main"))
            }
            .frame(width: 60, height: 60)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                if let count {
                    Text("\(count)件")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    LegacyCategoryListView()
}
