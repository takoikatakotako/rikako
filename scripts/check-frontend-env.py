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
# 配信先の完全な組。site だけを見ていると、bucket / alias の取り違えが素通りする。
# 特に bucket の取り違えは、片方の成果物をもう片方の本番バケットへ `--delete` 付きで
# 同期するため、両サイトを同時に壊す。
EXPECTED_MATRIX: dict[str, list[tuple[str, str, str]]] = {
    "dev": [
        ("it", "rikako-it-development", "it.dev.rikako.org"),
        ("chemistry", "rikako-chemistry-development", "chemistry.dev.rikako.org"),
    ],
    "prod": [
        ("it", "rikako-it-production", "it.rikako.org"),
        ("chemistry", "rikako-chemistry-production", "chemistry.rikako.org"),
    ],
}

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


def check_matrix(path: Path, job: dict | None, env_name: str) -> list[str]:
    """matrix の include が期待どおりの配信先の組であることを検証する。

    site / bucket / alias を**組**で比較する。集合ではなく件数も見るのは、
    同じ site の entry が重複していても集合比較では消えてしまうため。
    """
    want = EXPECTED_MATRIX[env_name]
    include = (((job or {}).get("strategy") or {}).get("matrix") or {}).get("include") or []
    got = [(str(e.get("site")), str(e.get("bucket")), str(e.get("alias"))) for e in include]

    if len(got) != len(want):
        return [f"{path.name}: matrix の entry が {len(got)} 件（期待値: {len(want)} 件）: {got}"]
    if sorted(got) != sorted(want):
        return [
            f"{path.name}: matrix の配信先が期待値と違う\n"
            f"    実際  : {sorted(got)}\n"
            f"    期待値: {sorted(want)}"
        ]
    return []


def check_cache_control(path: Path, job: dict | None) -> list[str]:
    """S3 同期の cache-control が実際に効く形になっているかを検証する（#336）。

    aws s3 sync は差分のあるファイルしか転送しないため、「全同期してから
    cache-control を上書き」という書き方だと 2 本目がスキップされて効かない。
    実際 it.rikako.org のハッシュ付きチャンクは immutable 指定にもかかわらず
    max-age=0 で配信されていた。対象が重ならないように分けることを強制する。
    """
    for step in (job or {}).get("steps") or []:
        run = str(step.get("run", ""))
        if "aws s3 sync" not in run:
            continue

        errors = []
        # 各 sync 呼び出しを、行継続（\）をつないでから取り出す。
        joined = run.replace("\\\n", " ")
        syncs = [
            line for line in joined.splitlines()
            if "aws s3 sync" in line and not line.strip().startswith("#")
        ]

        if len(syncs) != 2:
            return [f"{path.name}: s3 sync が {len(syncs)} 回（期待値: 2 回。長期キャッシュ用と再検証用）"]

        immutable = [c for c in syncs if "immutable" in c]
        revalidate = [c for c in syncs if "must-revalidate" in c]
        if len(immutable) != 1 or len(revalidate) != 1:
            errors.append(f"{path.name}: immutable / must-revalidate の sync が 1 本ずつになっていない")
            return errors

        for cmd in syncs:
            if "--delete" not in cmd:
                errors.append(f"{path.name}: --delete の無い s3 sync がある（stale が消えない）")

        # ハッシュ名が付くのは _next/static のみ。public/ の画像などを immutable に
        # すると、内容を変えても URL が同じままで更新が届かなくなる。
        if '--include "_next/static/*"' not in immutable[0] or '--exclude "*"' not in immutable[0]:
            errors.append(f'{path.name}: immutable の sync は --exclude "*" --include "_next/static/*" に絞ること')
        if '--exclude "_next/static/*"' not in revalidate[0]:
            errors.append(f'{path.name}: must-revalidate の sync が _next/static を除外していない（対象が重なると後勝ちにならず効かない）')

        return errors

    return [f"{path.name}: s3 sync する step が見つからない"]


def check_ref_validation(path: Path, job: dict | None) -> list[str]:
    """checkout_ref の検証が、依存インストールより前に行われることを確認する。

    workflow_dispatch の checkout_ref はそのまま actions/checkout に渡るため、
    branch を指定すれば未マージのコードを実行できてしまう。prod の job は
    environment: production と id-token: write を持つので、npm ci の
    lifecycle script が走る前に main 履歴上の commit SHA だけに絞る必要がある。
    """
    steps = (job or {}).get("steps") or []
    errors = []

    validate_at = None
    install_at = None
    for i, step in enumerate(steps):
        run = str(step.get("run", ""))
        if validate_at is None and "merge-base --is-ancestor" in run:
            validate_at = i
            if "[0-9a-fA-F]{40}" not in run:
                errors.append(f"{path.name}: checkout_ref を 40 桁の SHA に制限していない")
            # expression を run へ直書きするとシェル入力になる。env 経由で渡すこと。
            if "${{" in run:
                errors.append(f"{path.name}: 検証 step の run に expression を直書きしている")
        if install_at is None and "npm ci" in run:
            install_at = i

    if validate_at is None:
        return [f"{path.name}: checkout_ref が main 履歴上の commit か検証していない"]
    if install_at is not None and validate_at > install_at:
        errors.append(f"{path.name}: checkout_ref の検証が npm ci より後になっている")

    for step in steps:
        if str(step.get("uses", "")).startswith("actions/checkout"):
            if (step.get("with") or {}).get("fetch-depth") != 0:
                errors.append(f"{path.name}: checkout の fetch-depth が 0 でない（祖先チェックに履歴が要る）")
            break

    return errors


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
    env_name = path.stem.rsplit("-", 1)[-1]

    errors += check_matrix(path, job, env_name)
    errors += check_ref_validation(path, job)
    errors += check_cache_control(path, job)

    # `on:` は YAML では True として読まれることがある（on/yes が真偽値扱いのため）。
    triggers = workflow.get("on") or workflow.get(True) or {}
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
