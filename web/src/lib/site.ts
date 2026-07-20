// サイト設定。NEXT_PUBLIC_SITE でビルド時に IT / 化学 を切り替える。
// content の categoryId と、各サイトのコピー・ドメインをここで一元管理する。

export type SiteKey = "it" | "chemistry";

export type SiteConfig = {
  key: SiteKey;
  categoryId: number; // content.rikako.org のカテゴリID（IT=2 / 化学=1）
  badge: string; // ヘッダーの小バッジ
  siteName: string; // ヘッダー名・タイトルの基礎
  description: string; // metadata description
  domain: string; // metadataBase 用
  heroTitle: string; // トップの見出し
  heroLead: string; // トップのリード文
  unitLabel: string; // 「試験回」「問題集」など選択単位の呼称
  sourceNote: string; // フッターの出典注記（無ければ空）
};

const SITES: Record<SiteKey, SiteConfig> = {
  it: {
    key: "it",
    categoryId: 2,
    badge: "IT",
    siteName: "ITパスポート過去問",
    description:
      "ITパスポート試験の公開問題（過去問）を無料で解ける・見られるWebアプリ。解説付き。令和6年度・令和7年度の全問を収録。",
    domain: "https://it.rikako.org",
    heroTitle: "ITパスポート過去問を無料で解く・見る",
    heroLead:
      "ITパスポート試験の公開問題（過去問）を、解説付きで解いたり見たりできます。会員登録は不要です。まずは試験回を選んでください。",
    unitLabel: "試験回",
    sourceNote: "ITパスポート試験の公開問題を利用しています。",
  },
  chemistry: {
    key: "chemistry",
    categoryId: 1,
    badge: "化学",
    siteName: "高校化学 問題集",
    description:
      "高校化学（化学基礎・高校化学）の問題を無料で解ける・見られるWebアプリ。解説付き。",
    domain: "https://chemist.rikako.org",
    heroTitle: "高校化学の問題を無料で解く・見る",
    heroLead:
      "化学基礎・高校化学の問題を、解説付きで解いたり見たりできます。会員登録は不要です。まずは問題集を選んでください。",
    unitLabel: "問題集",
    sourceNote: "",
  },
};

function resolveSiteKey(): SiteKey {
  return process.env.NEXT_PUBLIC_SITE === "chemistry" ? "chemistry" : "it";
}

export const siteConfig: SiteConfig = SITES[resolveSiteKey()];
