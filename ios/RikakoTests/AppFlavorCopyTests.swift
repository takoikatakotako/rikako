import Testing
@testable import Rikako

/// フレーバー別の画面文言（#384）。IT 版に化学の表記が混ざらないこと。
struct AppFlavorCopyTests {
    @Test func chemistryCopyMentionsChemistry() {
        let copy = AppFlavorCopy(slug: "high-school-chemistry")
        #expect(copy.onboardingWelcomeMessages.joined().contains("化学"))
        #expect(copy.onboardingWorkbookIntroMessages.joined().contains("化学"))
        #expect(copy.homeHeroBadge == "0点から\n化学基礎")
    }

    @Test func itPassportCopyDoesNotMentionChemistry() {
        let copy = AppFlavorCopy(slug: "it-passport")
        let all = (copy.onboardingWelcomeMessages + copy.onboardingWorkbookIntroMessages + [copy.homeHeroBadge]).joined()
        #expect(!all.contains("化学"))
        #expect(all.contains("ITパスポート"))
    }

    @Test func unknownSlugFallsBackToChemistry() {
        #expect(AppFlavorCopy(slug: "unknown").homeHeroBadge == AppFlavorCopy(slug: "high-school-chemistry").homeHeroBadge)
    }
}
