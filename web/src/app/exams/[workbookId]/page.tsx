import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { ExamProgress } from "@/components/ExamProgress";
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
      </section>

      <ExamProgress
        workbookId={exam.id}
        questionIds={exam.questions.map((q) => q.id)}
      />
    </div>
  );
}
