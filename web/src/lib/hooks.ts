"use client";

import { useSyncExternalStore } from "react";
import {
  AUTH_CHANGED_EVENT,
  AUTH_STORAGE_KEY,
  emailFromIdToken,
  AuthTokens,
} from "./tokens";

// localStorage の auth を購読する（ログイン/ログアウトで再レンダー）。
// useEffect + setState を避けるため useSyncExternalStore を使う（SSR は null）。
function subscribeAuth(cb: () => void): () => void {
  window.addEventListener("storage", cb);
  window.addEventListener(AUTH_CHANGED_EVENT, cb);
  return () => {
    window.removeEventListener("storage", cb);
    window.removeEventListener(AUTH_CHANGED_EVENT, cb);
  };
}

export function useAuthEmail(): string | null {
  const raw = useSyncExternalStore(
    subscribeAuth,
    () => window.localStorage.getItem(AUTH_STORAGE_KEY),
    () => null,
  );
  if (!raw) return null;
  try {
    const t = JSON.parse(raw) as AuthTokens;
    return emailFromIdToken(t.idToken);
  } catch {
    return null;
  }
}

// URL クエリパラメータ（静的エクスポート用）。navigation でのみ変わる。
function subscribeLocation(cb: () => void): () => void {
  window.addEventListener("popstate", cb);
  return () => window.removeEventListener("popstate", cb);
}

export function useQueryParam(key: string): string {
  return useSyncExternalStore(
    subscribeLocation,
    () => new URLSearchParams(window.location.search).get(key) ?? "",
    () => "",
  );
}
