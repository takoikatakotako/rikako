// Rikako API クライアント。Authorization に ID Token を付け、401（トークン期限切れ）
// なら refresh() で更新してから1回だけ再試行する。
import { config } from "./config";
import { loadTokens } from "./tokens";
import { refresh } from "./cognito";
import { getDeviceId } from "./deviceId";

async function authedFetch(
  path: string,
  init: RequestInit,
  allowRetry = true,
): Promise<Response> {
  const idToken = loadTokens()?.idToken;
  const headers = new Headers(init.headers);
  if (idToken) headers.set("Authorization", `Bearer ${idToken}`);

  const res = await fetch(`${config.apiBaseUrl}${path}`, { ...init, headers });

  // ID Token 期限切れ等は refresh して1回だけ再試行。
  if (res.status === 401 && allowRetry) {
    const refreshed = await refresh().catch(() => null);
    if (refreshed) {
      return authedFetch(path, init, false);
    }
  }
  return res;
}

export type AccountResponse = { accountId: number; email?: string };

// ログイン後に呼ぶ。JWT sub からアカウントを解決/作成し、この端末の匿名データを
// canonical user へ冪等マージする。
export async function linkAccount(): Promise<AccountResponse> {
  const res = await authedFetch("/account/link", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Device-ID": getDeviceId(),
    },
    body: JSON.stringify({}),
  });
  if (!res.ok) {
    throw new Error(`link account failed: ${res.status}`);
  }
  return res.json();
}

export type Service = { slug: string; title: string };

// 利用中サービス（アプリ）一覧。認証必須（ID Token）。
export async function getServices(): Promise<Service[]> {
  const res = await authedFetch("/account/services", { method: "GET" });
  if (!res.ok) {
    throw new Error(`get services failed: ${res.status}`);
  }
  const data = (await res.json()) as { services?: Service[] };
  return data.services ?? [];
}
