"use client";

import { useEffect } from "react";
import { usePathname } from "next/navigation";

/**
 * 画面遷移時にメインコンテンツ領域を先頭へスクロールし直す。
 *
 * スクロール領域は window ではなくレイアウト内側の <main id="main-scroll">
 * （layout.tsx）であり、Next.js の遷移時スクロールリセットは window を対象に
 * するため <main> の scrollTop が残ってしまう。pathname の変化を検知して
 * 明示的に先頭へ戻す。
 */
export function ScrollReset() {
  const pathname = usePathname();

  useEffect(() => {
    document.getElementById("main-scroll")?.scrollTo({ top: 0 });
  }, [pathname]);

  return null;
}
