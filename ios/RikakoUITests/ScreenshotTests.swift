import XCTest

final class ScreenshotTests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    @MainActor
    func test01_WorkbookList() throws {
        // 問題集一覧画面
        XCTAssertTrue(app.navigationBars["問題集"].waitForExistence(timeout: 10))
        takeScreenshot(name: "01_workbook_list")
    }

    @MainActor
    func test02_WorkbookDetail() throws {
        // 問題集一覧 → 詳細画面
        let firstCell = app.cells.firstMatch
        XCTAssertTrue(firstCell.waitForExistence(timeout: 10))
        firstCell.tap()

        XCTAssertTrue(app.navigationBars["基礎化学"].waitForExistence(timeout: 10))
        takeScreenshot(name: "02_workbook_detail")
    }

    @MainActor
    func test03_QuizBeforeAnswer() throws {
        // 問題集一覧 → 詳細 → クイズ（解答前）
        let firstCell = app.cells.firstMatch
        XCTAssertTrue(firstCell.waitForExistence(timeout: 10))
        firstCell.tap()

        let startButton = app.buttons["この問題集を解く"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10))
        startButton.tap()

        XCTAssertTrue(app.navigationBars["Q1 / 5"].waitForExistence(timeout: 10))
        takeScreenshot(name: "03_quiz_before_answer")
    }

    @MainActor
    func test04_QuizAfterAnswer() throws {
        // 問題集一覧 → 詳細 → クイズ → 解答後
        let firstCell = app.cells.firstMatch
        XCTAssertTrue(firstCell.waitForExistence(timeout: 10))
        firstCell.tap()

        let startButton = app.buttons["この問題集を解く"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10))
        startButton.tap()

        XCTAssertTrue(app.navigationBars["Q1 / 5"].waitForExistence(timeout: 10))

        // 最初の選択肢をタップ（正解）
        let firstChoice = app.buttons.matching(identifier: "H2O").firstMatch
        if firstChoice.waitForExistence(timeout: 3) {
            firstChoice.tap()
        } else {
            // fallback: 最初のボタンをタップ
            app.buttons.element(boundBy: 0).tap()
        }

        // 解説が表示されるまで待つ
        sleep(1)
        takeScreenshot(name: "04_quiz_after_answer")
    }

    @MainActor
    func test05_Result() throws {
        // 全問解答して結果画面へ
        let firstCell = app.cells.firstMatch
        XCTAssertTrue(firstCell.waitForExistence(timeout: 10))
        firstCell.tap()

        let startButton = app.buttons["この問題集を解く"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10))
        startButton.tap()

        // 5問分の解答をループ
        for i in 1...5 {
            XCTAssertTrue(app.navigationBars["Q\(i) / 5"].waitForExistence(timeout: 10))

            // ScrollViewの中のボタンをタップ（最初の選択肢）
            let buttons = app.scrollViews.buttons
            if buttons.count > 0 {
                buttons.element(boundBy: 0).tap()
            }

            sleep(1)

            if i < 5 {
                // 「次の問題へ」ボタンをタップ
                let nextButton = app.scrollViews.buttons["次の問題へ"]
                XCTAssertTrue(nextButton.waitForExistence(timeout: 3))
                nextButton.tap()
            } else {
                // 「結果を見る」ボタンをタップ
                let resultButton = app.scrollViews.buttons["結果を見る"]
                XCTAssertTrue(resultButton.waitForExistence(timeout: 3))
                resultButton.tap()
            }

            sleep(1)
        }

        XCTAssertTrue(app.navigationBars["結果"].waitForExistence(timeout: 10))
        takeScreenshot(name: "05_result")
    }

    private func takeScreenshot(name: String) {
        let screenshot = app.windows.firstMatch.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
