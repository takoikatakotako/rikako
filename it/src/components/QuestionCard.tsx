"use client";

import { useState } from "react";
import type { Question } from "@/lib/content";

const CHOICE_LABELS = ["ア", "イ", "ウ", "エ", "オ", "カ"];

export function QuestionCard({ question }: { question: Question }) {
  // 既定は「答えを見せる」状態（＝閲覧モード。静的HTMLに解説が載るのでSEOに効く）。
  // 「自分で解く」を押すと答えを隠して演習モードに切り替える。
  const [revealed, setRevealed] = useState(true);
  const [selected, setSelected] = useState<number | null>(null);

  const images = question.images ?? [];

  const startSolving = () => {
    setSelected(null);
    setRevealed(false);
  };

  const choose = (index: number) => {
    if (revealed) return;
    setSelected(index);
    setRevealed(true);
  };

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
    if (revealed && index === question.correct) {
      return `${base} bg-brand text-white`;
    }
    if (revealed && index === selected) {
      return `${base} bg-rose-400 text-white`;
    }
    return `${base} bg-slate-100 text-slate-600`;
  };

  const isCorrect = selected !== null && selected === question.correct;

  return (
    <div className="flex flex-col gap-5">
      {/* 問題文 */}
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

      {/* 選択肢 */}
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
            <span className="whitespace-pre-wrap self-center text-[15px] leading-relaxed">
              {choice}
            </span>
          </button>
        ))}
      </div>

      {/* 操作 / 結果 */}
      {revealed ? (
        <div className="flex flex-col gap-4">
          {selected !== null && (
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
          )}
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
          <button
            type="button"
            onClick={startSolving}
            className="inline-flex w-fit items-center rounded-xl border-2 border-brand px-4 py-2 text-sm font-bold text-brand-strong transition-colors hover:bg-brand-soft"
          >
            自分で解いてみる
          </button>
        </div>
      ) : (
        <p className="text-sm text-slate-500">選択肢を選んで解答してください。</p>
      )}
    </div>
  );
}
