import Link from "next/link";
import { getExamCategory } from "@/lib/content";

export default async function Home() {
  const category = await getExamCategory();

  return (
    <div className="flex flex-col gap-8">
      <section className="flex flex-col gap-3">
        <h1 className="text-2xl font-bold tracking-tight">
          ITパスポート過去問を無料で解く・見る
        </h1>
        <p className="text-slate-600 leading-relaxed">
          ITパスポート試験の公開問題（過去問）を、解説付きで解いたり見たりできます。
          会員登録は不要です。まずは試験回を選んでください。
        </p>
      </section>

      <section className="flex flex-col gap-3">
        <h2 className="text-lg font-semibold">試験回を選ぶ</h2>
        <ul className="flex flex-col gap-3">
          {category.workbooks.map((exam) => (
            <li key={exam.id}>
              <Link
                href={`/exams/${exam.id}/`}
                className="block rounded-xl border border-slate-200 bg-white p-4 transition-colors hover:border-slate-300 hover:bg-slate-50"
              >
                <div className="flex items-center justify-between gap-3">
                  <span className="font-semibold">{exam.title}</span>
                  <span className="shrink-0 rounded-full bg-slate-100 px-2.5 py-1 text-xs font-medium text-slate-600">
                    全{exam.questionCount}問
                  </span>
                </div>
                {exam.description && (
                  <p className="mt-1 text-sm text-slate-500">
                    {exam.description}
                  </p>
                )}
              </Link>
            </li>
          ))}
        </ul>
      </section>
    </div>
  );
}
