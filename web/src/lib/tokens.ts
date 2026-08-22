// トークン保管。このサイトのみに閉じた localStorage（設計 §5.3: サブドメイン単位）。
// 跨ぎ SSO はしないため、他サブドメインとは共有しない。
const STORAGE_KEY = "rikako.it.auth";

export type AuthTokens = {
  idToken: string;
  accessToken: string;
  refreshToken: string;
  expiresAt: number; // epoch ms
};

// 同一タブ内でもログイン/ログアウトを検知できるよう独自イベントを発火する
// （storage イベントは他タブにしか飛ばないため）。
export const AUTH_CHANGED_EVENT = "rikako-auth-changed";
export const AUTH_STORAGE_KEY = STORAGE_KEY;

function notifyAuthChanged(): void {
  if (typeof window === "undefined") return;
  window.dispatchEvent(new Event(AUTH_CHANGED_EVENT));
}

export function saveTokens(t: AuthTokens): void {
  if (typeof window === "undefined") return;
  window.localStorage.setItem(STORAGE_KEY, JSON.stringify(t));
  notifyAuthChanged();
}

export function loadTokens(): AuthTokens | null {
  if (typeof window === "undefined") return null;
  const raw = window.localStorage.getItem(STORAGE_KEY);
  if (!raw) return null;
  try {
    return JSON.parse(raw) as AuthTokens;
  } catch {
    return null;
  }
}

export function clearTokens(): void {
  if (typeof window === "undefined") return;
  window.localStorage.removeItem(STORAGE_KEY);
  notifyAuthChanged();
}

// ID token の payload から email を取り出す（表示用。署名検証はサーバー側）。
export function emailFromIdToken(idToken: string): string | null {
  try {
    const payload = idToken.split(".")[1];
    const json = JSON.parse(
      atob(payload.replace(/-/g, "+").replace(/_/g, "/")),
    );
    return (json.email as string) ?? null;
  } catch {
    return null;
  }
}
