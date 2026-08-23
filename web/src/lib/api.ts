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

// セッション単位の single-flight な link。link 前に通常 API が走ると、サーバーが
// ACCOUNT_LINK_REQUIRED を返すので、その場合は「進行中なら待つ／未開始なら開始する」
// を同じ promise で行い、完了後に1回だけやり直す。
//
// 「進行中のものがあれば待つ」だけでは足りない。次の窓では null のままだからで、
// そこで諦めると link が成功していても通常 API だけ 400 で終わってしまう。
//   - link を開始する前
//   - link 開始前の待ち合わせ中（送信中の解答を待っている間）
//   - サーバーが 400 を決めた後、クライアントが受け取る前に link が完了した場合
let linkReady: Promise<void> | null = null;

// link を保証する。進行中ならその promise を返し、未開始/完了済みなら開始する。
// 完了したら保持を解除するので、後からの ACCOUNT_LINK_REQUIRED では link をやり直せる
// （アカウント切替後など）。link 自体は冪等。
function ensureLinkReady(): Promise<void> {
  if (linkReady) return linkReady;

  const task = performAccountLink();
  linkReady = task;
  void task.catch(() => {}).then(() => {
    if (linkReady === task) linkReady = null;
  });
  return task;
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

  // link 前に通常 API が走った場合。link を保証してから1回だけやり直す。
  // /account/link 自身は対象外（再帰する）。
  if (res.status === 400 && allowRetry && path !== "/account/link") {
    const body = await res.clone().json().catch(() => null);
    if (body?.code === "ACCOUNT_LINK_REQUIRED") {
      await ensureLinkReady().catch(() => {});
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
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({}),
  });
  if (!res.ok) {
    throw new ApiError(res.status, `link account failed: ${res.status}`);
  }
  return res.json();
}

// アカウントが紐付いていることを保証する（冪等）。通常 API 側の回復と
// 同じ single-flight を共有するので、並行して呼んでも link は1回だけ走る。
export function ensureAccountLinked(): Promise<void> {
  return ensureLinkReady();
}

// 同ブラウザで別アカウントへ切り替えた場合は device id が別アカウントに紐付き済みで
// 409 になるため、新しい UUID へ rotate して1回だけ再試行する。
async function performAccountLink(): Promise<void> {
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

// 送信中の解答送信をすべて保持する。直近1件だけだと、A を送信中に B を解答した
// 場合に A が追跡対象から外れ、B だけ待って進捗を取りに行ってしまう。
const inFlightSubmissions = new Set<Promise<unknown>>();

// 送信中の解答がすべて決着する（成功・失敗どちらでも）まで待つ。
// 進捗の取得前と /account/link の前の両方で待つ必要がある:
// - 進捗より先に解答が確定していないと、解いた問題が未解答として表示される
// - link より後に匿名 POST が確定すると、その回答は旧 device user に入り、
//   終わったマージの対象外になってアカウントへ回収されない
export async function waitForPendingSubmissions(): Promise<void> {
  await Promise.allSettled([...inFlightSubmissions]);
}

// 解答を1件送る。未ログインなら端末の匿名ユーザー、ログイン中はアカウントに記録される。
export function submitAnswer(
  workbookId: number,
  questionId: number,
  selectedChoice: number,
): Promise<void> {
  const task = postAnswer(workbookId, questionId, selectedChoice);
  inFlightSubmissions.add(task);
  // 失敗しても後続の待ち合わせを壊さないよう、保持側では握り潰す。
  void task.catch(() => {}).finally(() => inFlightSubmissions.delete(task));
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
