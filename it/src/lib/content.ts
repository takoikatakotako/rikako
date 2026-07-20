// content.rikako.org/v1 の静的JSONを読む層。
// これは iOS アプリが読むのと同じソース（is_published=true の公開中の問題だけが配信される）。
// よって Web で見える問題 = アプリで公開中の問題、が常に一致する。

const CONTENT_BASE_URL =
  process.env.NEXT_PUBLIC_CONTENT_BASE_URL ?? "https://content.rikako.org/v1";

// ITパスポートのカテゴリID（content 上で固定）。it.rikako.org はこのカテゴリのみを扱う。
export const IT_CATEGORY_ID = 2;

export type Question = {
  id: number;
  type: string;
  text: string;
  choices: string[];
  correct: number; // 正解の選択肢インデックス
  explanation: string;
  images?: string[]; // 図が無い問題では省略される
};

export type WorkbookSummary = {
  id: number;
  title: string;
  description: string;
  questionCount: number;
  categoryId: number;
};

export type WorkbookDetail = {
  id: number;
  title: string;
  description: string;
  categoryId: number;
  questions: Question[];
};

export type CategoryDetail = {
  id: number;
  title: string;
  description: string;
  workbooks: WorkbookSummary[];
};

async function fetchJSON<T>(path: string): Promise<T> {
  const res = await fetch(`${CONTENT_BASE_URL}/${path}`);
  if (!res.ok) {
    throw new Error(`content fetch failed: ${path} (${res.status})`);
  }
  return res.json() as Promise<T>;
}

/** ITパスポートのカテゴリ（試験回=workbook の一覧を含む） */
export function getExamCategory(): Promise<CategoryDetail> {
  return fetchJSON<CategoryDetail>(`categories/${IT_CATEGORY_ID}.json`);
}

/** 試験回（workbook）の詳細（全問を含む） */
export function getExam(workbookId: number): Promise<WorkbookDetail> {
  return fetchJSON<WorkbookDetail>(`workbooks/${workbookId}.json`);
}

/** 全試験回の詳細をまとめて取得 */
export async function getAllExams(): Promise<WorkbookDetail[]> {
  const category = await getExamCategory();
  return Promise.all(category.workbooks.map((w) => getExam(w.id)));
}

export type QuestionContext = {
  question: Question;
  exam: WorkbookDetail;
  index: number; // 0-based
  prevId: number | null;
  nextId: number | null;
};

/** 問題IDから、その問題・所属試験回・並び順・前後の問題を解決する */
export async function findQuestionContext(
  questionId: number,
): Promise<QuestionContext | null> {
  const exams = await getAllExams();
  for (const exam of exams) {
    const index = exam.questions.findIndex((q) => q.id === questionId);
    if (index !== -1) {
      return {
        question: exam.questions[index],
        exam,
        index,
        prevId: index > 0 ? exam.questions[index - 1].id : null,
        nextId:
          index < exam.questions.length - 1
            ? exam.questions[index + 1].id
            : null,
      };
    }
  }
  return null;
}
