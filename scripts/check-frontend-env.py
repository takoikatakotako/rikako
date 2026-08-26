#!/usr/bin/env python3
"""フロントエンドの deploy ワークフローの Build step に、必要な env が揃っているかを検証する。

web/ は IT と化学で同じコードベースを共有しており（NEXT_PUBLIC_SITE で切替）、
片方のワークフローにだけ環境変数を足す抜けが起きやすい。抜けたままデプロイすると:

  - NEXT_PUBLIC_COGNITO_CLIENT_ID が空 → ログインが MissingClientId で失敗する
  - NEXT_PUBLIC_API_BASE_URL が未設定 → 既定値の dev API を向く
    （本番サイトが dev に書き込む）

ビルドも lint も通ってしまい、デプロイして初めて分かるため CI で止める。

ファイル全体の文字列一致ではなく **Build step の env を取り出して**判定する。
そうしないと、値が空・コメントに書いてあるだけ・別 step に置いてある、といった
「実際にはビルドへ渡らない」状態を見逃す。
"""
from __future__ import annotations

import sys
from pathlib import Path

try:
    import yaml
except ImportError:  # pragma: no cover
    print("PyYAML が必要です: python3 -m pip install pyyaml", file=sys.stderr)
    raise SystemExit(1)

ROOT = Path(__file__).resolve().parent.parent

REQUIRED = [
    "NEXT_PUBLIC_SITE",
    "NEXT_PUBLIC_CONTENT_BASE_URL",
    "NEXT_PUBLIC_API_BASE_URL",
    "NEXT_PUBLIC_COGNITO_REGION",
    "NEXT_PUBLIC_COGNITO_CLIENT_ID",
]

# 部分一致にしない。prod が別ホストを向く事故も拾いたい。
EXPECTED_API = {
    "dev": "https://api.dev.rikako.org",
    "prod": "https://api.rikako.org",
}


def build_env(workflow: dict) -> dict | None:
    """web/ をビルドする step の env を返す。該当 step が無ければ None。"""
    for job in (workflow.get("jobs") or {}).values():
        for step in job.get("steps") or []:
            wd = str(step.get("working-directory", "")).strip("./")
            run = str(step.get("run", ""))
            if wd == "web" and "npm run build" in run:
                return step.get("env") or {}
    return None


def check(path: Path) -> list[str]:
    """問題があればメッセージの一覧を返す。"""
    env_name = path.stem.rsplit("-", 1)[-1]  # dev / prod
    workflow = yaml.safe_load(path.read_text(encoding="utf-8"))

    env = build_env(workflow)
    if env is None:
        return [f"{path.name}: web/ をビルドする step が見つからない"]

    errors = []
    for key in REQUIRED:
        if key not in env:
            errors.append(f"{path.name}: Build step の env に {key} が無い")
        elif not str(env[key]).strip():
            errors.append(f"{path.name}: {key} が空")

    api = str(env.get("NEXT_PUBLIC_API_BASE_URL", "")).strip()
    expected = EXPECTED_API.get(env_name)
    if api and expected and api != expected:
        errors.append(f"{path.name}: NEXT_PUBLIC_API_BASE_URL が {api}（期待値: {expected}）")

    return errors


def targets(workflows_dir: Path) -> list[Path]:
    """web/ をビルドする deploy ワークフロー（管理画面は別アプリなので含まない）。"""
    found = []
    for path in sorted(workflows_dir.glob("deploy-*-frontend-*.yml")):
        try:
            workflow = yaml.safe_load(path.read_text(encoding="utf-8"))
        except yaml.YAMLError:
            continue
        if isinstance(workflow, dict) and build_env(workflow) is not None:
            found.append(path)
    return found


def main() -> int:
    paths = targets(ROOT / ".github/workflows")
    if not paths:
        print("web/ をビルドするワークフローが見つからない", file=sys.stderr)
        return 1

    errors = []
    for path in paths:
        found = check(path)
        errors.extend(found)
        if not found:
            print(f"OK: {path.name}")

    if errors:
        print("", file=sys.stderr)
        for e in errors:
            print(e, file=sys.stderr)
        print(
            "\nweb/ は IT と化学で同じコードを共有している。"
            "片方だけ直すとデプロイして初めて壊れが分かる。",
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
