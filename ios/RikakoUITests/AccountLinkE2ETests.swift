import XCTest

/// dev バックエンドに実際につないで、メールログインと学習記録の引き継ぎを確認する E2E。
///
/// **認証情報を環境変数で渡したときだけ実行される**（未設定ならスキップ）。
/// リポジトリに認証情報を持たせないため、また CI（RikakoTests のみ実行）や
/// スクリーンショット生成に紛れ込ませないための措置。
///
/// ```
/// RIKAKO_E2E_EMAIL=... RIKAKO_E2E_PASSWORD=... \
///   xcodebuild test -scheme high-school-chemistry-dev \
///     -only-testing:RikakoUITests/AccountLinkE2ETests
/// ```
final class AccountLinkE2ETests: XCTestCase {

    private var app: XCUIApplication!
    private var email = ""
    private var password = ""

    override func setUpWithError() throws {
        continueAfterFailure = false

        let environment = ProcessInfo.processInfo.environment
        guard let email = environment["RIKAKO_E2E_EMAIL"],
              let password = environment["RIKAKO_E2E_PASSWORD"],
              !email.isEmpty, !password.isEmpty else {
            throw XCTSkip("RIKAKO_E2E_EMAIL / RIKAKO_E2E_PASSWORD が未設定のためスキップ")
        }
        self.email = email
        self.password = password

        app = XCUIApplication()
        // 認証情報はテストプロセスから渡し、アプリ側のコードには一切埋め込まない。
        app.launchEnvironment["RIKAKO_E2E_EMAIL"] = email
        app.launchEnvironment["RIKAKO_E2E_PASSWORD"] = password
    }

    /// 匿名で解く → ログイン → 学習記録が引き継がれる → ログアウト、までを通しで確認する。
    @MainActor
    func test_匿名で解いてからログインすると学習記録が引き継がれる() throws {
        app.launch()

        completeOnboardingIfNeeded()

        // === 0. 前回の実行でログインが残っていたらログアウトして匿名に戻す ===
        // Keychain にトークンが残るので、この前提づくりは毎回必要。
        openSettings()
        signOutIfNeeded()
        closeSettings()

        // === 1. 匿名のまま1問解く ===
        let answered = answerOneQuestion()
        XCTAssertTrue(answered, "匿名の状態で問題を解けない")
        takeScreenshot(name: "01_匿名で解答")

        // === 2. 設定を開き、未ログインの導線が出ていること ===
        openSettings()
        let loginRow = app.buttons["loginButton"]
        XCTAssertTrue(loginRow.waitForExistence(timeout: 10), "未ログイン時のログイン導線が出ていない")
        takeScreenshot(name: "02_設定_未ログイン")

        // === 3. ログイン（完了まで待つ = /account/link の完了待ち）===
        loginRow.tap()
        signIn()

        // ログイン画面が閉じて設定に戻り、メールアドレスが出ていれば
        // link まで完了している（onLoggedIn が link を待ってから閉じるため）。
        let emailText = app.staticTexts[email]
        XCTAssertTrue(emailText.waitForExistence(timeout: 60), "ログイン後にメールアドレスが表示されない")
        takeScreenshot(name: "03_設定_ログイン後")

        // === 4. リンク未完了の警告が出ていないこと ===
        XCTAssertFalse(
            app.staticTexts["学習記録の引き継ぎが未完了です"].exists,
            "/account/link が失敗している"
        )

        // === 5. 学習記録が引き継がれていること ===
        closeSettings()
        XCTAssertTrue(openStudyRecord(), "ログイン後に学習記録が読み込めない")
        takeScreenshot(name: "04_学習記録_ログイン後")
    }

    /// アプリを消して入れ直しても、ログインし直せば学習記録が戻ることを確認する。
    @MainActor
    func test_再インストール後もログインすれば学習記録が戻る() throws {
        // 事前にアプリをアンインストールしておくこと（UserDefaults を空にするため）。
        //   xcrun simctl uninstall <device> org.rikako.chemist.dev
        app.launch()

        completeOnboardingIfNeeded()
        openSettings()

        let loginRow = app.buttons["loginButton"]
        if loginRow.waitForExistence(timeout: 10) {
            loginRow.tap()
            signIn()
        }

        XCTAssertTrue(
            app.staticTexts[email].waitForExistence(timeout: 60),
            "再インストール後にログインできない"
        )
        takeScreenshot(name: "05_再インストール後_ログイン")

        closeSettings()
        XCTAssertTrue(openStudyRecord(), "再インストール後に学習記録が復元されない")
        takeScreenshot(name: "06_再インストール後_学習記録")
    }

    // MARK: - 部品

    private func signIn() {
        let emailField = app.textFields["メールアドレス"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 10), "メールアドレス欄が出ない")
        emailField.tap()
        emailField.typeText(email)

        let passwordField = app.secureTextFields["パスワード"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 5), "パスワード欄が出ない")
        passwordField.tap()
        passwordField.typeText(password)

        app.buttons["ログイン"].firstMatch.tap()
    }

    /// ログイン中ならログアウトする（未ログインなら何もしない）。
    private func signOutIfNeeded() {
        let signOutRow = app.buttons["signOutButton"]
        guard signOutRow.waitForExistence(timeout: 5) else { return }

        signOutRow.tap()
        let confirm = app.alerts.buttons["ログアウト"]
        if confirm.waitForExistence(timeout: 5) {
            confirm.tap()
        }
        XCTAssertTrue(
            app.buttons["loginButton"].waitForExistence(timeout: 20),
            "ログアウトできない"
        )
    }

    private func closeSettings() {
        let back = app.buttons["BackButton"].exists
            ? app.buttons["BackButton"]
            : app.navigationBars.buttons.firstMatch
        if back.exists && back.isHittable {
            back.tap()
        }
        XCTAssertTrue(app.tabBars.buttons["学習"].waitForExistence(timeout: 20), "設定を閉じられない")
        // 設定はマイページ配下なので、学習タブへ戻しておく。
        app.tabBars.buttons["学習"].tap()
    }

    /// 学習記録タブを開き、本体（スケルトンではない）が出るまで待つ。
    /// ログイン直後はアカウント側のデータを取り直すため時間がかかることがある。
    @discardableResult
    private func openStudyRecord(timeout: TimeInterval = 90) -> Bool {
        app.tabBars.buttons["学習記録"].tap()

        let marker = app.staticTexts["連続学習日数"]
        if marker.waitForExistence(timeout: timeout / 2) { return true }

        // 取りこぼした場合に備えてもう一度タブを叩く
        app.tabBars.buttons["学習記録"].tap()
        return marker.waitForExistence(timeout: timeout / 2)
    }

    private func openSettings() {
        XCTAssertTrue(
            app.tabBars.buttons["マイページ"].waitForExistence(timeout: 60),
            "メイン画面に到達できない（オンボーディングが完了していない）"
        )
        app.tabBars.buttons["マイページ"].tap()
        let settings = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "設定")).firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 15), "マイページから設定へ入れない")
        settings.tap()
    }

    /// オンボーディングが出た場合は最後まで進める（出なければ何もしない）。
    /// 実際の遷移は「次へ」→「問題集を選ぶ」→ 問題集を1つ選ぶ、の順。
    private func completeOnboardingIfNeeded() {
        // 実際の遷移: 次へ → 問題集を選ぶ → 問題集を1つ選ぶ → 同意して次へ → はじめる。
        // （タブバーが出た時点で抜けるので、学習ホームの「はじめる」は押さない）
        let labels = ["次へ", "問題集を選ぶ", "この問題集で始める", "はじめる"]
        // 新規インストール直後は問題集の取得などで時間がかかるため長めに待つ。
        let deadline = Date().addingTimeInterval(240)

        while Date() < deadline {
            if app.tabBars.buttons["マイページ"].exists { return }

            // 利用規約の同意チェックを入れないと「同意して次へ」が有効にならない。
            // ラベル付きの switch はタップに反応しない（実体は無ラベル側）ため、
            // ボタンが有効になるまで順にタップして確かめる。
            let agreeButton = app.buttons["同意して次へ"]
            if agreeButton.exists && !agreeButton.isEnabled {
                for index in 0..<app.switches.count {
                    app.switches.element(boundBy: index).tap()
                    usleep(300_000)
                    if agreeButton.isEnabled { break }
                }
            }

            // 「同意して次へ」は "次へ" に含まれるので labels でまとめて拾える。
            let candidate = app.buttons.matching(
                NSPredicate(format: "label CONTAINS %@ OR label CONTAINS %@ OR label CONTAINS %@ OR label CONTAINS %@",
                            labels[0], labels[1], labels[2], labels[3])
            ).firstMatch

            if candidate.exists && candidate.isHittable && candidate.isEnabled {
                candidate.tap()
            }
            usleep(500_000)
        }
    }

    /// 1問だけ解く。解けたら true。
    private func answerOneQuestion() -> Bool {
        let start = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "はじめる")).firstMatch
        guard start.waitForExistence(timeout: 30) else { return false }
        start.tap()

        let choice = app.buttons.matching(identifier: "quizChoice").element(boundBy: 0)
        guard choice.waitForExistence(timeout: 20) else { return false }
        choice.tap()

        // 解答が記録されるまで待つ
        var answered = false
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            if app.buttons["結果を見る"].exists || app.buttons["次の問題へ"].exists {
                answered = true
                break
            }
            usleep(200_000)
        }
        guard answered else { return false }

        // クイズ画面はタブバーを覆うので、閉じてメインへ戻す。
        leaveQuiz()
        return app.tabBars.buttons["マイページ"].waitForExistence(timeout: 15)
    }

    private func leaveQuiz() {
        let back = app.buttons["戻る"]
        if back.exists && back.isHittable {
            back.tap()
        }
        // 「クイズを終了しますか？」が出る。解答を残したいので必ず保存側を選ぶ
        // （ここで捨てるとマージ対象の学習記録が作られない）。
        let save = app.alerts.buttons["履歴を保存して戻る"]
        if save.waitForExistence(timeout: 5) {
            save.tap()
        }
    }

    private func takeScreenshot(name: String) {
        let attachment = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
