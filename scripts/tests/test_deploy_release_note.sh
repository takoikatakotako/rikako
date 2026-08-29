#!/usr/bin/env bash
# deploy-release-note アクションの挙動を、実際の git リポジトリに対して検証する。
#
# 重要なのは「デプロイ記録（タグ）は毎回作る」「Release は前回から新規コミットが
# ある時だけ作る」の2点が分かれていること。ここを一緒にすると、過去コミットへ
# ロールバックしたあとも最新タグが戻す前を指し続ける（#341 のレビュー指摘）。
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ACTION="$REPO_ROOT/.github/actions/deploy-release-note/action.yml"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

# アクションの run スクリプトを取り出す
python3 - "$ACTION" "$WORKDIR/action.sh" <<'PY'
import sys, yaml
action = yaml.safe_load(open(sys.argv[1]))
open(sys.argv[2], "w").write(action["runs"]["steps"][0]["run"])
PY

# gh はスタブ。呼ばれた引数を記録するだけ。
mkdir -p "$WORKDIR/bin"
cat > "$WORKDIR/bin/gh" <<'EOF'
#!/usr/bin/env bash
echo "$@" >> "$GH_CALLS"
EOF
chmod +x "$WORKDIR/bin/gh"
export PATH="$WORKDIR/bin:$PATH"
export GH_CALLS="$WORKDIR/gh-calls.txt"
export GH_TOKEN=dummy PREFIX=test-prod TITLE="Test Prod"

git init -q --bare "$WORKDIR/origin.git"
git init -q "$WORKDIR/repo"
cd "$WORKDIR/repo"
git config user.email t@example.com
git config user.name tester
git remote add origin "$WORKDIR/origin.git"

commit() { echo "$1" > f.txt; git add f.txt; git commit -qm "$1"; }
commit A; A=$(git rev-parse HEAD)
commit B; B=$(git rev-parse HEAD)
git push -q origin HEAD:refs/heads/main

run_action() { : > "$GH_CALLS"; bash "$WORKDIR/action.sh" > "$WORKDIR/out.txt" 2>&1 || { cat "$WORKDIR/out.txt"; return 1; }; }
latest_tag() { git tag -l "${PREFIX}/*" --sort=-refname | head -1; }
fail() { echo "FAIL: $1"; exit 1; }

# --- 1) 初回デプロイ: タグと Release（固定文）が作られる
run_action
[ "$(git tag -l "${PREFIX}/*" | wc -l)" -eq 1 ] || fail "初回でタグが作られていない"
grep -q "release create" "$GH_CALLS" || fail "初回で Release が作られていない"
grep -q "notes-start-tag" "$GH_CALLS" && fail "初回は前タグが無いのに notes-start-tag が付いている"
FIRST_TAG=$(latest_tag)
echo "ok: 初回デプロイ ($FIRST_TAG)"

sleep 1  # タグ名が秒単位なので重複を避ける

# --- 2) 新しいコミットを積んで再デプロイ: タグ + Release（前タグ起点）
commit C; C=$(git rev-parse HEAD)
run_action
[ "$(git tag -l "${PREFIX}/*" | wc -l)" -eq 2 ] || fail "通常更新でタグが増えていない"
grep -q "notes-start-tag $FIRST_TAG" "$GH_CALLS" || fail "前タグ起点の Release になっていない"
[ "$(git rev-list -n1 "$(latest_tag)")" = "$C" ] || fail "最新タグが最新コミットを指していない"
SECOND_TAG=$(latest_tag)
echo "ok: 通常更新 ($SECOND_TAG)"

sleep 1

# --- 3) 同一コミットの再デプロイ: タグは増えるが Release は作らない
run_action
[ "$(git tag -l "${PREFIX}/*" | wc -l)" -eq 3 ] || fail "同一コミット再デプロイでタグが作られていない"
grep -q "release create" "$GH_CALLS" && fail "同一コミット再デプロイで Release が作られている"
[ "$(git rev-list -n1 "$(latest_tag)")" = "$C" ] || fail "最新タグの指すコミットが違う"
echo "ok: 同一コミット再デプロイ（タグのみ）"

sleep 1

# --- 4) 過去コミットへロールバック: タグは A を指し、Release は作らない
git checkout -q "$A"
run_action
grep -q "release create" "$GH_CALLS" && fail "ロールバックで Release が作られている"
[ "$(git rev-list -n1 "$(latest_tag)")" = "$A" ] || fail "ロールバック後の最新タグが戻し先を指していない"
echo "ok: ロールバック（最新タグが戻し先 $A を指す）"

# --- 5) タグは origin にも push されている
[ "$(git ls-remote --tags origin | grep -c "${PREFIX}/")" -eq 4 ] || fail "タグが origin に push されていない"
echo "ok: タグが origin に push されている"

echo "PASS: deploy-release-note"
