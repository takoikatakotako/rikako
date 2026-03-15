import XCTest

final class ScreenshotTests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
        passOnboardingAndLogin()
    }

    /// オンボーディング（カテゴリ選択含む）とログインを通過して問題集一覧に到達する
    private func passOnboardingAndLogin() {
        // ウェルカム画面 → 「次へ」
        let nextButton = app.buttons["次へ"]
        if nextButton.waitForExistence(timeout: 5) {
            nextButton.tap()

            // 紹介ページ 1/3 → 2/3 → 3/3
            for _ in 0..<3 {
                let next = app.buttons["次へ"]
                XCTAssertTrue(next.waitForExistence(timeout: 5))
                next.tap()
            }

            // カテゴリ選択 → 最初のカテゴリを選択 → 「はじめる」
            let categoryButton = app.buttons.matching(NSPredicate(format: "label CONTAINS '中学理科'")).firstMatch
            XCTAssertTrue(categoryButton.waitForExistence(timeout: 5))
            categoryButton.tap()

            let startButton = app.buttons["はじめる"]
            XCTAssertTrue(startButton.waitForExistence(timeout: 5))
            startButton.tap()
        }

        // ログイン画面 → 「ログインせずに使う」
        let skipLogin = app.buttons["ログインせずに使う"]
        if skipLogin.waitForExistence(timeout: 5) {
            skipLogin.tap()
        }

        // 問題集一覧に到達するまで待つ
        XCTAssertTrue(app.navigationBars["問題集"].waitForExistence(timeout: 10))
    }

    @MainActor
    func test01_WorkbookList() throws {
        takeScreenshot(name: "01_workbook_list")
    }

    @MainActor
    func test02_WorkbookDetail() throws {
        let firstCell = app.cells.firstMatch
        XCTAssertTrue(firstCell.waitForExistence(timeout: 10))
        firstCell.tap()

        // 問題集詳細画面に遷移したことを「この問題集を解く」ボタンで確認
        let startButton = app.buttons["この問題集を解く"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10))
        takeScreenshot(name: "02_workbook_detail")
    }

    @MainActor
    func test03_QuizBeforeAnswer() throws {
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
        let firstCell = app.cells.firstMatch
        XCTAssertTrue(firstCell.waitForExistence(timeout: 10))
        firstCell.tap()

        let startButton = app.buttons["この問題集を解く"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10))
        startButton.tap()

        XCTAssertTrue(app.navigationBars["Q1 / 5"].waitForExistence(timeout: 10))

        let firstChoice = app.buttons.matching(identifier: "H2O").firstMatch
        if firstChoice.waitForExistence(timeout: 3) {
            firstChoice.tap()
        } else {
            app.buttons.element(boundBy: 0).tap()
        }

        sleep(1)
        takeScreenshot(name: "04_quiz_after_answer")
    }

    @MainActor
    func test05_Result() throws {
        let firstCell = app.cells.firstMatch
        XCTAssertTrue(firstCell.waitForExistence(timeout: 10))
        firstCell.tap()

        let startButton = app.buttons["この問題集を解く"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10))
        startButton.tap()

        for i in 1...5 {
            XCTAssertTrue(app.navigationBars["Q\(i) / 5"].waitForExistence(timeout: 10))

            let buttons = app.scrollViews.buttons
            if buttons.count > 0 {
                buttons.element(boundBy: 0).tap()
            }

            sleep(1)

            if i < 5 {
                let nextButton = app.scrollViews.buttons["次の問題へ"]
                XCTAssertTrue(nextButton.waitForExistence(timeout: 3))
                nextButton.tap()
            } else {
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
