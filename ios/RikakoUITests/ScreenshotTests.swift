import XCTest

final class ScreenshotTests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    @MainActor
    func test_AllScreenshots() throws {
        // === オンボーディング通過 ===
        let nextButton = app.buttons["次へ"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 15))
        nextButton.tap()
        sleep(2)

        for _ in 0..<3 {
            let next = app.buttons["次へ"]
            XCTAssertTrue(next.waitForExistence(timeout: 15))
            next.tap()
            sleep(2)
        }

        let categoryButton = app.buttons.matching(NSPredicate(format: "label CONTAINS '中学理科'")).firstMatch
        XCTAssertTrue(categoryButton.waitForExistence(timeout: 15))
        categoryButton.tap()
        sleep(1)

        let beginButton = app.buttons["はじめる"]
        XCTAssertTrue(beginButton.waitForExistence(timeout: 15))
        beginButton.tap()
        sleep(2)

        // === ログイン画面 → スキップ ===
        let skipLogin = app.buttons["ログインせずに使う"]
        XCTAssertTrue(skipLogin.waitForExistence(timeout: 15))
        skipLogin.tap()
        sleep(2)

        // === 01: 問題集一覧 ===
        XCTAssertTrue(app.navigationBars["問題集"].waitForExistence(timeout: 15))
        takeScreenshot(name: "01_workbook_list")

        // === 02: 問題集詳細 ===
        let firstCell = app.cells.firstMatch
        XCTAssertTrue(firstCell.waitForExistence(timeout: 10))
        firstCell.tap()

        let startQuizButton = app.buttons["この問題集を解く"]
        XCTAssertTrue(startQuizButton.waitForExistence(timeout: 15))
        takeScreenshot(name: "02_workbook_detail")

        // === 03: クイズ（解答前） ===
        startQuizButton.tap()
        XCTAssertTrue(app.navigationBars["Q1 / 5"].waitForExistence(timeout: 15))
        takeScreenshot(name: "03_quiz_before_answer")

        // === 04: クイズ（解答後） ===
        let firstChoice = app.scrollViews.buttons.element(boundBy: 0)
        XCTAssertTrue(firstChoice.waitForExistence(timeout: 10))
        firstChoice.tap()
        sleep(1)
        takeScreenshot(name: "04_quiz_after_answer")

        // === 05: 結果画面 ===
        // 残り4問を解答
        let nextQuestionButton = app.scrollViews.buttons["次の問題へ"]
        XCTAssertTrue(nextQuestionButton.waitForExistence(timeout: 5))
        nextQuestionButton.tap()
        sleep(1)

        for i in 2...5 {
            XCTAssertTrue(app.navigationBars["Q\(i) / 5"].waitForExistence(timeout: 10))

            let choice = app.scrollViews.buttons.element(boundBy: 0)
            XCTAssertTrue(choice.waitForExistence(timeout: 10))
            choice.tap()
            sleep(1)

            if i < 5 {
                let nextBtn = app.scrollViews.buttons["次の問題へ"]
                XCTAssertTrue(nextBtn.waitForExistence(timeout: 5))
                nextBtn.tap()
                sleep(1)
            } else {
                let resultBtn = app.scrollViews.buttons["結果を見る"]
                XCTAssertTrue(resultBtn.waitForExistence(timeout: 5))
                resultBtn.tap()
                sleep(1)
            }
        }

        XCTAssertTrue(app.navigationBars["結果"].waitForExistence(timeout: 15))
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
