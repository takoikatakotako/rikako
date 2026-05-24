import http from 'k6/http';
import { check } from 'k6';
import { loadWorkbook } from '../lib/setup.js';

const API_BASE_URL = __ENV.API_BASE_URL || 'https://api.dev.rikako.org';
const RATE = parseInt(__ENV.RATE || '20');
const DURATION = __ENV.DURATION || '2m';
const ANSWERS_PER_REQUEST = parseInt(__ENV.ANSWERS_PER_REQUEST || '3');

export const options = {
  scenarios: {
    answers: {
      executor: 'constant-arrival-rate',
      rate: RATE,
      timeUnit: '1s',
      duration: DURATION,
      preAllocatedVUs: 40,
      maxVUs: 200,
    },
  },
  thresholds: {
    http_req_duration: ['p(95)<1000'],
    http_req_failed: ['rate<0.01'],
  },
};

export function setup() {
  const data = loadWorkbook();
  console.log(`loaded workbook ${data.workbookId} with ${data.questions.length} questions`);
  return data;
}

export default function (data) {
  // 各 VU を1ユーザーとして扱う（device id を VU 単位で安定させる）
  const deviceID = `loadtest-vu-${__VU}`;

  const answers = [];
  for (let i = 0; i < ANSWERS_PER_REQUEST; i++) {
    const q = data.questions[Math.floor(Math.random() * data.questions.length)];
    answers.push({
      questionId: q.id,
      selectedChoice: Math.floor(Math.random() * q.choiceCount),
    });
  }

  const payload = JSON.stringify({
    workbookId: data.workbookId,
    answers,
  });

  const res = http.post(`${API_BASE_URL}/answers`, payload, {
    headers: {
      'Content-Type': 'application/json',
      'X-Device-ID': deviceID,
    },
  });

  check(res, {
    'status is 200': (r) => r.status === 200,
    'has correctCount': (r) => r.json('correctCount') !== undefined,
  });
}
