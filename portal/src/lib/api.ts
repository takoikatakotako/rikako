// Rikako API クライアント。Authorization に ID Token を付け、401（トークン期限切れ）
// なら refresh() で更新してから1回だけ再試行する。refresh 不能や再試行も 401 なら
// セッション終了として token を消す。
import { config } from "./config";
import { loadTokens, clearTokens } from "./tokens";
import { refresh } from "./cognito";
import { getDeviceId, rotateDeviceId } from "./deviceId";

export class ApiError extends Error {
  status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
    this.name = "ApiError";
  }
}

async function authedFetch(
  path: string,
  init: RequestInit,
  allowRetry = true,
): Promise<Response> {
  const idToken = loadTokens()?.idToken;
  const headers = new Headers(init.headers);
  if (idToken) headers.set("Authorization", `Bearer ${idToken}`);

  const res = await fetch(`${config.apiBaseUrl}${path}`, { ...init, headers });

  if (res.status === 401) {
    if (allowRetry) {
      const refreshed = await refresh().catch(() => null);
      if (refreshed) {
        return authedFetch(path, init, false);
      }
    }
    // refresh 不能 or 再試行も 401 → セッション終了。token を消すと
    // useAuthEmail が null になりログイン画面へ戻る。
    clearTokens();
    throw new ApiError(401, "unauthorized");
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
    throw new ApiError(res.status, `link account failed: ${res.status}`);
  }
  return res.json();
}

// アカウントが紐付いていることを保証する（冪等）。
// 同ブラウザで別アカウントへ切り替えた場合は device id が別アカウントに紐付き済みで
// 409 になるため、新しい UUID へ rotate して1回だけ再試行する。
export async function ensureAccountLinked(): Promise<void> {
  try {
    await linkAccount();
  } catch (e) {
    if (e instanceof ApiError && e.status === 409) {
      rotateDeviceId();
      await linkAccount();
      return;
    }
    throw e;
  }
}

export type Service = { slug: string; title: string };

// 利用中サービス（アプリ）一覧。認証必須（ID Token）。
export async function getServices(): Promise<Service[]> {
  const res = await authedFetch("/account/services", { method: "GET" });
  if (!res.ok) {
    throw new ApiError(res.status, `get services failed: ${res.status}`);
  }
  const data = (await res.json()) as { services?: Service[] };
  return data.services ?? [];
}

// アカウント削除（#408）。サーバーがアカウント・全端末の学習データ・Cognito ユーザーを消す。
// 成功したらローカルのトークンと device id を破棄し、新しい匿名ユーザーとしてやり直す。
// 204 でなければ ApiError（500 は「Cognito 側の削除確認が未完了」でもあり、再実行で収束する）。
export async function deleteAccount(): Promise<void> {
  const res = await authedFetch("/account", { method: "DELETE" });
  if (res.status !== 204) {
    throw new ApiError(res.status, `delete account failed: ${res.status}`);
  }
  clearTokens();
  // 削除したアカウントに紐付いていた device id を使い回すと、次のログイン時に
  // 「別アカウントに紐付き済み」ではなく「消えた users 行」を参照する。新しい id にする。
  rotateDeviceId();
}
