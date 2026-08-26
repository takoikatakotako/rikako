#!/usr/bin/env python3
"""フロントエンドの deploy ワークフローに必要な NEXT_PUBLIC_* が揃っているかを検証する。

web/ は IT と化学で同じコードベースを共有しており（NEXT_PUBLIC_SITE で切替）、
片方のワークフローにだけ環境変数を足すという抜けが起きやすい。抜けたままデプロイすると:

  - NEXT_PUBLIC_COGNITO_CLIENT_ID が空 → ログインが MissingClientId で失敗する
  - NEXT_PUBLIC_API_BASE_URL が未設定 → 既定値の dev API を向く
    （本番サイトが dev に書き込む）

ビルドも lint も通ってしまい、デプロイして初めて分かるため CI で止める。
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WORKFLOWS = ROOT / ".github/workflows"

REQUIRED = [
    "NEXT_PUBLIC_SITE",
    "NEXT_PUBLIC_CONTENT_BASE_URL",
    "NEXT_PUBLIC_API_BASE_URL",
    "NEXT_PUBLIC_COGNITO_REGION",
    "NEXT_PUBLIC_COGNITO_CLIENT_ID",
]

# 環境ごとに向き先が入れ替わっていないかも見る（prod が dev を向く事故を防ぐ）
EXPECTED_HOST = {"dev": "dev.rikako.org", "prod": "api.rikako.org"}


def main() -> int:
    # web/ をビルドするものだけが対象（管理画面は別アプリなので含めない）。
    targets = [
        p for p in sorted(WORKFLOWS.glob("deploy-*-frontend-*.yml"))
        if re.search(r"working-directory:\s*\.?/?web\s*$", p.read_text(encoding="utf-8"), re.M)
    ]
    if not targets:
        print("web/ をビルドするワークフローが見つからない", file=sys.stderr)
        return 1

    failed = False
    for path in targets:
        text = path.read_text(encoding="utf-8")
        env = path.stem.rsplit("-", 1)[-1]  # dev / prod

        missing = [k for k in REQUIRED if f"{k}:" not in text]
        if missing:
            failed = True
            print(f"{path.name}: 環境変数が足りない -> {', '.join(missing)}", file=sys.stderr)
            continue

        api = re.search(r"NEXT_PUBLIC_API_BASE_URL:\s*(\S+)", text)
        if api and env in EXPECTED_HOST:
            url = api.group(1)
            if env == "prod" and "dev." in url:
                failed = True
                print(f"{path.name}: prod なのに dev API を向いている -> {url}", file=sys.stderr)
            if env == "dev" and "dev." not in url:
                failed = True
                print(f"{path.name}: dev なのに dev API を向いていない -> {url}", file=sys.stderr)

        print(f"OK: {path.name}")

    if failed:
        print("\nweb/ は IT と化学で同じコードを共有している。片方だけ直すと"
              "デプロイして初めて壊れが分かる。", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
