import { beforeEach, describe, expect, it, vi } from "vitest";

// localStorage（tokens / deviceId）と fetch を差し替えてから api を読み込む。
function installBrowserStubs() {
  const store = new Map<string, string>();
  vi.stubGlobal("window", {
    localStorage: {
      getItem: (k: string) => store.get(k) ?? null,
      setItem: (k: string, v: string) => void store.set(k, v),
      removeItem: (k: string) => void store.delete(k),
    },
    dispatchEvent: () => true,
  });
  vi.stubGlobal("crypto", { randomUUID: () => "test-device-id" });
  // ログイン済みにする（Authorization が付く経路）。
  store.set(
    "rikako.it.auth",
    JSON.stringify({
      idToken: "id",
      accessToken: "access",
      refreshToken: "refresh",
      expiresAt: Date.now() + 3_600_000,
    }),
  );
  return store;
}

function jsonResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

const linkRequired = () =>
  jsonResponse(400, { code: "ACCOUNT_LINK_REQUIRED", message: "link first" });

describe("ACCOUNT_LINK_REQUIRED からの回復", () => {
  beforeEach(() => {
    vi.resetModules();
    vi.unstubAllGlobals();
    installBrowserStubs();
  });

  // (1) 400 を受けた時点で link がまだ始まっていないケース。
  // 「進行中の link を待つ」だけでは何も待てず 400 のまま返ってしまう。
  it("link 未開始でも link を開始してから再試行する", async () => {
    const calls: string[] = [];
    const fetchMock = vi.fn(async (url: string) => {
      calls.push(url);
      if (url.endsWith("/account/link")) return jsonResponse(200, { accountId: 1 });
      if (calls.filter((u) => u.includes("workbook-progress")).length === 1) {
        return linkRequired();
      }
      return jsonResponse(200, { results: [{ questionId: 1, isCorrect: true }] });
    });
    vi.stubGlobal("fetch", fetchMock);

    const { getWorkbookProgress } = await import("../api");
    const results = await getWorkbookProgress(3);

    expect(results).toEqual([{ questionId: 1, isCorrect: true }]);
    expect(calls.some((u) => u.endsWith("/account/link"))).toBe(true);
    // 進捗 GET は 400 の1回 + 再試行の1回だけ（無限に繰り返さない）。
    expect(calls.filter((u) => u.includes("workbook-progress"))).toHaveLength(2);
  });

  // (2) 400 を受け取る前に link が完了し、保持していた promise が消えているケース。
  // link 自体は成功しているのに通常 API だけ 400 で終わってはいけない。
  it("link 完了済みでも 400 を受けたら link をやり直して再試行する", async () => {
    const calls: string[] = [];
    const fetchMock = vi.fn(async (url: string) => {
      calls.push(url);
      if (url.endsWith("/account/link")) return jsonResponse(200, { accountId: 1 });
      if (calls.filter((u) => u.includes("workbook-progress")).length === 1) {
        return linkRequired();
      }
      return jsonResponse(200, { results: [] });
    });
    vi.stubGlobal("fetch", fetchMock);

    const { ensureAccountLinked, getWorkbookProgress } = await import("../api");

    // 先に link を完了させ、single-flight の保持を解除させる。
    await ensureAccountLinked();
    const linkCallsAfterFirst = calls.filter((u) => u.endsWith("/account/link")).length;
    expect(linkCallsAfterFirst).toBe(1);

    await expect(getWorkbookProgress(3)).resolves.toEqual([]);

    // 400 を受けて link をやり直している。
    expect(calls.filter((u) => u.endsWith("/account/link")).length).toBe(2);
    expect(calls.filter((u) => u.includes("workbook-progress"))).toHaveLength(2);
  });

  // 401 の refresh と link の再試行は別枠。共用だと refresh に成功しても
  // その後の ACCOUNT_LINK_REQUIRED を回復できない。
  it("401 -> refresh -> ACCOUNT_LINK_REQUIRED -> link -> 200 を通す", async () => {
    const calls: string[] = [];
    let progressCalls = 0;
    const fetchMock = vi.fn(async (url: string) => {
      calls.push(url);
      if (url.includes("cognito-idp")) {
        return jsonResponse(200, {
          AuthenticationResult: {
            IdToken: "id2",
            AccessToken: "access2",
            RefreshToken: "refresh2",
            ExpiresIn: 3600,
          },
        });
      }
      if (url.endsWith("/account/link")) return jsonResponse(200, { accountId: 1 });
      progressCalls += 1;
      if (progressCalls === 1) return jsonResponse(401, {});
      if (progressCalls === 2) return linkRequired();
      return jsonResponse(200, { results: [] });
    });
    vi.stubGlobal("fetch", fetchMock);

    const { getWorkbookProgress } = await import("../api");
    await expect(getWorkbookProgress(3)).resolves.toEqual([]);

    expect(calls.some((u) => u.includes("cognito-idp"))).toBe(true);
    expect(calls.filter((u) => u.endsWith("/account/link"))).toHaveLength(1);
    // 401 / 400 / 成功 の3回だけ（それぞれの再試行は1回まで）。
    expect(progressCalls).toBe(3);
  });

  // 逆順（link 回復のあとに 401）も同様に通る。
  it("ACCOUNT_LINK_REQUIRED -> link -> 401 -> refresh -> 200 を通す", async () => {
    const calls: string[] = [];
    let progressCalls = 0;
    const fetchMock = vi.fn(async (url: string) => {
      calls.push(url);
      if (url.includes("cognito-idp")) {
        return jsonResponse(200, {
          AuthenticationResult: {
            IdToken: "id2",
            AccessToken: "access2",
            RefreshToken: "refresh2",
            ExpiresIn: 3600,
          },
        });
      }
      if (url.endsWith("/account/link")) return jsonResponse(200, { accountId: 1 });
      progressCalls += 1;
      if (progressCalls === 1) return linkRequired();
      if (progressCalls === 2) return jsonResponse(401, {});
      return jsonResponse(200, { results: [] });
    });
    vi.stubGlobal("fetch", fetchMock);

    const { getWorkbookProgress } = await import("../api");
    await expect(getWorkbookProgress(3)).resolves.toEqual([]);

    expect(progressCalls).toBe(3);
  });

  // 同じ回復を繰り返さない（無限再試行にしない）。
  it("ACCOUNT_LINK_REQUIRED が続く場合は1回で諦める", async () => {
    let progressCalls = 0;
    const fetchMock = vi.fn(async (url: string) => {
      if (url.endsWith("/account/link")) return jsonResponse(200, { accountId: 1 });
      progressCalls += 1;
      return linkRequired();
    });
    vi.stubGlobal("fetch", fetchMock);

    const { getWorkbookProgress } = await import("../api");
    await expect(getWorkbookProgress(3)).rejects.toThrow();
    expect(progressCalls).toBe(2);
  });

  // 並行して呼んでも link は1回だけ（single-flight）。
  it("並行呼び出しでも link は1回だけ走る", async () => {
    const calls: string[] = [];
    let resolveLink: (r: Response) => void = () => {};
    const fetchMock = vi.fn(async (url: string) => {
      calls.push(url);
      if (url.endsWith("/account/link")) {
        return new Promise<Response>((r) => {
          resolveLink = r;
        });
      }
      return jsonResponse(200, { results: [] });
    });
    vi.stubGlobal("fetch", fetchMock);

    const { ensureAccountLinked } = await import("../api");
    const a = ensureAccountLinked();
    const b = ensureAccountLinked();
    resolveLink(jsonResponse(200, { accountId: 1 }));
    await Promise.all([a, b]);

    expect(calls.filter((u) => u.endsWith("/account/link"))).toHaveLength(1);
  });
});
