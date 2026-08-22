#!/usr/bin/env bash
#
# メールログイン（#283）の E2E を dev バックエンドに対して実行する。
#
# 各ケースの前にアプリをアンインストールして「新しい端末」の前提を作る。
# XCUITest 単体ではアンインストールできないため、ここで明示的に行う。
#
# 使い方:
#   RIKAKO_E2E_EMAIL=... RIKAKO_E2E_PASSWORD=... ./scripts/run-account-e2e.sh [device-udid]
#
# 注意: CODE_SIGNING_ALLOWED=NO は付けないこと。署名なしビルドは Keychain が
# 使えず（SecItemCopyMatching -34018）、トークンが保存されないため
# 「再起動でログアウトされる」という偽陽性になる。
set -euo pipefail

if [[ -z "${RIKAKO_E2E_EMAIL:-}" || -z "${RIKAKO_E2E_PASSWORD:-}" ]]; then
  echo "RIKAKO_E2E_EMAIL と RIKAKO_E2E_PASSWORD を設定してください" >&2
  exit 1
fi

DEVICE="${1:-}"
if [[ -z "$DEVICE" ]]; then
  DEVICE=$(xcrun simctl list devices available --json \
    | python3 -c 'import json,sys
d=json.load(sys.stdin)["devices"]
for runtime, devices in sorted(d.items()):
    for dev in devices:
        if dev["name"].startswith("iPhone"):
            print(dev["udid"]); raise SystemExit')
fi

BUNDLE_ID="org.rikako.chemist.dev"
SCHEME="high-school-chemistry-dev"
CONFIG="HighSchoolChemistryDev Debug"
cd "$(dirname "$0")/.."

run_case() {
  local test_id="$1"
  echo "=== $test_id"
  # 新しい端末の前提を作る（UserDefaults を空にする）
  xcrun simctl uninstall "$DEVICE" "$BUNDLE_ID" >/dev/null 2>&1 || true

  TEST_RUNNER_RIKAKO_E2E_EMAIL="$RIKAKO_E2E_EMAIL" \
  TEST_RUNNER_RIKAKO_E2E_PASSWORD="$RIKAKO_E2E_PASSWORD" \
  xcodebuild test \
    -scheme "$SCHEME" \
    -destination "platform=iOS Simulator,id=$DEVICE" \
    -configuration "$CONFIG" \
    -only-testing:"RikakoUITests/AccountLinkE2ETests/$test_id"
}

run_case "test_匿名で解いた回答がログイン時にアカウントへマージされる"
run_case "test_新しい端末でもログインすれば学習記録が戻る"

echo "=== E2E 完了"
