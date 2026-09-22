import type { Metadata } from "next";

// Play のアカウント削除要件（#422）: 削除ページ自体にストア掲載のアプリ名・運営者名が
// 含まれている必要がある。title / description にも入れておく。
export const metadata: Metadata = {
  title: "アカウントの削除 - ４択化学 / ４択IT（PureFlatAtSmallField）",
  description:
    "４択化学・４択IT（運営: 小野純平 / PureFlatAtSmallField / junpei ono）のアカウントと学習データを削除する手順。",
};

export default function DeleteLayout({ children }: { children: React.ReactNode }) {
  return children;
}
