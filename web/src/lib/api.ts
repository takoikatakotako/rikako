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
  // 未ログインでも学習記録はサーバーに持つため、常に端末識別子を送る。
  // ログイン中は Authorization が優先され、アカウントの記録として扱われる。
  headers.set("X-Device-ID", getDeviceId());
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
    headers: { "Content-Type": "application/json" },
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

// 直近の解答送信。次の画面で進捗を取りに行く前にこれを待つことで、
// 「今解いた問題が未解答のまま表示される」レースを防ぐ。
let pendingSubmission: Promise<unknown> = Promise.resolve();

// 送信中の解答があれば、その完了（失敗含む）を待つ。
export async function waitForPendingSubmission(): Promise<void> {
  await pendingSubmission.catch(() => {});
}

// 解答を1件送る。未ログインなら端末の匿名ユーザー、ログイン中はアカウントに記録される。
export function submitAnswer(
  workbookId: number,
  questionId: number,
  selectedChoice: number,
): Promise<void> {
  const task = postAnswer(workbookId, questionId, selectedChoice);
  // 失敗しても後続の待ち合わせを壊さないよう、保持側では握り潰す。
  pendingSubmission = task.catch(() => {});
  return task;
}

async function postAnswer(
  workbookId: number,
  questionId: number,
  selectedChoice: number,
): Promise<void> {
  const res = await authedFetch("/answers", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      workbookId,
      answers: [{ questionId, selectedChoice }],
    }),
  });
  if (!res.ok) {
    throw new ApiError(res.status, `submit answer failed: ${res.status}`);
  }
}

export type QuestionProgress = { questionId: number; isCorrect: boolean };

// 問題集の進捗（問題IDごとの最新の正誤）。
export async function getWorkbookProgress(
  workbookId: number,
): Promise<QuestionProgress[]> {
  const res = await authedFetch(
    `/users/me/workbook-progress?workbook_id=${workbookId}`,
    { method: "GET" },
  );
  if (!res.ok) {
    throw new ApiError(res.status, `get workbook progress failed: ${res.status}`);
  }
  const data = (await res.json()) as { results?: QuestionProgress[] };
  return data.results ?? [];
}
