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
  appSlug: string;
  appName: string;
  appStoreUrl: string;
  playStoreUrl: string;
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
    appSlug: "it-passport",
    appName: "４択IT",
    appStoreUrl: "https://apps.apple.com/jp/app/%EF%BC%94%E6%8A%9Eit%E3%83%91%E3%82%B9%E3%83%9D%E3%83%BC%E3%83%88/id6772535532",
    playStoreUrl: "https://play.google.com/store/apps/details?id=org.rikako.itpassport",
  },
  chemistry: {
    key: "chemistry",
    categoryId: 1,
    badge: "化学",
    siteName: "高校化学 問題集",
    description:
      "高校化学（化学基礎・高校化学）の問題を無料で解ける・見られるWebアプリ。解説付き。",
    domain: "https://chemistry.rikako.org",
    heroTitle: "高校化学の問題を無料で解く・見る",
    heroLead:
      "化学基礎・高校化学の問題を、解説付きで解いたり見たりできます。会員登録は不要です。まずは問題集を選んでください。",
    unitLabel: "問題集",
    sourceNote: "",
    appSlug: "high-school-chemistry",
    appName: "４択化学",
    appStoreUrl: "https://apps.apple.com/jp/app/%EF%BC%94%E6%8A%9E%E5%8C%96%E5%AD%A6/id960647263",
    playStoreUrl: "https://play.google.com/store/apps/details?id=org.rikako.chemistry",
  },
};

function resolveSiteKey(): SiteKey {
  return process.env.NEXT_PUBLIC_SITE === "chemistry" ? "chemistry" : "it";
}

export const siteConfig: SiteConfig = SITES[resolveSiteKey()];
