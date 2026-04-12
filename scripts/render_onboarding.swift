#!/usr/bin/env swift

import AppKit
import Foundation
import SwiftUI

let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let outputDirectory = repoRoot.appendingPathComponent("docs/ios/images/onboarding", isDirectory: true)

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let pageSize = CGSize(width: 393, height: 852)
let renderScale: CGFloat = 2

struct SampleWorkbook: Identifiable {
    let id: Int
    let title: String
    let description: String
    let questionCount: Int
}

let workbooks = [
    SampleWorkbook(id: 1, title: "基礎化学のはじめの一歩", description: "まずは化学の基本用語と考え方に慣れるための問題集です。", questionCount: 12),
    SampleWorkbook(id: 2, title: "化学結合の基礎", description: "イオン結合や共有結合など、化学結合の基本を確認する問題集です。", questionCount: 18),
    SampleWorkbook(id: 3, title: "酸と塩基の入門", description: "pH、電離、酸と塩基の考え方をやさしく学ぶ問題集です。", questionCount: 15),
    SampleWorkbook(id: 4, title: "物質量とモル計算", description: "mol の考え方と計算に慣れるための問題集です。", questionCount: 20)
]

enum SnapshotColor {
    static let main = Color(red: 0.96, green: 0.42, blue: 0.14)
    static let pink = Color(red: 1.0, green: 0.91, blue: 0.92)
    static let blue = Color(red: 0.90, green: 0.95, blue: 1.0)
    static let background = Color(nsColor: .windowBackgroundColor)
    static let card = Color(nsColor: .controlBackgroundColor)
    static let muted = Color.secondary
}

func loadImage(_ relativePath: String) -> NSImage? {
    NSImage(contentsOf: repoRoot.appendingPathComponent(relativePath))
}

let characterImage = loadImage("ios/Rikako/Assets.xcassets/images/Top/top-rikako-standing.imageset/rikako-standing@2x.png")

struct SnapshotContainer<Artwork: View>: View {
    let title: String
    let lines: [String]
    let buttonTitle: String
    let artwork: Artwork

    init(title: String, lines: [String], buttonTitle: String, @ViewBuilder artwork: () -> Artwork) {
        self.title = title
        self.lines = lines
        self.buttonTitle = buttonTitle
        self.artwork = artwork()
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 24)

            artwork

            VStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 30, weight: .bold))
                    .multilineTextAlignment(.center)

                VStack(spacing: 8) {
                    ForEach(lines, id: \.self) { line in
                        Text(line)
                            .font(.body)
                            .foregroundStyle(SnapshotColor.muted)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            Text(buttonTitle)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(SnapshotColor.main)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
        }
        .frame(width: pageSize.width, height: pageSize.height)
        .background(SnapshotColor.background)
    }
}

struct CharacterArtwork: View {
    var body: some View {
        Group {
            if let characterImage {
                Image(nsImage: characterImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 260)
            } else {
                Image(systemName: "tortoise.fill")
                    .font(.system(size: 160))
                    .foregroundStyle(SnapshotColor.main)
            }
        }
        .padding(.horizontal, 24)
    }
}

struct WorkbookCard: View {
    let workbook: SampleWorkbook
    let primary: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(workbook.title)
                .font(primary ? .title3.bold() : .headline)

            Text(workbook.description)
                .foregroundStyle(SnapshotColor.muted)
                .lineLimit(primary ? nil : 2)

            HStack {
                Text("\(workbook.questionCount)問")
                    .font(.caption.bold())
                    .foregroundStyle(SnapshotColor.muted)

                Spacer()

                Text("この問題集で始める")
                    .font(.subheadline.bold())
                    .foregroundStyle(SnapshotColor.main)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(SnapshotColor.main.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SnapshotColor.card)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(SnapshotColor.main.opacity(primary ? 0.2 : 0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}

struct WorkbookSelectionSnapshot: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                Spacer(minLength: 24)

                VStack(spacing: 10) {
                    Text("最初の問題集を選ぼう")
                        .font(.system(size: 28, weight: .bold))
                        .multilineTextAlignment(.center)

                    Text("おすすめの1冊を用意したよ。まずはここから始めてみよう！")
                        .foregroundStyle(SnapshotColor.muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("おすすめ")
                            .font(.headline)
                            .foregroundStyle(SnapshotColor.main)

                        WorkbookCard(workbook: workbooks[0], primary: true)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        Text("その他")
                            .font(.headline)
                            .foregroundStyle(SnapshotColor.muted)

                        VStack(spacing: 12) {
                            ForEach(Array(workbooks.dropFirst())) { workbook in
                                WorkbookCard(workbook: workbook, primary: false)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 40)
        }
        .frame(width: pageSize.width, height: pageSize.height)
        .background(SnapshotColor.background)
    }
}

struct TermsSnapshot: View {
    @State private var hasAgreedToTerms = true

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 24)

            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(SnapshotColor.main.opacity(0.10))
                    .frame(width: 112, height: 112)
                Image(systemName: "checkmark.seal.text.page")
                    .font(.system(size: 40))
                    .foregroundStyle(SnapshotColor.main)
            }

            VStack(spacing: 12) {
                Text("利用規約に同意して始めよう")
                    .font(.system(size: 30, weight: .bold))
                    .multilineTextAlignment(.center)

                VStack(spacing: 8) {
                    Text("アプリを使い始める前に、利用規約への同意をお願いしています。")
                    Text("内容を確認したうえで、同意して次へ進んでください。")
                }
                .font(.body)
                .foregroundStyle(SnapshotColor.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            }

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("以下の内容を確認できます。")
                        .font(.footnote)
                        .foregroundStyle(SnapshotColor.muted)

                    Text("利用規約を確認する")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.blue)

                    Text("プライバシーポリシーを確認する")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.blue)
                }

                Toggle(isOn: $hasAgreedToTerms) {
                    Text("利用規約に同意します")
                        .font(.headline)
                }
                .toggleStyle(.switch)

                Text("リンク先を確認したうえで、同意して次へ進んでください。")
                    .font(.footnote)
                    .foregroundStyle(SnapshotColor.muted)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
            .background(SnapshotColor.card)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 24)

            Spacer()
        }
        .safeAreaInset(edge: .bottom) {
            Text("同意して次へ")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(SnapshotColor.main)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 56)
                .background(SnapshotColor.background)
        }
        .frame(width: pageSize.width, height: pageSize.height)
        .background(SnapshotColor.background)
    }
}

let pages: [(String, AnyView)] = [
    (
        "01-welcome",
        AnyView(
            SnapshotContainer(
                title: "こんにちは、理科子です！",
                lines: [
                    "このアプリは高校生向けの化学を楽しく学ぶためのアプリです！",
                    "一緒に楽しく勉強していこうね！"
                ],
                buttonTitle: "次へ",
                artwork: { CharacterArtwork() }
            )
        )
    ),
    (
        "02-workbook-intro",
        AnyView(
            SnapshotContainer(
                title: "君にあった分野を選ぼう！",
                lines: [
                    "高校化学とはいっても、範囲や分野はいろいろあります。",
                    "次のページで問題集を選択できるから、学びたい問題集を選んでみてね。",
                    "特になければ、おすすめの基礎の問題集を選んでみよう！"
                ],
                buttonTitle: "問題集を選ぶ",
                artwork: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(SnapshotColor.pink)
                            .frame(width: 220, height: 220)
                        Image(systemName: "books.vertical.fill")
                            .font(.system(size: 84))
                            .foregroundStyle(SnapshotColor.main)
                    }
                }
            )
        )
    ),
    ("03-workbook-selection", AnyView(WorkbookSelectionSnapshot())),
    (
        "04-app-intro",
        AnyView(
            SnapshotContainer(
                title: "選びおわったね！",
                lines: [
                    "他の機能は使いながら覚えていこうね！",
                    "このアプリはログインしなくても使えるけど、ログインすると他の端末でも学習記録を共有できるよ。",
                    "よかったらログインして使ってみてね！"
                ],
                buttonTitle: "次へ",
                artwork: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(SnapshotColor.blue)
                            .frame(width: 220, height: 220)
                        Image(systemName: "ipad.and.iphone")
                            .font(.system(size: 80))
                            .foregroundStyle(Color.blue)
                    }
                }
            )
        )
    ),
    ("05-terms", AnyView(TermsSnapshot())),
    (
        "06-finish",
        AnyView(
            SnapshotContainer(
                title: "それではさっそく勉強していこう！",
                lines: ["一緒に頑張ろうね！"],
                buttonTitle: "はじめる",
                artwork: { CharacterArtwork() }
            )
        )
    )
]

@MainActor
func writePNG(view: some View, to url: URL) throws {
    let renderer = ImageRenderer(content: view.environment(\.colorScheme, .light))
    renderer.scale = renderScale

    guard let nsImage = renderer.nsImage,
          let tiffData = nsImage.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "render_onboarding", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to render image"])
    }

    try pngData.write(to: url)
}

Task { @MainActor in
    do {
        for (name, view) in pages {
            let url = outputDirectory.appendingPathComponent("\(name).png")
            try writePNG(view: view.frame(width: pageSize.width, height: pageSize.height), to: url)
            print("Wrote \(url.path)")
        }
        exit(EXIT_SUCCESS)
    } catch {
        fputs("render failed: \(error)\n", stderr)
        exit(EXIT_FAILURE)
    }
}

RunLoop.main.run()
