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

import re
import shlex
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


# S3 同期の形を検証する対象。web だけでなく portal / admin も同じ手順に揃えている。
# ここに列挙したものだけが検査される（自動検出だと黙って対象から外れるため）。
SYNC_WORKFLOWS = [
    "deploy-web-dev.yml",
    "deploy-web-prod.yml",
    "deploy-portal-dev.yml",
    "deploy-portal-prod.yml",
    "deploy-admin-frontend-dev.yml",
    "deploy-admin-frontend-prod.yml",
]


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


# `aws s3 sync` で値を伴うオプション。位置引数（source / destination）を拾うときに
# オプションの値を取り違えないよう、ここに列挙したものは次のトークンごと読み飛ばす。
S3_SYNC_VALUE_FLAGS = {
    "--exclude", "--include", "--cache-control", "--content-type", "--acl",
    "--metadata", "--metadata-directive", "--sse", "--storage-class", "--profile",
    "--region", "--endpoint-url",
}


def s3_sync_commands(workflow: dict) -> list[str]:
    """ワークフロー全体の `aws s3 sync` 呼び出しを、現れる順にすべて返す。

    最初の step で打ち切らない。打ち切ると、後続の step に余計な sync
    （`--cache-control` 付きや、バケット全体を消すもの）を足しても検出できない。
    """
    commands = []
    for job in (workflow.get("jobs") or {}).values():
        for step in job.get("steps") or []:
            run = str(step.get("run", ""))
            if "aws s3 sync" not in run:
                continue
            # 行継続（\）をつないでから 1 呼び出し 1 行にする。
            joined = run.replace("\\\n", " ")
            commands += [
                line for line in joined.splitlines()
                if "aws s3 sync" in line and not line.strip().startswith("#")
            ]
    return commands


def s3_sync_operands(cmd: str) -> list[str]:
    """sync コマンドの位置引数（source, destination）を返す。

    `${{ matrix.bucket }}` は中に空白を含むので、shlex に渡す前に潰しておく。
    バケット名そのものは環境ごとに違うため、ここでは比較可能な形にするだけでよい。
    """
    normalized = re.sub(r"\$\{\{[^}]*\}\}", "EXPR", cmd)
    tokens = shlex.split(normalized)
    tokens = tokens[tokens.index("sync") + 1:]

    operands, skip = [], False
    for token in tokens:
        if skip:
            skip = False
        elif token.startswith("-"):
            skip = token in S3_SYNC_VALUE_FLAGS
        else:
            operands.append(token)
    return operands


def check_s3_sync(path: Path, workflow: dict) -> list[str]:
    """S3 同期が「チャンク保持」の形になっているかを検証する（#336 / #342）。

    Cache-Control は CloudFront の ResponseHeadersPolicy で付ける
    （terraform/environments/*/frontend_cache.tf）。`aws s3 sync --cache-control` は
    「ローカルの方が新しい/サイズが違う」ファイルしか転送しない性質のせいで、対象が
    重なると 2 本目がスキップされて値が付かなかった（#336 の実害）。デプロイ手順に
    戻さないよう、ここで禁止する。

    sync を 2 本に分ける理由は --delete の適用範囲だけ。ハッシュ付きチャンクを
    --delete 無しで先に上げ、HTML 等の削除対象からも外すことで、デプロイ前から
    開いている画面が旧チャンクを取得できる（#342）。

    source / destination も検証する。フラグだけ合っていても転送元・転送先を間違えれば
    壊れるため（例: `aws s3 sync out/ s3://bucket/_next/static/` はサイト全体を
    チャンク階層へ流し込む）。
    """
    syncs = s3_sync_commands(workflow)
    if not syncs:
        return [f"{path.name}: s3 sync する step が見つからない"]
    if len(syncs) != 2:
        return [
            f"{path.name}: s3 sync が {len(syncs)} 回（期待値: 2 回。チャンク用と HTML 用）"
            "\n    " + "\n    ".join(c.strip() for c in syncs)
        ]

    chunks, rest = syncs
    errors = []

    for cmd in syncs:
        if "--cache-control" in cmd:
            errors.append(
                f"{path.name}: s3 sync に --cache-control がある"
                "（Cache-Control は CloudFront の ResponseHeadersPolicy で付ける）"
            )
            break

    if "--delete" in chunks:
        errors.append(f"{path.name}: チャンクの sync に --delete がある（旧チャンクが即削除される）")
    if "--delete" not in rest:
        errors.append(f"{path.name}: HTML 等の sync に --delete が無い（stale が消えない）")
    if '--exclude "_next/static/*"' not in rest:
        errors.append(f"{path.name}: HTML 等の sync が _next/static を除外していない（旧チャンクが消える）")

    # source / destination。1 本目は必ず _next/static/ 階層どうしで、2 本目はその親どうし。
    # 「親を剥がすと一致する」ことを見るので、バケット名の取り違えも同時に弾ける。
    chunk_operands = s3_sync_operands(chunks)
    rest_operands = s3_sync_operands(rest)

    if len(chunk_operands) != 2 or len(rest_operands) != 2:
        errors.append(
            f"{path.name}: sync の位置引数が source / destination の 2 つになっていない"
            f"（チャンク: {chunk_operands}、HTML 等: {rest_operands}）"
        )
        return errors

    suffix = "_next/static/"
    chunk_src, chunk_dst = chunk_operands
    rest_src, rest_dst = rest_operands

    if not chunk_src.endswith("/" + suffix) or not chunk_dst.endswith("/" + suffix):
        errors.append(
            f"{path.name}: 1 本目が _next/static/ どうしの同期になっていない"
            f"（{chunk_src} → {chunk_dst}）"
        )
    elif rest_src != chunk_src[: -len(suffix)] or rest_dst != chunk_dst[: -len(suffix)]:
        errors.append(
            f"{path.name}: 2 本目の source / destination が 1 本目の親になっていない"
            f"（期待値: {chunk_src[: -len(suffix)]} → {chunk_dst[: -len(suffix)]}、"
            f"実際: {rest_src} → {rest_dst}）"
        )

    if not chunk_dst.startswith("s3://") or not rest_dst.startswith("s3://"):
        errors.append(f"{path.name}: destination が s3:// になっていない（{chunk_dst} / {rest_dst}）")

    return errors


def check_ref_validation(path: Path, job: dict | None, env_name: str) -> list[str]:
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

    # prod のロールバック先は「本番へ出した実績のある commit」に限る。
    # main 履歴上でも未デプロイの commit は動作実績が無い。
    if env_name == "prod":
        validate_run = str(steps[validate_at].get("run", ""))
        if "--points-at" not in validate_run or "web-prod/" not in validate_run:
            errors.append(
                f"{path.name}: ロールバック先を web-prod/* タグの付いた commit に限定していない"
            )
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
    errors += check_ref_validation(path, job, env_name)

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

    for name in SYNC_WORKFLOWS:
        path = WORKFLOWS / name
        if not path.exists():
            errors.append(f"{name}: ワークフローが見つからない（SYNC_WORKFLOWS に列挙されている）")
            continue
        try:
            workflow = yaml.safe_load(path.read_text(encoding="utf-8"))
        except yaml.YAMLError as e:
            errors.append(f"{name}: YAML を解析できない: {e}")
            continue
        found = check_s3_sync(path, workflow)
        errors.extend(found)
        if not found:
            print(f"OK: {name} (s3 sync)")

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
