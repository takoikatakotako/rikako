"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { clearResults, getResults, type ProgressMap } from "@/lib/progress";

export function ExamProgress({ questionIds }: { questionIds: number[] }) {
  const router = useRouter();
  const [progress, setProgress] = useState<ProgressMap>({});
  const [loaded, setLoaded] = useState(false);

  // localStorage はクライアント限定のため、マウント後に読み込んで反映する
  // （SSR/初回描画は未ロード状態にしてハイドレーション不整合を避ける）。
  useEffect(() => {
    /* eslint-disable react-hooks/set-state-in-effect */
    setProgress(getResults(questionIds));
    setLoaded(true);
    /* eslint-enable react-hooks/set-state-in-effect */
  }, [questionIds]);

  const total = questionIds.length;
  const answered = Object.keys(progress).length;
  const correct = Object.values(progress).filter((r) => r === "correct").length;
  const rate = answered > 0 ? Math.round((correct / answered) * 100) : 0;
  const allDone = loaded && total > 0 && answered === total;

  const firstUnanswered = questionIds.find((id) => !progress[String(id)]);
  const continueId = firstUnanswered ?? questionIds[0];
  const firstIncorrectId = questionIds.find(
    (id) => progress[String(id)] === "incorrect",
  );

  const reset = () => {
    if (!window.confirm("この試験回の解答履歴をリセットします。よろしいですか？")) {
      return;
    }
    clearResults(questionIds);
    setProgress({});
  };

  // 全問終了バナーから「もう一度最初から」: 履歴を消して問1へ。
  const restart = () => {
    clearResults(questionIds);
    setProgress({});
    router.push(`/questions/${questionIds[0]}/`);
  };

  const completionMessage = (): string => {
    if (rate >= 80) return "素晴らしい！この回はしっかり解けているね 🎉";
    if (rate >= 60) return "その調子！間違えた問題を見直せば完璧だよ。";
    return "お疲れさま！×の問題をもう一度解いて定着させよう。";
  };

  return (
    <div className="flex flex-col gap-5">
      {allDone ? (
        /* 全問終了：達成バナー（＝結果画面） */
        <div className="rounded-2xl border-2 border-brand bg-brand-soft p-5 text-center">
          <p className="text-sm font-bold text-brand-strong">全問終了！</p>
          <p className="mt-1 text-4xl font-bold text-brand-strong">
            {rate}
            <span className="text-2xl">%</span>
          </p>
          <p className="mt-0.5 text-sm text-slate-600">
            正解 {correct} / {total} 問
          </p>
          <p className="mt-2 text-sm text-slate-600">{completionMessage()}</p>
          <div className="mt-4 flex flex-wrap justify-center gap-2">
            {firstIncorrectId !== undefined && (
              <Link
                href={`/questions/${firstIncorrectId}/`}
                className="rounded-xl bg-brand px-5 py-2.5 text-sm font-bold text-white transition-colors hover:bg-brand-strong"
              >
                間違えた問題を解く
              </Link>
            )}
            <button
              type="button"
              onClick={restart}
              className="rounded-xl border border-slate-300 bg-white px-4 py-2.5 text-sm font-bold text-slate-600 transition-colors hover:bg-slate-50"
            >
              もう一度最初から
            </button>
          </div>
        </div>
      ) : (
        /* 途中まで（または未着手）：解答状況サマリー */
        <div className="rounded-2xl border border-slate-200 bg-white p-4">
          <div className="flex items-baseline justify-between">
            <span className="text-sm text-slate-500">解答状況</span>
            {loaded && answered > 0 && (
              <span className="text-sm font-medium text-brand-strong">
                正答率 {rate}%
              </span>
            )}
          </div>
          <p className="mt-1 text-lg font-bold">
            {loaded ? answered : 0} / {total} 問
            {loaded && answered > 0 && (
              <span className="ml-2 text-sm font-medium text-slate-500">
                正解 {correct}
              </span>
            )}
          </p>
          <div className="mt-3 flex flex-wrap gap-2">
            <Link
              href={`/questions/${continueId}/`}
              className="rounded-xl bg-brand px-5 py-2.5 text-sm font-bold text-white transition-colors hover:bg-brand-strong"
            >
              {loaded && answered > 0 ? "続きから解く" : "問1から解く"}
            </Link>
            {loaded && answered > 0 && (
              <button
                type="button"
                onClick={reset}
                className="rounded-xl border border-slate-300 px-4 py-2.5 text-sm font-bold text-slate-600 transition-colors hover:bg-slate-50"
              >
                リセット
              </button>
            )}
          </div>
        </div>
      )}

      {/* 問題一覧（解答状況つき） */}
      <div>
        <h2 className="mb-2 text-lg font-semibold">問題一覧</h2>
        <ol className="grid grid-cols-[repeat(auto-fill,minmax(4rem,1fr))] gap-2">
          {questionIds.map((id, i) => {
            const r = progress[String(id)];
            const stateClass =
              loaded && r === "correct"
                ? "border-brand bg-brand-soft text-brand-strong"
                : loaded && r === "incorrect"
                  ? "border-rose-300 bg-rose-50 text-rose-500"
                  : "border-slate-200 bg-white hover:border-brand hover:bg-brand-soft";
            return (
              <li key={id}>
                <Link
                  href={`/questions/${id}/`}
                  className={`flex h-12 flex-col items-center justify-center rounded-xl border text-sm font-semibold transition-colors ${stateClass}`}
                >
                  <span>問{i + 1}</span>
                  {loaded && r && (
                    <span className="text-xs leading-none">
                      {r === "correct" ? "○" : "×"}
                    </span>
                  )}
                </Link>
              </li>
            );
          })}
        </ol>
      </div>
    </div>
  );
}
