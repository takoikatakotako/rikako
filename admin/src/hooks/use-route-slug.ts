"use client";

import { useState, useEffect } from "react";
import { usePathname } from "next/navigation";

/**
 * Reads the slug from the current pathname.
 * This is needed because Next.js static export embeds slug=[] in the HTML,
 * so direct access to /categories/3 would otherwise show the list page.
 *
 * usePathname を購読することで、クライアントサイド遷移（例: /questions/5 →
 * /questions）でも再評価され、画面が正しく切り替わる。
 */
export function useRouteSlug(prefix: string) {
  const pathname = usePathname();
  const [slug, setSlug] = useState<string[] | undefined>(undefined);
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    const path = (pathname ?? "").replace(/\/+$/, "");
    const segments = path.split("/").filter(Boolean);
    // Find prefix index and take everything after it
    const prefixIndex = segments.indexOf(prefix);
    const sub = prefixIndex >= 0 ? segments.slice(prefixIndex + 1) : [];
    setSlug(sub.length > 0 ? sub : undefined);
    setMounted(true);
  }, [prefix, pathname]);

  return { slug, mounted };
}
