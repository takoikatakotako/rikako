import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { QuestionCard } from "@/components/QuestionCard";
import { findQuestionContext, getAllExams } from "@/lib/content";

type Params = { questionId: string };

export async function generateStaticParams() {
  const exams = await getAllExams();
  return exams.flatMap((exam) =>
    exam.questions.map((q) => ({ questionId: String(q.id) })),
  );
}

export async function generateMetadata({
  params,
}: {
  params: Promise<Params>;
}): Promise<Metadata> {
  const { questionId } = await params;
  const ctx = await findQuestionContext(Number(questionId));
  if (!ctx) return {};
  const title = `${ctx.exam.title} 問${ctx.index + 1}`;
  const snippet = ctx.question.text.replace(/\s+/g, " ").slice(0, 100);
  return {
    title,
    description: `${title}：${snippet} 解答・解説付き。`,
  };
}

export default async function QuestionPage({
  params,
}: {
  params: Promise<Params>;
}) {
  const { questionId } = await params;
  const ctx = await findQuestionContext(Number(questionId));
  if (!ctx) notFound();

  const { question, exam, index, prevId, nextId } = ctx;
  const questionNo = index + 1;
  const total = exam.questions.length;

  return (
    <div className="flex flex-col gap-6">
      <nav className="text-sm text-slate-500">
        <Link href="/" className="hover:underline">
          トップ
        </Link>
        <span className="mx-1.5">/</span>
        <Link href={`/exams/${exam.id}/`} className="hover:underline">
          {exam.title}
        </Link>
        <span className="mx-1.5">/</span>
        <span className="text-slate-700">問{questionNo}</span>
      </nav>

      <article className="flex flex-col gap-5 rounded-2xl border border-slate-200 bg-white p-5">
        <div className="flex flex-col gap-2">
          <div className="flex items-baseline justify-between">
            <h1 className="text-lg font-bold tracking-tight">
              {exam.title} 問{questionNo}
            </h1>
            <span className="shrink-0 text-sm font-medium text-slate-500">
              問 {questionNo} / {total}
            </span>
          </div>
          <div
            className="h-1.5 w-full overflow-hidden rounded-full bg-slate-100"
            role="progressbar"
            aria-valuenow={questionNo}
            aria-valuemin={1}
            aria-valuemax={total}
          >
            <div
              className="h-full rounded-full bg-brand transition-all"
              style={{ width: `${(questionNo / total) * 100}%` }}
            />
          </div>
        </div>
        <QuestionCard
          workbookId={exam.id}
          question={question}
          nextHref={nextId !== null ? `/questions/${nextId}/` : null}
          backHref={`/exams/${exam.id}/`}
        />
      </article>

      <nav className="flex items-center justify-between gap-3">
        {prevId !== null ? (
          <Link
            href={`/questions/${prevId}/`}
            className="rounded-xl border border-slate-300 bg-white px-4 py-2 text-sm font-semibold transition-colors hover:border-brand hover:bg-brand-soft"
          >
            ← 前の問題
          </Link>
        ) : (
          <span />
        )}
        {nextId !== null ? (
          <Link
            href={`/questions/${nextId}/`}
            className="rounded-xl border border-slate-300 bg-white px-4 py-2 text-sm font-semibold transition-colors hover:border-brand hover:bg-brand-soft"
          >
            次の問題 →
          </Link>
        ) : (
          <Link
            href={`/exams/${exam.id}/`}
            className="rounded-xl border border-slate-300 bg-white px-4 py-2 text-sm font-semibold transition-colors hover:border-brand hover:bg-brand-soft"
          >
            一覧へ戻る
          </Link>
        )}
      </nav>
    </div>
  );
}
