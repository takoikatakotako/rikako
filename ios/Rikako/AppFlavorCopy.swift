import Foundation

/// フレーバー（化学 / IT パスポート）で出し分ける画面文言（#384）。
///
/// 画面側に `AppFlavor.current.slug` の分岐を散らさず、ここに 1 か所に集める。
/// Android の `OnboardingScreen.kt`（`isChemistry` 分岐）と同じ文言にしてある。
/// マスコット名「理科子」は両フレーバー共通。
struct AppFlavorCopy {
    /// オンボーディング 1 ページ目（挨拶）の本文
    let onboardingWelcomeMessages: [String]
    /// オンボーディング 2 ページ目（問題集の説明）の本文
    let onboardingWorkbookIntroMessages: [String]
    /// ホーム画面のおすすめ問題集カードにある、本の表紙風バッジの文言
    let homeHeroBadge: String

    init(slug: String) {
        switch slug {
        case "it-passport":
            onboardingWelcomeMessages = [
                "ITパスポートの問題を一緒に解いていこうね！",
                "毎日少しずつ進めていこう！"
            ]
            onboardingWorkbookIntroMessages = [
                "ITパスポートは分野が広いので、いきなり全部はやらなくて大丈夫。",
                "次のページで問題集を選択できるから、学びたい問題集を選んでみてね。",
                "特になければ、おすすめの問題集から始めてみよう！"
            ]
            homeHeroBadge = "0点から\nITパスポート"
        default:
            onboardingWelcomeMessages = [
                "このアプリは高校生向けの化学を楽しく学ぶためのアプリです！",
                "一緒に楽しく勉強していこうね！"
            ]
            onboardingWorkbookIntroMessages = [
                "高校化学とはいっても、範囲や分野はいろいろあります。",
                "次のページで問題集を選択できるから、学びたい問題集を選んでみてね。",
                "特になければ、おすすめの基礎の問題集を選んでみよう！"
            ]
            homeHeroBadge = "0点から\n化学基礎"
        }
    }
}

extension AppFlavor {
    /// このフレーバーの画面文言
    var copy: AppFlavorCopy { AppFlavorCopy(slug: slug) }
}
