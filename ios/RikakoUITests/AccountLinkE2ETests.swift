import XCTest

/// dev バックエンドに実際につないで、メールログインと学習記録の引き継ぎを検証する E2E。
///
/// **認証情報を環境変数で渡したときだけ実行される**（未設定ならスキップ）。
/// 認証情報はこのテストプロセス内で入力に使うだけで、アプリ側へは渡さない。
///
/// 実行は `ios/scripts/run-account-e2e.sh` を使うこと。アンインストールを含む
/// 前提づくりをスクリプト側で行う。**`CODE_SIGNING_ALLOWED=NO` を付けてはいけない**
/// （署名なしビルドは Keychain が使えず、トークンが保存されない）。
/// E2E の途中で前提が崩れたことを表すエラー。
/// 環境変数が無い場合の XCTSkip と違い、これは**アプリ側の回帰の可能性がある**ので
/// 必ず失敗として扱う。
enum E2EError: LocalizedError {
    case elementNotFound(String)
    case unreadableValue(String)

    var errorDescription: String? {
        switch self {
        case .elementNotFound(let what):
            return "画面に要素が見つからない: \(what)"
        case .unreadableValue(let label):
            return "件数を読み取れない: '\(label)'"
        }
    }
}

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
    }

    override func tearDownWithError() throws {
        // CI でしか再現しない事象を追えるように、失敗時の画面を残す。
        if let app, testRun?.hasSucceeded == false {
            let attachment = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
            attachment.name = "失敗時の画面"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    /// 匿名で解いた回答が、ログイン時にアカウントへマージされることを件数で検証する。
    ///
    /// 1. ログインしてアカウントの回答数を数える（基準値）
    /// 2. ログアウトし、**新しい匿名 identity** で起動し直す（未リンクの端末を作る）
    /// 3. 匿名のまま1問解き、匿名側の回答数が 1 になることを確認
    /// 4. ログインすると、アカウントの回答数が **基準値 + 1** になることを確認
    @MainActor
    func test_匿名で解いた回答がログイン時にアカウントへマージされる() throws {
        // === 1. アカウント側の基準値を読む ===
        // Keychain はアンインストールしても残るため、前回のセッションを必ず消してから始める。
        launchFresh(resetIdentity: true)
        openSettings()
        signInIfNeeded()
        closeSettings()
        let accountBefore = try readWeeklyAnswered()

        // === 2. ログアウトして、未リンクの新しい匿名 identity で起動し直す ===
        openSettings()
        signOut()
        closeSettings()

        launchFresh(resetIdentity: true)
        let anonymousBefore = try readWeeklyAnswered()
        XCTAssertEqual(anonymousBefore, 0, "リセット直後の匿名ユーザーに回答が残っている")

        // === 3. 匿名のまま1問解く ===
        XCTAssertTrue(answerOneQuestion(), "匿名の状態で問題を解けない")
        let anonymousAfter = try readWeeklyAnswered()
        XCTAssertEqual(anonymousAfter, 1, "匿名の回答が記録されていない")

        // === 4. ログインするとアカウント側にマージされる ===
        openSettings()
        signInIfNeeded()
        XCTAssertFalse(
            app.staticTexts["学習記録の引き継ぎが未完了です"].exists,
            "/account/link が失敗している"
        )
        closeSettings()

        let accountAfter = try readWeeklyAnswered()
        XCTAssertEqual(
            accountAfter,
            accountBefore + 1,
            "匿名の回答がアカウントへマージされていない（基準 \(accountBefore) → \(accountAfter)）"
        )
    }

    /// 端末を作り直しても、ログインすればアカウントの学習記録が戻ることを検証する。
    ///
    /// スクリプトが事前にアプリをアンインストールしている前提。加えて
    /// `-uitest-reset-identity` で Keychain も消し、完全に新しい端末として起動する。
    ///
    /// **アカウントに回答が1件以上あることが前提**。`run-account-e2e.sh` は
    /// マージのテストを先に流すので、その回答が残っている状態でここに来る。
    @MainActor
    func test_新しい端末でもログインすれば学習記録が戻る() throws {
        launchFresh(resetIdentity: true)

        // ログイン前は新しい匿名ユーザーなので 0 件。
        XCTAssertEqual(try readWeeklyAnswered(), 0, "新しい端末に回答が残っている")

        openSettings()
        signInIfNeeded()
        closeSettings()

        // ログイン後はアカウントの記録が見えるので 0 件ではなくなる。
        let restored = try readWeeklyAnswered()
        XCTAssertGreaterThan(restored, 0, "ログインしてもアカウントの学習記録が復元されない")
    }

    /// `/account/link` が通信エラーで失敗しても、起動時の自動再試行で回復することを検証する。
    ///
    /// オフラインをシミュレータで再現する手段が無いため、DEBUG 限定の
    /// `-uitest-fail-account-link` で link を `URLError(.notConnectedToInternet)` に
    /// 差し替えて、実際に「ログインはできたがリンクだけ失敗した」状態を作る。
    @MainActor
    func test_リンクに失敗しても次の起動で自動的にやり直される() throws {
        // === 0. アカウント側の基準値を読む ===
        // 「未完了表示が消える」だけだと link の成功しか見ておらず、取り残された
        // 匿名回答が回収されたかは分からないため、件数でも確かめる。
        launchFresh(resetIdentity: true)
        openSettings()
        signInIfNeeded()
        closeSettings()
        let accountBefore = try readWeeklyAnswered()

        openSettings()
        signOut()
        closeSettings()

        // === 1. 新しい匿名 identity で1問解く ===
        launchFresh(resetIdentity: true)
        XCTAssertEqual(try readWeeklyAnswered(), 0, "リセット直後の匿名ユーザーに回答が残っている")
        XCTAssertTrue(answerOneQuestion(), "匿名の状態で問題を解けない")

        // === 2. link が失敗する状態でログインする ===
        launchFresh(failAccountLink: true)
        openSettings()
        signInIfNeeded()

        // ログインは成立するが、リンクは未完了として案内が出る。
        XCTAssertTrue(
            app.staticTexts["学習記録の引き継ぎが未完了です"].waitForExistence(timeout: 30),
            "リンクが失敗したのに未完了の案内が出ない"
        )

        // === 3. 失敗したままでも手動の再試行導線がある ===
        let retry = app.buttons["retryAccountLinkButton"]
        XCTAssertTrue(retry.waitForExistence(timeout: 10), "再試行の導線が出ていない")
        XCTAssertTrue(tapWhenHittable(retry), "再試行の導線をタップできない")
        // まだ失敗する状態なので、案内は消えない。
        XCTAssertTrue(
            app.staticTexts["学習記録の引き継ぎが未完了です"].waitForExistence(timeout: 30),
            "再試行に失敗したのに未完了の案内が消えている"
        )

        // === 4. 通信が回復した状態で起動し直すと、自動でやり直される ===
        launchFresh()
        openSettings()
        XCTAssertFalse(
            app.staticTexts["学習記録の引き継ぎが未完了です"].waitForExistence(timeout: 20),
            "起動時の自動再試行でリンクが完了していない"
        )
        closeSettings()

        // 取り残されていた匿名の回答が、アカウント側に回収されている。
        XCTAssertEqual(
            try readWeeklyAnswered(),
            accountBefore + 1,
            "リンク回復後も匿名の回答がアカウントへ回収されていない"
        )
    }

    // MARK: - 画面操作

    private func launchFresh(resetIdentity: Bool = false, failAccountLink: Bool = false) {
        app.terminate()
        var arguments: [String] = []
        if resetIdentity { arguments.append("-uitest-reset-identity") }
        if failAccountLink { arguments.append("-uitest-fail-account-link") }
        app.launchArguments = arguments
        app.launch()
        completeOnboardingIfNeeded()
    }

    /// 学習記録タブの「解答した問題」件数を読む。
    ///
    /// 要素が見つからない・値が読めない場合は **失敗** させる（skip にしない）。
    /// identifier の付け忘れや画面遷移の不具合、表示形式の変更は、まさにこの E2E で
    /// 検出したい回帰であり、skip にすると気づけないため。
    private func readWeeklyAnswered() throws -> Int {
        let value = app.staticTexts["stat.weeklyAnswered"]

        // 起動直後や画面遷移の途中はタブのタップが効かないことがあるため、
        // 切り替わったことを確認できるまで数回やり直す。
        for _ in 0..<4 {
            // 取りこぼし対策。ここでは待たずに、出ていれば閉じるだけ。
            dismissPasswordSavePromptIfNeeded(timeout: 0.5)
            let tab = app.tabBars.buttons["学習記録"]
            if tab.waitForExistence(timeout: 30), tab.isHittable {
                tab.tap()
            }
            if value.waitForExistence(timeout: 30) {
                return try parseCount(value.label)
            }
            sleep(1)
        }

        throw E2EError.elementNotFound("stat.weeklyAnswered（学習記録の「解答した問題」件数）")
    }

    private func parseCount(_ label: String) throws -> Int {
        let digits = label.filter(\.isNumber)
        guard !digits.isEmpty, let count = Int(digits) else {
            throw E2EError.unreadableValue(label)
        }
        return count
    }

    private func signInIfNeeded() {
        let loginRow = app.buttons["loginButton"]
        guard loginRow.waitForExistence(timeout: 10) else {
            // すでにログイン済みのはず。想定と別のアカウントなら以降の件数比較が
            // 成り立たないので、ここで失敗させる。
            XCTAssertTrue(
                app.staticTexts[email].exists,
                "ログイン導線が無いのに \(email) でログインしていない（別アカウントのセッションが残っている）"
            )
            return
        }

        loginRow.tap()

        let emailField = app.textFields["メールアドレス"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 10), "メールアドレス欄が出ない")
        emailField.tap()
        emailField.typeText(email)

        let passwordField = app.secureTextFields["パスワード"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 5), "パスワード欄が出ない")
        passwordField.tap()
        passwordField.typeText(password)

        app.buttons["ログイン"].firstMatch.tap()

        // ログイン直後に iOS の「Save Password?」が出ると以降のタップを全て
        // 飲み込んでしまうので、出ていれば閉じる。
        dismissPasswordSavePromptIfNeeded()

        // ログイン画面は /account/link の完了後に閉じるので、
        // メールアドレスが出た時点でリンクまで終わっている。
        XCTAssertTrue(
            app.staticTexts[email].waitForExistence(timeout: 90),
            "ログインできない（または /account/link が終わらない）"
        )
    }

    /// iOS のパスワード保存ダイアログ（"Save Password?"）を閉じる。
    /// SpringBoard 側に出る場合とアプリ側に出る場合の両方を見る。
    private func dismissPasswordSavePromptIfNeeded(timeout: TimeInterval = 10) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let labels = ["Not Now", "今はしない", "後で"]

        // 表示まで少し間があるので、少しだけ待つ。
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            for label in labels {
                let button = springboard.buttons[label]
                if button.exists && button.isHittable {
                    button.tap()
                    return
                }
                let inApp = app.buttons[label]
                if inApp.exists && inApp.isHittable {
                    inApp.tap()
                    return
                }
            }
            usleep(500_000)
        }
    }

    private func signOut() {
        let signOutRow = app.buttons["signOutButton"]
        XCTAssertTrue(signOutRow.waitForExistence(timeout: 10), "ログアウト導線が出ていない")
        signOutRow.tap()

        let confirm = app.alerts.buttons["ログアウト"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "ログアウトの確認が出ない")
        confirm.tap()

        XCTAssertTrue(
            app.buttons["loginButton"].waitForExistence(timeout: 20),
            "ログアウトできない"
        )
    }

    /// 要素がタップ可能になるまで待ってからタップする。
    ///
    /// 座標タップへフォールバックしないのは、この PR で直したいのが
    /// 「通常の Button として当たり判定が十分にあること」だから。
    /// 座標タップで回避すると、当たり判定が再び狭くなっても気づけない。
    @discardableResult
    private func tapWhenHittable(_ element: XCUIElement, timeout: TimeInterval = 20) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            // パスワード保存ダイアログはログイン完了より後に出ることがあり、
            // 出ている間は下の要素が hittable にならない。
            dismissPasswordSavePromptIfNeeded(timeout: 0.5)
            if element.isHittable {
                element.tap()
                return true
            }
            usleep(500_000)
        }
        return false
    }

    private func openSettings() {
        XCTAssertTrue(
            app.tabBars.buttons["マイページ"].waitForExistence(timeout: 60),
            "メイン画面に到達できない"
        )
        app.tabBars.buttons["マイページ"].tap()

        let settings = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "設定")).firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 15), "マイページから設定へ入れない")
        settings.tap()
    }

    /// 学習ホームで問題集を選び直す。選択済みなら何もしない。
    private func selectWorkbook() -> Bool {
        let change = app.buttons["問題集を変更"]
        guard change.waitForExistence(timeout: 30) else { return false }
        change.tap()

        let pick = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "この問題集で始める")
        ).firstMatch
        guard pick.waitForExistence(timeout: 30) else { return false }
        pick.tap()
        return true
    }

    private func closeSettings() {
        let back = app.buttons["BackButton"].exists
            ? app.buttons["BackButton"]
            : app.navigationBars.buttons.firstMatch
        if back.exists && back.isHittable {
            back.tap()
        }
        XCTAssertTrue(app.tabBars.buttons["学習"].waitForExistence(timeout: 20), "設定を閉じられない")
        app.tabBars.buttons["学習"].tap()
    }

    /// オンボーディングが出た場合は最後まで進める（出なければ何もしない）。
    /// 実際の遷移: 次へ → 問題集を選ぶ → 問題集を1つ選ぶ → 同意して次へ → はじめる。
    private func completeOnboardingIfNeeded() {
        let labels = ["次へ", "問題集を選ぶ", "この問題集で始める", "はじめる"]
        let deadline = Date().addingTimeInterval(240)

        while Date() < deadline {
            if app.tabBars.buttons["マイページ"].exists { return }

            // 同意チェックを入れないと「同意して次へ」が有効にならない。
            // ラベル付きの switch はタップに反応しない（実体は無ラベル側）。
            let agreeButton = app.buttons["同意して次へ"]
            if agreeButton.exists && !agreeButton.isEnabled {
                for index in 0..<app.switches.count {
                    app.switches.element(boundBy: index).tap()
                    usleep(300_000)
                    if agreeButton.isEnabled { break }
                }
            }

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

    /// 1問だけ解いて、履歴を保存してクイズを抜ける。
    private func answerOneQuestion() -> Bool {
        app.tabBars.buttons["学習"].tap()

        var start = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "はじめる")).firstMatch
        if !start.waitForExistence(timeout: 90) {
            // identity を作り直した直後は、この端末の選択中の問題集が引き継がれず
            // 学習ホームが未選択状態になることがある。その場合は選び直す。
            guard selectWorkbook() else { return false }
            start = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "はじめる")).firstMatch
            guard start.waitForExistence(timeout: 90) else { return false }
        }
        start.tap()

        let choice = app.buttons.matching(identifier: "quizChoice").element(boundBy: 0)
        guard choice.waitForExistence(timeout: 60) else { return false }
        choice.tap()

        var answered = false
        let deadline = Date().addingTimeInterval(15)
        while Date() < deadline {
            if app.buttons["結果を見る"].exists || app.buttons["次の問題へ"].exists {
                answered = true
                break
            }
            usleep(200_000)
        }
        guard answered else { return false }

        // 解説の表示アニメーション中などはタップが効かないことがあるので、
        // メイン画面に戻れるまで数回やり直す。
        for _ in 0..<3 {
            let back = app.buttons["quizBackButton"]
            if back.waitForExistence(timeout: 10), back.isHittable {
                back.tap()
            }

            // 「クイズを終了しますか？」。解答を残したいので必ず保存側を選ぶ
            // （ここで捨てるとマージ対象の学習記録が作られない）。
            let save = app.alerts.buttons["履歴を保存して戻る"]
            if save.waitForExistence(timeout: 10) {
                save.tap()
            }

            if app.tabBars.buttons["マイページ"].waitForExistence(timeout: 20) {
                return true
            }
        }
        return false
    }
}
