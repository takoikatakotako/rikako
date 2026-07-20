"use client";

import { useState } from "react";
import type { Question } from "@/lib/content";

const CHOICE_LABELS = ["ア", "イ", "ウ", "エ", "オ", "カ"];

export function QuestionCard({ question }: { question: Question }) {
  // 既定は「答えを見せる」状態（＝閲覧モード。静的HTMLに解説が載るのでSEOに効く）。
  // 「自分で解く」を押すと答えを隠して演習モードに切り替える。
  const [revealed, setRevealed] = useState(true);
  const [selected, setSelected] = useState<number | null>(null);

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
      "flex w-full items-start gap-3 rounded-xl border p-3 text-left transition-colors";
    if (!revealed) {
      return `${base} border-slate-200 bg-white hover:border-slate-300 hover:bg-slate-50`;
    }
    if (index === question.correct) {
      return `${base} border-green-500 bg-green-50`;
    }
    if (index === selected) {
      return `${base} border-red-400 bg-red-50`;
    }
    return `${base} border-slate-200 bg-white opacity-70`;
  };

  const isCorrect = selected !== null && selected === question.correct;
  const images = question.images ?? [];

  return (
    <div className="flex flex-col gap-5">
      {/* 問題文 */}
      <div className="whitespace-pre-wrap text-[15px] leading-relaxed text-slate-800">
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
              className="max-w-full rounded-lg border border-slate-200"
            />
          ))}
        </div>
      )}

      {/* 選択肢 */}
      <div className="flex flex-col gap-2">
        {question.choices.map((choice, index) => (
          <button
            key={index}
            type="button"
            onClick={() => choose(index)}
            disabled={revealed}
            className={choiceClass(index)}
          >
            <span className="mt-0.5 flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-slate-100 text-xs font-bold text-slate-600">
              {CHOICE_LABELS[index] ?? index + 1}
            </span>
            <span className="whitespace-pre-wrap text-[15px] leading-relaxed">
              {choice}
            </span>
          </button>
        ))}
      </div>

      {/* 操作 / 結果 */}
      {revealed ? (
        <div className="flex flex-col gap-4">
          {selected !== null && (
            <p
              className={`text-sm font-bold ${
                isCorrect ? "text-green-600" : "text-red-500"
              }`}
            >
              {isCorrect ? "正解！" : "不正解"}
            </p>
          )}
          <div className="rounded-xl bg-slate-100 p-4">
            <p className="text-sm font-semibold text-slate-700">
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
            className="inline-flex w-fit items-center rounded-lg border border-slate-300 bg-white px-4 py-2 text-sm font-semibold text-slate-700 transition-colors hover:bg-slate-50"
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
