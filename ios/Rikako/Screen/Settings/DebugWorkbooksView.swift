import SwiftUI

// MARK: - 問題集一覧

struct DebugWorkbooksView: View {
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
                    Button("再読み込み") { Task { await load() } }
                }
            } else if workbooks.isEmpty {
                ContentUnavailableView("問題集がありません", systemImage: "book")
            } else {
                List {
                    ForEach(workbooks) { workbook in
                        NavigationLink(destination: DebugWorkbookDetailView(workbookID: workbook.id)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(workbook.title).font(.headline)
                                Text("\(workbook.questionCount)問").font(.caption).foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
        .navigationTitle("問題集 (Debug)")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            workbooks = try await AppContainer.shared.learningUseCases.fetchWorkbooks.execute()
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

// MARK: - 問題一覧

struct DebugWorkbookDetailView: View {
    let workbookID: Int64
    @State private var workbook: WorkbookDetail?
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
                    Button("再読み込み") { Task { await load() } }
                }
            } else if let workbook {
                List {
                    ForEach(Array(workbook.questions.enumerated()), id: \.element.id) { index, question in
                        NavigationLink(destination: DebugQuestionDetailView(index: index + 1, question: question)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Q\(index + 1)").font(.caption.bold()).foregroundStyle(.secondary)
                                Text(question.text).font(.subheadline).lineLimit(2)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                .navigationTitle(workbook.title)
            } else {
                ContentUnavailableView("問題集が見つかりません", systemImage: "exclamationmark.triangle")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            workbook = try await AppContainer.shared.learningUseCases.fetchWorkbookDetail.execute(id: workbookID)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

// MARK: - 問題詳細

struct DebugQuestionDetailView: View {
    let index: Int
    let question: Question

    var body: some View {
        List {
            Section("問題") {
                Text(question.text)
                    .font(.body)
                    .textSelection(.enabled)
            }

            Section("選択肢") {
                ForEach(Array(question.choices.enumerated()), id: \.offset) { i, choice in
                    HStack(spacing: 10) {
                        Image(systemName: i == question.correctIndex ? "circle.fill" : "circle")
                            .foregroundStyle(i == question.correctIndex ? .green : .secondary)
                            .frame(width: 20)
                        Text(choice)
                            .font(.subheadline)
                            .foregroundStyle(i == question.correctIndex ? .primary : .secondary)
                        if i == question.correctIndex {
                            Spacer()
                            Text("正解").font(.caption.bold()).foregroundStyle(.green)
                        }
                    }
                }
            }

            if let explanation = question.explanation, !explanation.isEmpty {
                Section("解説") {
                    Text(explanation)
                        .font(.subheadline)
                        .textSelection(.enabled)
                }
            }

            Section("メタ情報") {
                row(title: "問題ID", value: String(question.id))
                row(title: "種別", value: question.type.rawValue)
                if let images = question.images, !images.isEmpty {
                    row(title: "画像数", value: "\(images.count)枚")
                }
            }
        }
        .navigationTitle("Q\(index) (Debug)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary).font(.caption).textSelection(.enabled)
        }
    }
}
