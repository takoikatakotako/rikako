"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import type { Question } from "@/lib/content";
import { submitAnswer } from "@/lib/api";

const CHOICE_LABELS = ["ア", "イ", "ウ", "エ", "オ", "カ"];

export function QuestionCard({
  question,
  workbookId,
  nextHref,
  backHref,
}: {
  question: Question;
  workbookId: number;
  nextHref: string | null;
  backHref: string;
}) {
  // 解くフロー: 既定は答えを隠した状態。選択肢を選ぶと採点し、解説と「次の問題へ」を出す。
  const router = useRouter();
  const [revealed, setRevealed] = useState(false);
  const [selected, setSelected] = useState<number | null>(null);
  const resultRef = useRef<HTMLDivElement>(null);

  const images = question.images ?? [];
  const isCorrect = selected !== null && selected === question.correct;
  // 解答後に進む先。最終問なら一覧（＝結果）へ。
  const forwardHref = nextHref ?? backHref;

  const choose = useCallback(
    (index: number) => {
      setSelected(index);
      setRevealed(true);
      // 記録はサーバー側。失敗しても解答体験は止めない（次に解いたときに再度送られる）。
      void submitAnswer(workbookId, question.id, index).catch(() => {});
    },
    [workbookId, question.id],
  );

  const retry = () => {
    setSelected(null);
    setRevealed(false);
  };

  // D: 解答したら結果・解説へスッと寄せる（スマホで下に隠れがちなため）。
  useEffect(() => {
    if (revealed) {
      resultRef.current?.scrollIntoView({ behavior: "smooth", block: "center" });
    }
  }, [revealed]);

  // C: キーボード操作。未解答時は 1〜n で選択、解答後は Enter / → で次へ。
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.metaKey || e.ctrlKey || e.altKey) return;
      const tag = (e.target as HTMLElement | null)?.tagName;
      if (tag === "INPUT" || tag === "TEXTAREA") return;

      if (!revealed) {
        const n = Number(e.key);
        if (Number.isInteger(n) && n >= 1 && n <= question.choices.length) {
          e.preventDefault();
          choose(n - 1);
        }
      } else if (e.key === "Enter" || e.key === "ArrowRight") {
        e.preventDefault();
        router.push(forwardHref);
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [revealed, question.choices.length, choose, forwardHref, router]);

  const choiceClass = (index: number): string => {
    const base =
      "flex w-full items-start gap-3 rounded-2xl border-2 p-3.5 text-left transition-colors";
    if (!revealed) {
      return `${base} border-slate-200 bg-white hover:border-brand/50 hover:bg-brand-soft`;
    }
    if (index === question.correct) {
      return `${base} border-brand bg-brand-soft`;
    }
    if (index === selected) {
      return `${base} border-rose-300 bg-rose-50`;
    }
    return `${base} border-slate-200 bg-white opacity-60`;
  };

  const badgeClass = (index: number): string => {
    const base =
      "mt-0.5 flex h-7 w-7 shrink-0 items-center justify-center rounded-full text-sm font-bold";
    if (revealed && index === question.correct) return `${base} bg-brand text-white`;
    if (revealed && index === selected) return `${base} bg-rose-400 text-white`;
    return `${base} bg-slate-100 text-slate-600`;
  };

  return (
    <div className="flex flex-col gap-5">
      <div className="whitespace-pre-wrap rounded-2xl bg-slate-100 p-4 text-[15px] leading-relaxed text-slate-800">
        {question.text}
      </div>

      {images.length > 0 && (
        <div className="flex flex-col gap-2">
          {images.map((src) => (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              key={src}
              src={src}
              alt="問題図"
              className="max-w-full rounded-xl border border-slate-200"
            />
          ))}
        </div>
      )}

      <div className="flex flex-col gap-2.5">
        {question.choices.map((choice, index) => (
          <button
            key={index}
            type="button"
            onClick={() => choose(index)}
            disabled={revealed}
            className={choiceClass(index)}
          >
            <span className={badgeClass(index)}>
              {CHOICE_LABELS[index] ?? index + 1}
            </span>
            <span className="self-center whitespace-pre-wrap text-[15px] leading-relaxed">
              {choice}
            </span>
          </button>
        ))}
      </div>

      {!revealed && (
        <p className="text-sm text-slate-500">
          選択肢を選んで解答してください。
          <span className="ml-1 hidden text-slate-400 sm:inline">
            （キーボードの 1〜{question.choices.length} でも選べます）
          </span>
        </p>
      )}

      {/* 解答結果・解説（SEO のため DOM には常に置き、未解答時は非表示にする） */}
      <div ref={resultRef} className={revealed ? "flex flex-col gap-4" : "hidden"}>
        <div
          className={`flex items-center gap-2 text-base font-bold ${
            isCorrect ? "text-brand-strong" : "text-rose-500"
          }`}
        >
          <span
            className={`flex h-6 w-6 items-center justify-center rounded-full text-white ${
              isCorrect ? "bg-brand" : "bg-rose-400"
            }`}
          >
            {isCorrect ? "○" : "×"}
          </span>
          {isCorrect ? "正解！" : "不正解"}
        </div>

        <div className="rounded-2xl border border-slate-200 bg-white p-4">
          <p className="text-sm font-bold text-brand-strong">
            正解: {CHOICE_LABELS[question.correct] ?? question.correct + 1}
          </p>
          {question.explanation && (
            <p className="mt-2 whitespace-pre-wrap text-sm leading-relaxed text-slate-600">
              {question.explanation}
            </p>
          )}
        </div>

        <div className="flex items-center gap-3">
          <Link
            href={forwardHref}
            className="inline-flex flex-1 items-center justify-center rounded-xl bg-brand px-5 py-3 text-sm font-bold text-white transition-colors hover:bg-brand-strong"
          >
            {nextHref ? "次の問題へ →" : "結果を見る →"}
          </Link>
          <button
            type="button"
            onClick={retry}
            className="inline-flex items-center rounded-xl border-2 border-slate-300 px-4 py-3 text-sm font-bold text-slate-600 transition-colors hover:bg-slate-50"
          >
            もう一度
          </button>
        </div>
      </div>
    </div>
  );
}
