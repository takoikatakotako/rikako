"use client";

import { useState, useEffect } from "react";

/**
 * Reads the slug from the browser URL on mount.
 * This is needed because Next.js static export embeds slug=[] in the HTML,
 * so direct access to /categories/3 would otherwise show the list page.
 */
export function useRouteSlug(prefix: string) {
  const [slug, setSlug] = useState<string[] | undefined>(undefined);
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    const path = window.location.pathname.replace(/\/+$/, "");
    const segments = path.split("/").filter(Boolean);
    // Find prefix index and take everything after it
    const prefixIndex = segments.indexOf(prefix);
    const sub = prefixIndex >= 0 ? segments.slice(prefixIndex + 1) : [];
    setSlug(sub.length > 0 ? sub : undefined);
    setMounted(true);
  }, [prefix]);

  return { slug, mounted };
}
