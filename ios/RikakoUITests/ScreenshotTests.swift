import XCTest

/// App Store 提出用スクリーンショットを生成する UI テスト。
///
/// `-uitest-screenshots` 起動引数で以下が有効になる（いずれも #if DEBUG 限定）:
/// - AppContainer が PreviewLearningRepository（モック）を注入 → ネットワーク不要・決定的
/// - AppState.hasCompletedOnboarding = true → オンボーディングをスキップして直接メイン画面へ
///
/// モックの問題集詳細は MockData.questions（5問）を返すため、クイズを最後まで解いて結果画面まで撮れる。
final class ScreenshotTests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments += ["-uitest-screenshots"]
        app.launch()
    }

    @MainActor
    func test_AllScreenshots() throws {
        // === 01: 学習ホーム ===
        // 「はじめる」（チャプター開始）ボタンが出れば StudyHome の準備完了
        let startButton = button(containing: "はじめる")
        XCTAssertTrue(startButton.waitForExistence(timeout: 30), "学習ホームの『はじめる』ボタンが見つからない")
        sleep(1) // ヒーロー描画の安定待ち
        takeScreenshot(name: "01_study_home")

        // === 02: 問題集を変更（一覧）===
        let pickerButton = app.buttons["問題集を変更"]
        XCTAssertTrue(pickerButton.waitForExistence(timeout: 10))
        pickerButton.tap()
        XCTAssertTrue(app.navigationBars["問題集を変更"].waitForExistence(timeout: 10))
        sleep(1)
        takeScreenshot(name: "02_workbook_picker")
        app.buttons["閉じる"].tap()

        // === 03: クイズ（解答前）===
        let start2 = button(containing: "はじめる")
        XCTAssertTrue(start2.waitForExistence(timeout: 10))
        start2.tap()

        let firstChoice = app.buttons.matching(identifier: "quizChoice").element(boundBy: 0)
        XCTAssertTrue(firstChoice.waitForExistence(timeout: 15), "クイズの選択肢が表示されない")
        sleep(1)
        takeScreenshot(name: "03_quiz_before_answer")

        // === 04: クイズ（解答後・解説）===
        firstChoice.tap()
        XCTAssertTrue(waitForNextOrResult(timeout: 10), "解答後の『次の問題へ / 結果を見る』が出ない")
        sleep(1)
        takeScreenshot(name: "04_quiz_after_answer")

        // === 05: 結果 ===
        // 残りの問題を解き進めて結果画面へ（問題数に依存しないループ）
        while true {
            let resultBtn = app.buttons["結果を見る"]
            let nextBtn = app.buttons["次の問題へ"]

            if resultBtn.exists && resultBtn.isHittable {
                resultBtn.tap()
                break
            } else if nextBtn.exists && nextBtn.isHittable {
                nextBtn.tap()
                let choice = app.buttons.matching(identifier: "quizChoice").element(boundBy: 0)
                XCTAssertTrue(choice.waitForExistence(timeout: 10))
                choice.tap()
                _ = waitForNextOrResult(timeout: 10)
            } else {
                XCTFail("『次の問題へ / 結果を見る』ボタンが見つからない")
                break
            }
        }

        XCTAssertTrue(app.navigationBars["結果"].waitForExistence(timeout: 15), "結果画面に遷移しない")
        sleep(1)
        takeScreenshot(name: "05_result")
    }

    // MARK: - Helpers

    /// ラベルに指定文字列を含む最初のボタン（複合ラベルのボタン向け）
    private func button(containing text: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    /// 解答後に現れる「次の問題へ」または「結果を見る」ボタンの出現を待つ
    private func waitForNextOrResult(timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if app.buttons["結果を見る"].exists || app.buttons["次の問題へ"].exists {
                return true
            }
            usleep(200_000)
        }
        return false
    }

    private func takeScreenshot(name: String) {
        let screenshot = app.windows.firstMatch.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
