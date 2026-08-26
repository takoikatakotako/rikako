#!/usr/bin/env python3
"""フロントエンドの deploy ワークフローの Build step の env を検証する。

web/ は IT と化学で同じコードベースを共有しており（NEXT_PUBLIC_SITE で切替）、
片方のワークフローにだけ環境変数を足す抜けや、dev/prod の値の取り違えが起きやすい。
どちらもビルドも lint も通ってしまい、デプロイして初めて分かるため CI で止める。

抜けたままデプロイすると:
  - NEXT_PUBLIC_COGNITO_CLIENT_ID が空/取り違え → ログインが失敗する
  - NEXT_PUBLIC_API_BASE_URL が未設定/取り違え → 本番サイトが dev に書き込む

**対象は下の EXPECTED に明示的に列挙する。** 自動検出だと、working-directory の誤記や
Build step の削除で対象から黙って外れ、CI が成功してしまう。

it / chemistry は 1 つのワークフロー内で matrix により両方ビルドするため、
「matrix に両サイトが含まれること」も検証する（片方だけ出る状態を防ぐ）。
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
WORKFLOWS = ROOT / ".github/workflows"

# 検査対象と、Build step の env に期待する値（すべて完全一致で確認する）。
# 新しいサイトを追加したらここにも足す。
SITES = {"it", "chemistry"}

EXPECTED: dict[str, dict[str, str]] = {
    "deploy-web-dev.yml": {
        "NEXT_PUBLIC_SITE": "${{ matrix.site }}",
        "NEXT_PUBLIC_CONTENT_BASE_URL": "https://content.dev.rikako.org/v1",
        "NEXT_PUBLIC_API_BASE_URL": "https://api.dev.rikako.org",
        "NEXT_PUBLIC_COGNITO_REGION": "ap-northeast-1",
        "NEXT_PUBLIC_COGNITO_CLIENT_ID": "2buo6t5fbneujoknvrdph8flda",
    },
    "deploy-web-prod.yml": {
        "NEXT_PUBLIC_SITE": "${{ matrix.site }}",
        "NEXT_PUBLIC_CONTENT_BASE_URL": "https://content.rikako.org/v1",
        "NEXT_PUBLIC_API_BASE_URL": "https://api.rikako.org",
        "NEXT_PUBLIC_COGNITO_REGION": "ap-northeast-1",
        "NEXT_PUBLIC_COGNITO_CLIENT_ID": "4sqsett62vuckqt68d72nf2083",
    },
}


# トリガーも IT / 化学で揃える。片方だけ自動デプロイ、という非対称は事故のもと。
#   dev  : main への push（web/** と自ファイル）＋ 手動
#   prod : 手動のみ
EXPECTED_TRIGGERS = {"dev": {"push", "workflow_dispatch"}, "prod": {"workflow_dispatch"}}

# prod は承認を通してから反映する（Terraform の Apply Terraform Prod と同じ方式）。
EXPECTED_ENVIRONMENT = {"dev": None, "prod": "production"}


def build_job(workflow: dict) -> dict | None:
    """web/ をビルドする job を返す。該当 job が無ければ None。"""
    for job in (workflow.get("jobs") or {}).values():
        for step in job.get("steps") or []:
            wd = str(step.get("working-directory", "")).strip("./")
            run = str(step.get("run", ""))
            if wd == "web" and "npm run build" in run:
                return job
    return None


def build_env(workflow: dict) -> dict | None:
    """web/ をビルドする step の env を返す。該当 step が無ければ None。"""
    job = build_job(workflow)
    if job is None:
        return None
    for step in job.get("steps") or []:
        wd = str(step.get("working-directory", "")).strip("./")
        if wd == "web" and "npm run build" in str(step.get("run", "")):
            return step.get("env") or {}
    return None


def check(path: Path, expected: dict[str, str]) -> list[str]:
    """問題があればメッセージの一覧を返す。"""
    if not path.exists():
        return [f"{path.name}: ワークフローが見つからない（EXPECTED に列挙されている）"]

    try:
        workflow = yaml.safe_load(path.read_text(encoding="utf-8"))
    except yaml.YAMLError as e:
        return [f"{path.name}: YAML を解析できない: {e}"]

    env = build_env(workflow)
    if env is None:
        # 自動検出方式だとここで黙って対象外になっていた。必ずエラーにする。
        return [f"{path.name}: web/ をビルドする step が見つからない"]

    errors = []

    job = build_job(workflow)

    # it / chemistry の両方が出ること。片方だけ古いまま残るのを防ぐ。
    matrix = ((job or {}).get("strategy") or {}).get("matrix") or {}
    sites = {str(e.get("site")) for e in (matrix.get("include") or [])}
    if sites != SITES:
        errors.append(f"{path.name}: matrix のサイトが {sorted(sites)}（期待値: {sorted(SITES)}）")

    # `on:` は YAML では True として読まれることがある（on/yes が真偽値扱いのため）。
    triggers = workflow.get("on") or workflow.get(True) or {}
    env_name = path.stem.rsplit("-", 1)[-1]
    want_triggers = EXPECTED_TRIGGERS.get(env_name)
    if want_triggers is not None and set(triggers) != want_triggers:
        errors.append(
            f"{path.name}: トリガーが {sorted(set(triggers))}（期待値: {sorted(want_triggers)}）"
        )

    want_env = EXPECTED_ENVIRONMENT.get(env_name)
    got_env = (job or {}).get("environment")
    if want_env != got_env:
        errors.append(
            f"{path.name}: environment が {got_env}（期待値: {want_env}）"
            + ("（prod は承認ゲートが必要）" if want_env else "")
        )

    for key, want in expected.items():
        if key not in env:
            errors.append(f"{path.name}: Build step の env に {key} が無い")
            continue
        got = str(env[key]).strip()
        if not got:
            errors.append(f"{path.name}: {key} が空")
        elif got != want:
            errors.append(f"{path.name}: {key} が {got}（期待値: {want}）")
    return errors


def main() -> int:
    errors = []
    for name, expected in EXPECTED.items():
        found = check(WORKFLOWS / name, expected)
        errors.extend(found)
        if not found:
            print(f"OK: {name}")

    if errors:
        print("", file=sys.stderr)
        for e in errors:
            print(e, file=sys.stderr)
        print(
            "\nweb/ は IT と化学で同じコードを共有している。片方だけ直したり "
            "dev/prod の値を取り違えたりすると、デプロイして初めて壊れが分かる。",
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
