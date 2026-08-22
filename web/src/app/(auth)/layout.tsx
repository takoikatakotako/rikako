import type { Metadata } from "next";

// ログイン系は検索結果に出す必要がないので noindex にする
// （このサイトの SEO 対象は問題ページ）。ルートグループなので URL は変わらない。
export const metadata: Metadata = {
  robots: { index: false, follow: false },
};

export default function AuthLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return <div className="mx-auto max-w-md">{children}</div>;
}
