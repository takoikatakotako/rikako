#!/usr/bin/env bash
# Android の Play 用アップロード鍵と Play Console サービスアカウントを SSM Parameter Store と
# 手元の間で出し入れする（#405）。scripts/firebase-config.sh と同じ型。
#
# SSM がマスター。`push` は SSM に登録すると同時に GitHub Secrets（deploy-android-prod.yml が
# 読む）にも同じ値を書くので、2 か所を手で同期する必要はない。`pull` は手元で署名付きビルドを
# 作るとき（初回の手動アップロード）に SSM から取る。
#
# パラメータ（すべて SecureString、prod アカウントのみ。名前は Terraform の ssm.tf で管理）:
#   /rikako/production/android/upload-keystore           … アップロード鍵の keystore（base64）
#   /rikako/production/android/upload-keystore-password  … keystore のパスワード
#   /rikako/production/android/upload-key-alias          … 鍵の alias
#   /rikako/production/android/upload-key-password       … 鍵のパスワード
#   /rikako/production/android/play-service-account     … Play Developer API のサービスアカウント JSON
#
# 使い方:
#   scripts/android-signing.sh push <keystore.jks> [service-account.json]
#       keystore と（あれば）SA JSON を SSM と GitHub Secrets に登録する。パスワードと alias は
#       対話で入力（コマンドラインに残さない）。gh の認証（gh auth login）が必要。
#   eval "$(scripts/android-signing.sh pull [dir])"
#       keystore を <dir>（既定: $RUNNER_TEMP か mktemp）に復元し、Gradle が読む
#       ANDROID_KEYSTORE_FILE / ANDROID_KEYSTORE_PASSWORD / ANDROID_KEY_ALIAS / ANDROID_KEY_PASSWORD
#       の export 文を標準出力に出す（値はシングルクォートで囲む）。
#   scripts/android-signing.sh pull-service-account <path>
#       SA JSON を <path> に書き出す。
#
# 事前に AWS_PROFILE を prod のプロファイルにして `aws sso login`（docs/aws-setup.md 参照）。
# CI では OIDC で assume したロールでそのまま動く。
set -euo pipefail

usage() {
  echo "usage: $0 push <keystore.jks> [service-account.json]" >&2
  echo "       $0 pull [dir]            # eval \"\$(...)\" で環境変数に取り込む" >&2
  echo "       $0 pull-service-account <path>" >&2
  exit 2
}

region="${AWS_REGION:-ap-northeast-1}"
prefix="/rikako/production/android"
expected_account=211125415945

require_prod_account() {
  local actual
  actual="$(aws sts get-caller-identity --query Account --output text 2>/dev/null || true)"
  if [[ "$actual" != "$expected_account" ]]; then
    echo "error: prod は AWS アカウント $expected_account だが、現在の認証情報は ${actual:-取得失敗}" >&2
    echo "       prod 用のプロファイルで aws sso login してください" >&2
    exit 1
  fi
}

get_param() {
  aws ssm get-parameter --region "$region" --with-decryption \
    --name "$1" --query 'Parameter.Value' --output text
}

put_param_value() {
  aws ssm put-parameter --region "$region" --type SecureString --overwrite \
    --name "$1" --value "$2" >/dev/null
}

put_param_file() {
  aws ssm put-parameter --region "$region" --type SecureString --overwrite \
    --name "$1" --value "file://$2" >/dev/null
}

push() {
  local keystore="${1:-}" sa="${2:-}"
  [[ -n "$keystore" && -f "$keystore" ]] || usage
  require_prod_account

  # keytool で keystore とパスワードの組を先に検証する（間違った値を登録しない）。
  local store_pass alias key_pass
  read -r -s -p "keystore のパスワード: " store_pass; echo
  if ! keytool -list -keystore "$keystore" -storepass "$store_pass" >/dev/null 2>&1; then
    echo "error: keystore を開けません（パスワード違い？）" >&2; exit 1
  fi
  read -r -p "鍵の alias [key0]: " alias; alias="${alias:-key0}"
  if ! keytool -list -keystore "$keystore" -storepass "$store_pass" -alias "$alias" >/dev/null 2>&1; then
    echo "error: alias '$alias' が keystore にありません" >&2; exit 1
  fi
  # 鍵のパスワードは keytool では安く検証できない（間違っていれば Gradle の署名で失敗する）。
  # Android Studio / PKCS12 では keystore と同じにしてあることが多い。
  read -r -s -p "鍵のパスワード（keystore と同じなら空 Enter）: " key_pass; echo
  key_pass="${key_pass:-$store_pass}"

  if [[ -n "$sa" ]]; then
    [[ -f "$sa" ]] || { echo "missing: $sa" >&2; exit 1; }
    python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d.get("type")=="service_account", "not a service account JSON"' "$sa"
  fi
  command -v gh >/dev/null || { echo "error: gh が必要です（GitHub Secrets にも書くため）" >&2; exit 1; }
  gh auth status >/dev/null 2>&1 || { echo "error: gh auth login してください" >&2; exit 1; }

  local b64
  b64="$(base64 -i "$keystore" | tr -d '\n')"

  # 1) SSM（マスター）
  put_param_value "$prefix/upload-keystore" "$b64"
  put_param_value "$prefix/upload-keystore-password" "$store_pass"
  put_param_value "$prefix/upload-key-alias" "$alias"
  put_param_value "$prefix/upload-key-password" "$key_pass"
  [[ -n "$sa" ]] && put_param_file "$prefix/play-service-account" "$sa"
  echo "pushed to SSM: $prefix/*"

  # 2) GitHub Secrets（deploy-android-prod.yml が読む写し）。値は stdin で渡す（引数に出さない）
  local repo="${GH_REPO:-takoikatakotako/rikako}"
  printf '%s' "$b64"        | gh secret set ANDROID_KEYSTORE_BASE64   --repo "$repo"
  printf '%s' "$store_pass" | gh secret set ANDROID_KEYSTORE_PASSWORD --repo "$repo"
  printf '%s' "$alias"      | gh secret set ANDROID_KEY_ALIAS         --repo "$repo"
  printf '%s' "$key_pass"   | gh secret set ANDROID_KEY_PASSWORD      --repo "$repo"
  [[ -n "$sa" ]] && gh secret set PLAY_SERVICE_ACCOUNT_JSON --repo "$repo" < "$sa"
  echo "mirrored to GitHub Secrets: ANDROID_KEYSTORE_BASE64, ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_ALIAS, ANDROID_KEY_PASSWORD${sa:+, PLAY_SERVICE_ACCOUNT_JSON}"
}

pull() {
  local dir="${1:-${RUNNER_TEMP:-$(mktemp -d)}}"
  mkdir -p "$dir"
  local jks="$dir/upload.jks"
  get_param "$prefix/upload-keystore" | base64 -d > "$jks"
  chmod 600 "$jks"
  local store_pass alias key_pass
  store_pass="$(get_param "$prefix/upload-keystore-password")"
  alias="$(get_param "$prefix/upload-key-alias")"
  key_pass="$(get_param "$prefix/upload-key-password")"
  # 呼び出し側が eval する。printf %q でシェルに安全な形に引用する（記号入りパスワード対策）。
  printf 'export ANDROID_KEYSTORE_FILE=%q\n' "$jks"
  printf 'export ANDROID_KEYSTORE_PASSWORD=%q\n' "$store_pass"
  printf 'export ANDROID_KEY_ALIAS=%q\n' "$alias"
  printf 'export ANDROID_KEY_PASSWORD=%q\n' "$key_pass"
}

pull_service_account() {
  local out="${1:-}"
  [[ -n "$out" ]] || usage
  get_param "$prefix/play-service-account" > "$out"
  chmod 600 "$out"
  echo "wrote $out" >&2
}

case "${1:-}" in
  push) shift; push "$@" ;;
  pull) shift; pull "$@" ;;
  pull-service-account) shift; pull_service_account "$@" ;;
  *) usage ;;
esac
