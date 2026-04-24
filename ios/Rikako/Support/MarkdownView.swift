import SwiftUI

/// シンプルなブロック単位の Markdown レンダラ。
///
/// サポート: `#`/`##`/`###` 見出し、`- ` / `* ` の順序なしリスト、`1. ` の順序ありリスト、
/// 空行区切りの段落、水平線 `---`、インラインは Apple の `AttributedString(markdown:)`
/// に任せる（**太字**、*斜体*、`code`、リンクなど）。
///
/// コードブロック・引用・テーブルなど未サポート要素はプレーンテキストで表示。
struct MarkdownView: View {
    let markdown: String

    var body: some View {
        let blocks = MarkdownParser.parse(markdown)
        return VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                view(for: block)
            }
        }
    }

    @ViewBuilder
    private func view(for block: MarkdownParser.Block) -> some View {
        switch block {
        case .heading(let level, let text):
            Text(attributed(text))
                .font(headingFont(level))
                .padding(.top, 4)
        case .paragraph(let text):
            Text(attributed(text))
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        case .unorderedList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 6) {
                        Text("・")
                        Text(attributed(item))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.body)
                }
            }
        case .orderedList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 6) {
                        Text("\(index + 1).")
                        Text(attributed(item))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.body)
                }
            }
        case .rule:
            Divider()
                .padding(.vertical, 2)
        }
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: return .title2.bold()
        case 2: return .title3.bold()
        default: return .headline
        }
    }

    private func attributed(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text)) ?? AttributedString(text)
    }
}

enum MarkdownParser {
    enum Block {
        case heading(level: Int, text: String)
        case paragraph(String)
        case unorderedList([String])
        case orderedList([String])
        case rule
    }

    static func parse(_ source: String) -> [Block] {
        let lines = source.components(separatedBy: .newlines)
        var blocks: [Block] = []
        var paragraphBuffer: [String] = []
        var ulBuffer: [String] = []
        var olBuffer: [String] = []

        func flushParagraph() {
            guard !paragraphBuffer.isEmpty else { return }
            let text = paragraphBuffer.joined(separator: " ").trimmingCharacters(in: .whitespaces)
            if !text.isEmpty {
                blocks.append(.paragraph(text))
            }
            paragraphBuffer.removeAll()
        }
        func flushUL() {
            guard !ulBuffer.isEmpty else { return }
            blocks.append(.unorderedList(ulBuffer))
            ulBuffer.removeAll()
        }
        func flushOL() {
            guard !olBuffer.isEmpty else { return }
            blocks.append(.orderedList(olBuffer))
            olBuffer.removeAll()
        }
        func flushAll() {
            flushParagraph()
            flushUL()
            flushOL()
        }

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: CharacterSet.whitespaces.subtracting(CharacterSet(charactersIn: "")))

            if line.isEmpty {
                flushAll()
                continue
            }

            if line == "---" || line == "***" {
                flushAll()
                blocks.append(.rule)
                continue
            }

            if let heading = parseHeading(line) {
                flushAll()
                blocks.append(heading)
                continue
            }

            if let item = parseUnorderedItem(line) {
                flushParagraph()
                flushOL()
                ulBuffer.append(item)
                continue
            }

            if let item = parseOrderedItem(line) {
                flushParagraph()
                flushUL()
                olBuffer.append(item)
                continue
            }

            flushUL()
            flushOL()
            paragraphBuffer.append(line)
        }

        flushAll()
        return blocks
    }

    private static func parseHeading(_ line: String) -> Block? {
        var level = 0
        var idx = line.startIndex
        while idx < line.endIndex && line[idx] == "#" && level < 6 {
            level += 1
            idx = line.index(after: idx)
        }
        guard level > 0, idx < line.endIndex, line[idx] == " " else { return nil }
        let text = String(line[line.index(after: idx)...]).trimmingCharacters(in: .whitespaces)
        return .heading(level: level, text: text)
    }

    private static func parseUnorderedItem(_ line: String) -> String? {
        if line.hasPrefix("- ") { return String(line.dropFirst(2)) }
        if line.hasPrefix("* ") { return String(line.dropFirst(2)) }
        return nil
    }

    private static func parseOrderedItem(_ line: String) -> String? {
        // "1. text", "10. text"
        var idx = line.startIndex
        while idx < line.endIndex, line[idx].isNumber {
            idx = line.index(after: idx)
        }
        guard idx != line.startIndex,
              idx < line.endIndex, line[idx] == ".",
              line.index(after: idx) < line.endIndex, line[line.index(after: idx)] == " "
        else { return nil }
        return String(line[line.index(idx, offsetBy: 2)...])
    }
}

#Preview {
    ScrollView {
        MarkdownView(markdown: """
        # 新機能のお知らせ

        本日、**新しい問題集** を追加しました！以下の機能が使えるようになっています。

        - 基礎化学の復習
        - 物質量の計算
        - *酸と塩基* の基礎

        ## 使い方

        1. ホーム画面で問題集を選択
        2. 問題を解く
        3. 結果を確認

        ---

        詳しくは [ヘルプ](https://example.com) をご覧ください。
        """)
        .padding()
    }
}
