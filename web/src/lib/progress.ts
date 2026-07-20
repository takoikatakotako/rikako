// 解答の進捗を localStorage に保存する（ログイン不要・匿名）。
// 過去問道場のように「解いた問題・正誤・続きから」を扱うための最小ストア。

const STORAGE_KEY = "it_progress_v1";

export type AnswerResult = "correct" | "incorrect";
export type ProgressMap = Record<string, AnswerResult>;

function readAll(): ProgressMap {
  if (typeof window === "undefined") return {};
  try {
    return JSON.parse(
      window.localStorage.getItem(STORAGE_KEY) ?? "{}",
    ) as ProgressMap;
  } catch {
    return {};
  }
}

function writeAll(map: ProgressMap): void {
  if (typeof window === "undefined") return;
  window.localStorage.setItem(STORAGE_KEY, JSON.stringify(map));
}

export function recordResult(questionId: number, result: AnswerResult): void {
  const map = readAll();
  map[String(questionId)] = result;
  writeAll(map);
}

export function getResult(questionId: number): AnswerResult | undefined {
  return readAll()[String(questionId)];
}

/** 指定した問題IDのうち、記録がある分だけ返す */
export function getResults(questionIds: number[]): ProgressMap {
  const all = readAll();
  const out: ProgressMap = {};
  for (const id of questionIds) {
    const r = all[String(id)];
    if (r) out[String(id)] = r;
  }
  return out;
}

/** 指定した問題IDの記録を消す（試験回単位のリセット用） */
export function clearResults(questionIds: number[]): void {
  const all = readAll();
  for (const id of questionIds) delete all[String(id)];
  writeAll(all);
}
