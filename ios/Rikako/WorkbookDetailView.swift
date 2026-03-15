import SwiftUI

struct WorkbookDetailView: View {
    let workbookID: Int64

    private var workbook: WorkbookDetail? {
        MockData.workbookDetails[workbookID]
    }

    var body: some View {
        if let workbook {
            List {
                Section {
                    Text(workbook.description)
                        .foregroundStyle(.secondary)
                }

                Section("問題一覧") {
                    ForEach(Array(workbook.questions.enumerated()), id: \.element.id) { index, question in
                        HStack {
                            Text("Q\(index + 1)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(Color.accentColor)
                                .clipShape(Circle())
                            Text(question.text)
                                .lineLimit(2)
                        }
                    }
                }

                Section {
                    NavigationLink(destination: QuizView(questions: workbook.questions, workbookTitle: workbook.title)) {
                        Label("この問題集を解く", systemImage: "play.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle(workbook.title)
        } else {
            ContentUnavailableView("問題集が見つかりません", systemImage: "exclamationmark.triangle")
        }
    }
}

#Preview {
    NavigationStack {
        WorkbookDetailView(workbookID: 1)
    }
}
