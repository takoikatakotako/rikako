import http from 'k6/http';
import { check } from 'k6';
import { loadWorkbook } from '../lib/setup.js';

// docs/load-test.md「2. スパイク」のシナリオ実装。
// 0 → TARGET_RATE RPS を RAMP_DURATION で立ち上げ、SUSTAIN_DURATION 維持する。
// Lambda の cold start が大量発生する状況での挙動を確認する。
const API_BASE_URL = __ENV.API_BASE_URL || 'https://api.dev.rikako.org';
const TARGET_RATE = parseInt(__ENV.TARGET_RATE || '100');
const RAMP_DURATION = __ENV.RAMP_DURATION || '30s';
const SUSTAIN_DURATION = __ENV.SUSTAIN_DURATION || '2m';
const ANSWERS_PER_REQUEST = parseInt(__ENV.ANSWERS_PER_REQUEST || '3');

export const options = {
  scenarios: {
    spike: {
      executor: 'ramping-arrival-rate',
      startRate: 0,
      timeUnit: '1s',
      preAllocatedVUs: 100,
      maxVUs: 500,
      stages: [
        { target: TARGET_RATE, duration: RAMP_DURATION },
        { target: TARGET_RATE, duration: SUSTAIN_DURATION },
      ],
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
  const deviceID = `loadtest-spike-vu-${__VU}`;

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
