#!/usr/bin/env bash
# Firebase のクライアント設定ファイル（iOS の GoogleService-Info.plist / Android の
# google-services.json）を SSM Parameter Store と手元の間で出し入れする（#235）。
#
# これらは API キーを含むため git 管理外にしているが、秘密度は低い（アプリに同梱されて
# 配布される値）。SSM に置くのは「CI とローカルが同じ場所から取れる」ようにするため。
#
# パラメータ名（SecureString、手動 put。Terraform 管理外）:
#   /rikako/<environment>/firebase/ios/<app_slug>   … plist（app ごと）
#   /rikako/<environment>/firebase/android          … json（1 プロジェクト分に両アプリを含む）
#   <environment> は development / production
#
# 使い方:
#   scripts/firebase-config.sh pull dev            # dev の iOS plist 2 + Android json を配置
#   scripts/firebase-config.sh pull prod android   # prod の Android json だけ
#   scripts/firebase-config.sh pull all            # dev / prod 両方
#   scripts/firebase-config.sh push prod           # 手元のファイルを SSM へ登録（初回・更新時）
#
# 事前に AWS_PROFILE を設定して `aws sso login`（docs/aws-setup.md 参照）。
# CI では OIDC で assume したロールでそのまま動く。
set -euo pipefail

usage() {
  echo "usage: $0 <pull|push> <dev|prod|all> [ios|android|all]" >&2
  exit 2
}

action="${1:-}"
env_arg="${2:-}"
target="${3:-all}"
[[ "$action" == "pull" || "$action" == "push" ]] || usage
[[ "$env_arg" == "dev" || "$env_arg" == "prod" || "$env_arg" == "all" ]] || usage
[[ "$target" == "ios" || "$target" == "android" || "$target" == "all" ]] || usage

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
ios_dir="$repo_root/ios/Rikako/Firebase"
android_src="$repo_root/android/app/src"
region="${AWS_REGION:-ap-northeast-1}"

ios_slugs=(high-school-chemistry it-passport)

# env（dev/prod）→ SSM のパス（Terraform の local.environment に合わせる）
ssm_env() {
  case "$1" in
    dev) echo development ;;
    prod) echo production ;;
  esac
}

# Android は google-services プラグインの探索パスに合わせて app×env の変種ごとに置く。
# 1 プロジェクトの json は登録アプリを全部含むので、dev / prod それぞれ同じ内容でよい。
android_dirs() {
  case "$1" in
    dev) echo chemistryDev itPassportDev ;;
    prod) echo chemistryProd itPassportProd ;;
  esac
}

get_param() {
  aws ssm get-parameter --region "$region" --with-decryption \
    --name "$1" --query 'Parameter.Value' --output text
}

put_param() {
  # 値は 4KB（標準パラメータ）以内。超えると失敗するので advanced に切り替えるより
  # Firebase 側で不要なアプリ登録を減らす方を先に検討する。
  aws ssm put-parameter --region "$region" --type SecureString --overwrite \
    --name "$1" --value "file://$2" >/dev/null
}

pull_env() {
  local env="$1" senv
  senv="$(ssm_env "$env")"
  if [[ "$target" != "android" ]]; then
    mkdir -p "$ios_dir"
    for slug in "${ios_slugs[@]}"; do
      local out="$ios_dir/GoogleService-Info-$slug-$env.plist"
      get_param "/rikako/$senv/firebase/ios/$slug" > "$out"
      echo "wrote ${out#"$repo_root"/}"
    done
  fi
  if [[ "$target" != "ios" ]]; then
    local json
    json="$(get_param "/rikako/$senv/firebase/android")"
    for dir in $(android_dirs "$env"); do
      mkdir -p "$android_src/$dir"
      printf '%s\n' "$json" > "$android_src/$dir/google-services.json"
      echo "wrote android/app/src/$dir/google-services.json"
    done
  fi
}

push_env() {
  local env="$1" senv
  senv="$(ssm_env "$env")"
  if [[ "$target" != "android" ]]; then
    for slug in "${ios_slugs[@]}"; do
      local src="$ios_dir/GoogleService-Info-$slug-$env.plist"
      [[ -f "$src" ]] || { echo "missing: ${src#"$repo_root"/}" >&2; exit 1; }
      put_param "/rikako/$senv/firebase/ios/$slug" "$src"
      echo "pushed /rikako/$senv/firebase/ios/$slug"
    done
  fi
  if [[ "$target" != "ios" ]]; then
    # 変種ディレクトリのどれか 1 つにあればよい（中身は同じ前提）。
    local src=""
    for dir in $(android_dirs "$env"); do
      [[ -f "$android_src/$dir/google-services.json" ]] && { src="$android_src/$dir/google-services.json"; break; }
    done
    [[ -n "$src" ]] || { echo "missing: android/app/src/{$(android_dirs "$env" | tr ' ' ',')}/google-services.json" >&2; exit 1; }
    put_param "/rikako/$senv/firebase/android" "$src"
    echo "pushed /rikako/$senv/firebase/android"
  fi
}

envs=("$env_arg")
[[ "$env_arg" == "all" ]] && envs=(dev prod)
for env in "${envs[@]}"; do
  "${action}_env" "$env"
done
