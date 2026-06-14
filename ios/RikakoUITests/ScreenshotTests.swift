import XCTest

final class ScreenshotTests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = true
        app.launch()
    }

    @MainActor
    func test_AllScreenshots() throws {
        // === オンボーディング（現行6ページ構成） ===
        // 0: Welcome
        tapButtonIfExists("次へ", timeout: 25)
        // 1: WorkbookIntro
        tapButtonIfExists("問題集を選ぶ", timeout: 15)
        // 2: WorkbookSelection（API読み込み後、おすすめ問題集をタップ）
        let recommended = app.scrollViews.buttons.firstMatch
        if recommended.waitForExistence(timeout: 30) { recommended.tap() }
        sleep(1)
        // 3: AppIntro
        tapButtonIfExists("次へ", timeout: 15)
        // 4: TermsAgreement（同意スイッチON → 同意して次へ）
        // Toggle はラベルとノブが入れ子。中心はラベル上なので右端(ノブ)を座標タップする。
        let agreeToggle = app.switches["利用規約に同意します"]
        if agreeToggle.waitForExistence(timeout: 15), (agreeToggle.value as? String) != "1" {
            agreeToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
            sleep(1)
        }
        tapButtonIfExists("同意して次へ", timeout: 10)
        // 5: Finish（はじめる → 匿名サインイン）
        tapButtonIfExists("はじめる", timeout: 15)
        sleep(5)

        // === 01: ホーム（学習：選択した問題集のチャプター一覧） ===
        _ = app.navigationBars["学習"].waitForExistence(timeout: 30)
        sleep(2)
        takeScreenshot(name: "01_home")

        // === 02: 学習記録タブ ===
        let recordTab = app.tabBars.buttons["学習記録"]
        if recordTab.waitForExistence(timeout: 10) {
            recordTab.tap()
            sleep(2)
            takeScreenshot(name: "02_study_record")
            app.tabBars.buttons["学習"].tap()
            sleep(1)
        }

        // === 03: クイズ（解答前） ===
        let startButton = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'はじめる'")).firstMatch
        if startButton.waitForExistence(timeout: 15) { startButton.tap() }
        sleep(2)
        takeScreenshot(name: "03_quiz_before_answer")

        // === 04: クイズ（解答後／解説＋AIに質問） ===
        let firstChoice = app.scrollViews.buttons.element(boundBy: 0)
        if firstChoice.waitForExistence(timeout: 10) { firstChoice.tap() }
        sleep(1)
        takeScreenshot(name: "04_quiz_explanation")

        // === 残りを解いて結果画面へ ===
        for _ in 0..<25 {
            if app.scrollViews.buttons["結果を見る"].exists {
                app.scrollViews.buttons["結果を見る"].tap()
                break
            } else if app.scrollViews.buttons["次の問題へ"].exists {
                app.scrollViews.buttons["次の問題へ"].tap()
                sleep(1)
                let choice = app.scrollViews.buttons.element(boundBy: 0)
                if choice.waitForExistence(timeout: 5) { choice.tap() }
                sleep(1)
            } else {
                sleep(1)
            }
        }
        sleep(2)

        // === 05: 結果画面 ===
        _ = app.navigationBars["結果"].waitForExistence(timeout: 20)
        takeScreenshot(name: "05_result")
    }

    private func tapButtonIfExists(_ label: String, timeout: TimeInterval) {
        let button = app.buttons[label]
        if button.waitForExistence(timeout: timeout) {
            button.tap()
            sleep(1)
        }
    }

    private func takeScreenshot(name: String) {
        let screenshot = app.windows.firstMatch.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
