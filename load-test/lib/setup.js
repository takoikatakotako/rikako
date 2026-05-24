import http from 'k6/http';

const CONTENT_BASE_URL = __ENV.CONTENT_BASE_URL || 'https://content.dev.rikako.org/v1';
// 令和7年度 ITパスポート（100問）。大きすぎず実データが揃っていてバランス良い。
const WORKBOOK_ID = parseInt(__ENV.WORKBOOK_ID || '3');

export function loadWorkbook() {
  const res = http.get(`${CONTENT_BASE_URL}/workbooks/${WORKBOOK_ID}.json`);
  if (res.status !== 200) {
    throw new Error(`failed to fetch workbook ${WORKBOOK_ID}: status ${res.status}`);
  }
  const wb = res.json();
  return {
    workbookId: wb.id,
    questions: wb.questions.map((q) => ({
      id: q.id,
      choiceCount: q.choices.length,
    })),
  };
}
