// admin_spa_rewrite CloudFront Function の挙動テスト。
//
// コピーではなく、terraform ファイル内に実際にデプロイされる JS を抽出して評価する。
// これにより「テストは通るが本物は古い」という乖離を防ぐ。
//
// 実行: node --test terraform/tests/
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const __dirname = dirname(fileURLToPath(import.meta.url));
const DEV_TF = join(__dirname, "../environments/dev/admin_frontend.tf");
const PROD_TF = join(__dirname, "../environments/prod/admin_frontend.tf");

const TEST_CRED = "dGVzdDp0ZXN0"; // 任意のダミー Basic 認証値

// terraform ファイルから admin_spa_rewrite 関数の heredoc(JS) を抜き出す
function extractHandlerSource(tfPath) {
  const content = readFileSync(tfPath, "utf8");
  const afterResource = content.split(
    'resource "aws_cloudfront_function" "admin_spa_rewrite"',
  )[1];
  assert.ok(afterResource, `admin_spa_rewrite が ${tfPath} に見つからない`);
  const m = afterResource.match(/code\s*=\s*<<-EOF\n([\s\S]*?)\n\s*EOF/);
  assert.ok(m, `admin_spa_rewrite の code heredoc を抽出できない (${tfPath})`);
  return m[1];
}

// 抽出した JS を評価して handler 関数を得る（terraform 補間はダミー値に置換）
function loadHandler(tfPath) {
  const raw = extractHandlerSource(tfPath).replaceAll(
    "${local.admin_basic_auth_credentials}",
    TEST_CRED,
  );
  // eslint-disable-next-line no-new-func
  return new Function(`${raw}\nreturn handler;`)();
}

function authedEvent(uri) {
  return {
    request: {
      uri,
      headers: { authorization: { value: `Basic ${TEST_CRED}` } },
    },
  };
}

const handler = loadHandler(DEV_TF);

test("認証情報が無ければ 401 を返す", () => {
  const res = handler({ request: { uri: "/questions/668/", headers: {} } });
  assert.equal(res.statusCode, 401);
});

test("認証情報が誤っていれば 401 を返す", () => {
  const res = handler({
    request: {
      uri: "/questions/668/",
      headers: { authorization: { value: "Basic WRONG" } },
    },
  });
  assert.equal(res.statusCode, 401);
});

// URI → リライト後 URI の期待表
const cases = [
  ["/", "/index.html"],
  ["/questions", "/questions/index.html"],
  ["/questions/", "/questions/index.html"],
  ["/questions/668", "/questions/index.html"], // 末尾スラッシュ無し（元々OK）
  ["/questions/668/", "/questions/index.html"], // 末尾スラッシュ有り（本修正の対象）
  ["/categories/1/", "/categories/index.html"],
  ["/workbooks/5", "/workbooks/index.html"],
];

for (const [input, expected] of cases) {
  test(`リライト: ${input} -> ${expected}`, () => {
    const req = handler(authedEvent(input));
    assert.equal(req.uri, expected);
  });
}

// 拡張子付き（静的アセット）はリライトしない
for (const asset of ["/_next/static/chunk.js", "/favicon.ico", "/index.html"]) {
  test(`静的アセットは素通し: ${asset}`, () => {
    const req = handler(authedEvent(asset));
    assert.equal(req.uri, asset);
  });
}

test("dev と prod の admin_spa_rewrite は完全一致（環境間ドリフト防止）", () => {
  assert.equal(
    extractHandlerSource(DEV_TF),
    extractHandlerSource(PROD_TF),
    "dev と prod の admin_spa_rewrite 関数が乖離している",
  );
});
