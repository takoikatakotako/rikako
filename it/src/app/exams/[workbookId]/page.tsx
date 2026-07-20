import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { getExam, getExamCategory } from "@/lib/content";

type Params = { workbookId: string };

export async function generateStaticParams() {
  const category = await getExamCategory();
  return category.workbooks.map((w) => ({ workbookId: String(w.id) }));
}

export async function generateMetadata({
  params,
}: {
  params: Promise<Params>;
}): Promise<Metadata> {
  const { workbookId } = await params;
  const exam = await getExam(Number(workbookId));
  return {
    title: exam.title,
    description: `${exam.title}の全${exam.questions.length}問。解説付きで一覧・演習できます。`,
  };
}

export default async function ExamPage({
  params,
}: {
  params: Promise<Params>;
}) {
  const { workbookId } = await params;
  const id = Number(workbookId);
  if (!Number.isFinite(id)) notFound();
  const exam = await getExam(id);

  return (
    <div className="flex flex-col gap-6">
      <nav className="text-sm text-slate-500">
        <Link href="/" className="hover:underline">
          トップ
        </Link>
        <span className="mx-1.5">/</span>
        <span className="text-slate-700">{exam.title}</span>
      </nav>

      <section className="flex flex-col gap-2">
        <h1 className="text-xl font-bold tracking-tight">{exam.title}</h1>
        {exam.description && (
          <p className="text-slate-600">{exam.description}</p>
        )}
        {exam.questions.length > 0 && (
          <Link
            href={`/questions/${exam.questions[0].id}/`}
            className="mt-2 inline-flex w-fit items-center rounded-xl bg-brand px-5 py-2.5 text-sm font-bold text-white transition-colors hover:bg-brand-strong"
          >
            問1から順に見る
          </Link>
        )}
      </section>

      <section className="flex flex-col gap-2">
        <h2 className="text-lg font-semibold">問題一覧</h2>
        <ol className="grid grid-cols-[repeat(auto-fill,minmax(4rem,1fr))] gap-2">
          {exam.questions.map((q, i) => (
            <li key={q.id}>
              <Link
                href={`/questions/${q.id}/`}
                className="flex h-12 items-center justify-center rounded-xl border border-slate-200 bg-white text-sm font-semibold transition-colors hover:border-brand hover:bg-brand-soft hover:text-brand-strong"
              >
                問{i + 1}
              </Link>
            </li>
          ))}
        </ol>
      </section>
    </div>
  );
}
