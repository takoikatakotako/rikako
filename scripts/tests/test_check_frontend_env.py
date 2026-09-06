"""check-frontend-env.py が「実際にビルドへ渡らない env」「dev/prod の取り違え」を
検出できることを確かめる。

ガード自体が退行すると、守っているつもりで守れていない状態になるため。
標準ライブラリだけで動く（python3 -m unittest discover -s scripts/tests）。
"""
import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path

MODULE_PATH = Path(__file__).resolve().parent.parent / "check-frontend-env.py"
spec = importlib.util.spec_from_file_location("check_frontend_env", MODULE_PATH)
mod = importlib.util.module_from_spec(spec)
sys.modules["check_frontend_env"] = mod
spec.loader.exec_module(mod)

PROD = mod.EXPECTED["deploy-web-prod.yml"]
DEV = mod.EXPECTED["deploy-web-dev.yml"]


# 実ワークフローの検証 step 相当（run の中身だけ）。
VALID_REF_CHECK = ('[[ "$CHECKOUT_REF" =~ ^[0-9a-fA-F]{40}$ ]] && '
                   'git merge-base --is-ancestor "$CHECKOUT_REF" origin/main && '
                   'test -n "$(git tag --points-at "$CHECKOUT_REF" -l \'web-prod/*\')"')

# dev はデプロイ実績タグを要求しない（自由に出せてよい）。
DEV_REF_CHECK = ('[[ "$CHECKOUT_REF" =~ ^[0-9a-fA-F]{40}$ ]] && '
                 'git merge-base --is-ancestor "$CHECKOUT_REF" origin/main')


# 実ワークフローの S3 同期相当。チャンクを --delete 無しで先に、HTML 等を --delete 付きで後に。
# Cache-Control は CloudFront の ResponseHeadersPolicy で付けるので sync では指定しない。
VALID_SYNC = """
aws s3 sync out/_next/static/ s3://bucket/_next/static/
aws s3 sync out/ s3://bucket/ --delete --exclude "_next/static/*"
"""


def workflow(env: dict, *, working_dir: str = "web", build_cmd: str = "npm run build",
             extra_step_env: dict | None = None, triggers: list | None = None,
             include: list | None = None, environment: str | None = "production",
             env_name: str = "prod", checkout: bool = True, fetch_depth: int = 0,
             validate: str | None = VALID_REF_CHECK, install: bool = True,
             sync: str | None = VALID_SYNC, extra_sync: str | None = None) -> str:
    """Build step の env に指定した値を持つワークフローを組み立てる。"""
    trigger_lines = ["on:"]
    for t in (triggers or ["workflow_dispatch"]):
        trigger_lines.append(f"  {t}:")
    lines = [
        "name: Deploy", *trigger_lines, "jobs:", "  deploy:",
        "    runs-on: ubuntu-latest",
    ]
    if environment:
        lines.append(f"    environment: {environment}")
    lines += ["    strategy:", "      matrix:", "        include:"]
    for site, bucket, alias in (include if include is not None
                                else mod.EXPECTED_MATRIX[env_name]):
        lines += [f"          - site: {site}", f"            bucket: {bucket}",
                  f"            alias: {alias}"]
    lines += ["    steps:"]
    if checkout:
        lines += ["      - uses: actions/checkout@v6", "        with:",
                  "          ref: ${{ inputs.checkout_ref || github.sha }}",
                  f"          fetch-depth: {fetch_depth}"]
    if validate:
        lines += ["      - name: Validate checkout ref", "        env:",
                  "          CHECKOUT_REF: ${{ inputs.checkout_ref || github.sha }}",
                  "        run: |", f"          {validate}"]
    if install:
        lines += ["      - name: Install", f"        working-directory: {working_dir}",
                  "        run: npm ci"]
    if sync is not None:
        lines += ["      - name: Deploy to S3", "        run: |"]
        lines += [f"          {l}" for l in sync.strip().splitlines()]
    if extra_sync is not None:
        lines += ["      - name: Deploy to S3 (extra)", "        run: |"]
        lines += [f"          {l}" for l in extra_sync.strip().splitlines()]
    lines += [
        "      - name: Build", f"        working-directory: {working_dir}",
        f"        run: {build_cmd}", "        env:",
    ]
    for k, v in env.items():
        value = '""' if v == "" else v
        lines.append(f"          {k}: {value}")
    if extra_step_env:
        lines += ["      - name: Deploy", "        run: echo deploy", "        env:"]
        for k, v in extra_step_env.items():
            lines.append(f"          {k}: {v}")
    return "\n".join(lines) + "\n"


class CheckFrontendEnvTest(unittest.TestCase):
    def run_check(self, content: str, expected: dict | None = None,
                  name: str = "deploy-web-prod.yml"):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / name
            path.write_text(content, encoding="utf-8")
            return mod.check(path, expected or PROD)

    def run_sync_check(self, content: str, name: str = "deploy-web-prod.yml"):
        import yaml
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / name
            path.write_text(content, encoding="utf-8")
            return mod.check_s3_sync(path, yaml.safe_load(content))

    # --- 正常系 ---

    def test_valid_workflow_passes(self):
        self.assertEqual(self.run_check(workflow(PROD)), [])

    def test_valid_dev_workflow_passes(self):
        self.assertEqual(
            self.run_check(workflow(DEV, triggers=["push", "workflow_dispatch"],
                                    environment=None, env_name="dev",
                                    validate=DEV_REF_CHECK),
                           DEV, "deploy-web-dev.yml"), [])

    def test_both_workflows_are_checked(self):
        """対象が黙って減らないこと。自動検出をやめた理由そのもの。"""
        self.assertEqual(
            sorted(mod.EXPECTED),
            ["deploy-web-dev.yml", "deploy-web-prod.yml"],
        )

    def test_real_workflows_pass(self):
        """リポジトリの実ファイルが期待値どおりであること。"""
        for name, expected in mod.EXPECTED.items():
            self.assertEqual(mod.check(mod.WORKFLOWS / name, expected), [], name)

    # --- 欠落・空・配置ミス ---

    def test_missing_key_is_detected(self):
        env = {k: v for k, v in PROD.items() if k != "NEXT_PUBLIC_COGNITO_CLIENT_ID"}
        errors = self.run_check(workflow(env))
        self.assertTrue(any("NEXT_PUBLIC_COGNITO_CLIENT_ID が無い" in e for e in errors), errors)

    def test_empty_value_is_detected(self):
        env = dict(PROD, NEXT_PUBLIC_COGNITO_CLIENT_ID="")
        errors = self.run_check(workflow(env))
        self.assertTrue(any("NEXT_PUBLIC_COGNITO_CLIENT_ID が空" in e for e in errors), errors)

    def test_key_outside_build_step_is_detected(self):
        env = {k: v for k, v in PROD.items() if k != "NEXT_PUBLIC_COGNITO_CLIENT_ID"}
        errors = self.run_check(workflow(
            env, extra_step_env={"NEXT_PUBLIC_COGNITO_CLIENT_ID": PROD["NEXT_PUBLIC_COGNITO_CLIENT_ID"]}))
        self.assertTrue(any("NEXT_PUBLIC_COGNITO_CLIENT_ID が無い" in e for e in errors), errors)

    # --- Build step を見失うケース（以前は黙って対象外になっていた）---

    def test_wrong_working_directory_is_detected(self):
        errors = self.run_check(workflow(PROD, working_dir="wep"))
        self.assertTrue(any("ビルドする step が見つからない" in e for e in errors), errors)

    def test_build_command_change_is_detected(self):
        errors = self.run_check(workflow(PROD, build_cmd="npm run bulid"))
        self.assertTrue(any("ビルドする step が見つからない" in e for e in errors), errors)

    def test_missing_file_is_detected(self):
        with tempfile.TemporaryDirectory() as d:
            errors = mod.check(Path(d) / "deploy-web-prod.yml", PROD)
        self.assertTrue(any("見つからない" in e for e in errors), errors)

    # --- dev/prod の取り違え ---

    def test_prod_with_dev_api_is_detected(self):
        env = dict(PROD, NEXT_PUBLIC_API_BASE_URL="https://api.dev.rikako.org")
        errors = self.run_check(workflow(env))
        self.assertTrue(any("NEXT_PUBLIC_API_BASE_URL" in e for e in errors), errors)

    def test_prod_with_dev_cognito_client_id_is_detected(self):
        """ログイン不能につながる取り違え。API だけ見ていた頃は通っていた。"""
        dev_id = DEV["NEXT_PUBLIC_COGNITO_CLIENT_ID"]
        env = dict(PROD, NEXT_PUBLIC_COGNITO_CLIENT_ID=dev_id)
        errors = self.run_check(workflow(env))
        self.assertTrue(any("NEXT_PUBLIC_COGNITO_CLIENT_ID" in e for e in errors), errors)

    def test_prod_with_dev_content_url_is_detected(self):
        env = dict(PROD, NEXT_PUBLIC_CONTENT_BASE_URL="https://content.dev.rikako.org/v1")
        errors = self.run_check(workflow(env))
        self.assertTrue(any("NEXT_PUBLIC_CONTENT_BASE_URL" in e for e in errors), errors)

    def test_site_pinned_instead_of_matrix_is_detected(self):
        """matrix で回さず片方に固定されていたら弾く（もう片方が出なくなる）。"""
        env = dict(PROD, NEXT_PUBLIC_SITE="chemistry")
        errors = self.run_check(workflow(env))
        self.assertTrue(any("NEXT_PUBLIC_SITE" in e for e in errors), errors)

    # --- 2サイト同時配信 ---

    PROD_MATRIX = mod.EXPECTED_MATRIX["prod"]

    def test_missing_site_in_matrix_is_detected(self):
        """chemistry だけ落ちて IT しか出ない、という状態を防ぐ。"""
        errors = self.run_check(workflow(PROD, include=self.PROD_MATRIX[:1]))
        self.assertTrue(any("matrix" in e for e in errors), errors)

    def test_unknown_site_in_matrix_is_detected(self):
        extra = self.PROD_MATRIX + [("physics", "rikako-physics-production", "physics.rikako.org")]
        errors = self.run_check(workflow(PROD, include=extra))
        self.assertTrue(any("matrix" in e for e in errors), errors)

    def test_duplicated_entry_is_detected(self):
        """集合で比べていると、重複が消えて片方の欠落を見逃す。"""
        dup = [self.PROD_MATRIX[0], self.PROD_MATRIX[0]]
        errors = self.run_check(workflow(PROD, include=dup))
        self.assertTrue(any("matrix" in e for e in errors), errors)

    def test_swapped_buckets_are_detected(self):
        """IT の成果物を chemistry の本番バケットへ --delete 付きで同期する事故。"""
        (s1, b1, a1), (s2, b2, a2) = self.PROD_MATRIX
        errors = self.run_check(workflow(PROD, include=[(s1, b2, a1), (s2, b1, a2)]))
        self.assertTrue(any("matrix" in e for e in errors), errors)

    def test_swapped_aliases_are_detected(self):
        """配信先バケットは正しいのに、無効化する CloudFront が逆になる事故。"""
        (s1, b1, a1), (s2, b2, a2) = self.PROD_MATRIX
        errors = self.run_check(workflow(PROD, include=[(s1, b1, a2), (s2, b2, a1)]))
        self.assertTrue(any("matrix" in e for e in errors), errors)

    def test_dev_bucket_in_prod_matrix_is_detected(self):
        """prod の matrix に dev のバケットが紛れ込むケース。"""
        (s1, _, a1), rest = self.PROD_MATRIX[0], self.PROD_MATRIX[1:]
        include = [(s1, "rikako-it-development", a1)] + rest
        errors = self.run_check(workflow(PROD, include=include))
        self.assertTrue(any("matrix" in e for e in errors), errors)

    # --- checkout_ref の検証（未マージコードを prod 権限で実行させない）---

    def test_missing_ref_validation_is_detected(self):
        errors = self.run_check(workflow(PROD, validate=None))
        self.assertTrue(any("検証していない" in e for e in errors), errors)

    def test_validation_after_npm_ci_is_detected(self):
        """npm ci の lifecycle script が先に走ってしまう並び。"""
        content = workflow(PROD)
        # Install を検証 step より前に移す
        content = content.replace(
            "      - name: Validate checkout ref", "      - name: Install\n"
            "        working-directory: web\n        run: npm ci\n"
            "      - name: Validate checkout ref", 1)
        content = content.replace(
            "      - name: Install\n        working-directory: web\n        run: npm ci\n"
            "      - name: Build", "      - name: Build", 1)
        errors = self.run_check(content)
        self.assertTrue(any("npm ci より後" in e for e in errors), errors)

    def test_ref_not_restricted_to_sha_is_detected(self):
        """branch 名を渡せると、未マージのコードを prod 権限で実行できる。"""
        errors = self.run_check(workflow(
            PROD, validate='git merge-base --is-ancestor "$CHECKOUT_REF" origin/main'))
        self.assertTrue(any("40 桁の SHA" in e for e in errors), errors)

    def test_expression_in_run_is_detected(self):
        """expression を run へ直書きするとシェル入力になる。"""
        errors = self.run_check(workflow(
            PROD, validate='[[ "${{ inputs.checkout_ref }}" =~ ^[0-9a-fA-F]{40}$ ]] && '
                           'git merge-base --is-ancestor x origin/main'))
        self.assertTrue(any("直書き" in e for e in errors), errors)

    def test_prod_without_deploy_tag_restriction_is_detected(self):
        """main 履歴上でも未デプロイの commit へ戻せてしまう状態を防ぐ。"""
        errors = self.run_check(workflow(PROD, validate=DEV_REF_CHECK))
        self.assertTrue(any("web-prod/*" in e for e in errors), errors)

    def test_dev_does_not_require_deploy_tag(self):
        """dev は実績タグを要求しない（要求すると初回が回らない）。"""
        errors = self.run_check(
            workflow(DEV, triggers=["push", "workflow_dispatch"], environment=None,
                     env_name="dev", validate=DEV_REF_CHECK),
            DEV, "deploy-web-dev.yml")
        self.assertEqual(errors, [])

    def test_shallow_checkout_is_detected(self):
        """履歴が無いと merge-base が常に失敗する（= 検証が形骸化する）。"""
        errors = self.run_check(workflow(PROD, fetch_depth=1))
        self.assertTrue(any("fetch-depth" in e for e in errors), errors)

    # --- S3 同期の形（#336: cache-control が効いていなかった / #342: 旧チャンクが消えていた）---

    def test_valid_sync_passes(self):
        self.assertEqual(self.run_sync_check(workflow(PROD)), [])

    def test_cache_control_in_sync_is_detected(self):
        """Cache-Control は CloudFront の責務。sync に戻すと #336 が再発する。"""
        sync = VALID_SYNC.replace(
            "s3://bucket/_next/static/",
            's3://bucket/_next/static/ --cache-control "public, max-age=31536000, immutable"')
        errors = self.run_sync_check(workflow(PROD, sync=sync))
        self.assertTrue(any("--cache-control" in e for e in errors), errors)

    def test_deleting_old_chunks_is_detected(self):
        """チャンクに --delete を付けると、開いたままの画面が ChunkLoadError になる。"""
        sync = VALID_SYNC.replace(
            "s3://bucket/_next/static/\n", "s3://bucket/_next/static/ --delete\n")
        errors = self.run_sync_check(workflow(PROD, sync=sync))
        self.assertTrue(any("即削除" in e for e in errors), errors)

    def test_html_before_chunks_is_detected(self):
        """HTML が先だと、新 HTML が参照するチャンクがまだ無い瞬間ができる。"""
        sync = "\n".join(reversed(VALID_SYNC.strip().splitlines()))
        errors = self.run_sync_check(workflow(PROD, sync=sync))
        self.assertTrue(errors, errors)

    def test_missing_delete_is_detected(self):
        """HTML 側の --delete が無いと、消したページが公開され続ける。"""
        sync = VALID_SYNC.replace(" --delete", "")
        errors = self.run_sync_check(workflow(PROD, sync=sync))
        self.assertTrue(any("--delete が無い" in e for e in errors), errors)

    def test_chunk_exclusion_in_html_sync_is_required(self):
        """HTML 側が _next/static を除外しないと、--delete が旧チャンクを消す。"""
        sync = VALID_SYNC.replace(' --exclude "_next/static/*"', "")
        errors = self.run_sync_check(workflow(PROD, sync=sync))
        self.assertTrue(any("除外していない" in e for e in errors), errors)

    def test_single_sync_is_detected(self):
        errors = self.run_sync_check(workflow(PROD, sync="""
aws s3 sync out/ s3://bucket/ --delete
"""))
        self.assertTrue(any("2 回" in e for e in errors), errors)

    def test_missing_sync_step_is_detected(self):
        errors = self.run_sync_check(workflow(PROD, sync=None))
        self.assertTrue(any("s3 sync する step" in e for e in errors), errors)

    def test_sync_workflows_are_covered(self):
        """検査対象が黙って減らないこと。web だけでなく portal / admin も含む。"""
        self.assertEqual(sorted(mod.SYNC_WORKFLOWS), [
            "deploy-admin-frontend-dev.yml",
            "deploy-admin-frontend-prod.yml",
            "deploy-portal-dev.yml",
            "deploy-portal-prod.yml",
            "deploy-web-dev.yml",
            "deploy-web-prod.yml",
        ])

    def test_real_workflows_sync_passes(self):
        """リポジトリの実ファイルが、6 本とも同じ配信手順になっていること。"""
        import yaml
        for name in mod.SYNC_WORKFLOWS:
            path = mod.WORKFLOWS / name
            workflow_doc = yaml.safe_load(path.read_text(encoding="utf-8"))
            self.assertEqual(mod.check_s3_sync(path, workflow_doc), [], name)

    # --- source / destination（フラグが合っていても転送先を間違えれば壊れる）---

    def test_whole_site_into_chunk_prefix_is_detected(self):
        """サイト全体をチャンク階層へ流し込む誤り。フラグだけでは見抜けない。"""
        errors = self.run_sync_check(workflow(PROD, sync="""
aws s3 sync out/ s3://bucket/_next/static/
aws s3 sync out/ s3://bucket/ --delete --exclude "_next/static/*"
"""))
        self.assertTrue(any("_next/static/ どうし" in e for e in errors), errors)

    def test_wrong_source_in_html_sync_is_detected(self):
        """2 本目の source を間違えると、--delete が公開中のファイルを消す。"""
        errors = self.run_sync_check(workflow(PROD, sync="""
aws s3 sync out/_next/static/ s3://bucket/_next/static/
aws s3 sync wrong/ s3://bucket/ --delete --exclude "_next/static/*"
"""))
        self.assertTrue(any("親になっていない" in e for e in errors), errors)

    def test_bucket_mismatch_is_detected(self):
        """2 本の宛先バケットがずれていると、片方のサイトを別サイトの内容で壊す。"""
        errors = self.run_sync_check(workflow(PROD, sync="""
aws s3 sync out/_next/static/ s3://bucket/_next/static/
aws s3 sync out/ s3://other-bucket/ --delete --exclude "_next/static/*"
"""))
        self.assertTrue(any("親になっていない" in e for e in errors), errors)

    def test_matrix_expression_destination_passes(self):
        """${{ matrix.bucket }} のような expression でも位置引数として読めること。"""
        self.assertEqual(self.run_sync_check(workflow(PROD, sync="""
aws s3 sync out/_next/static/ s3://${{ matrix.bucket }}/_next/static/
aws s3 sync out/ s3://${{ matrix.bucket }}/ --delete --exclude "_next/static/*"
""")), [])

    # --- 後続 step に足された sync ---

    def test_extra_sync_in_later_step_is_detected(self):
        """最初の step で打ち切ると、後から足した全消し sync を見逃す。"""
        errors = self.run_sync_check(workflow(
            PROD, extra_sync="aws s3 sync empty/ s3://bucket/ --delete"))
        self.assertTrue(any("3 回" in e for e in errors), errors)

    def test_extra_cache_control_sync_in_later_step_is_detected(self):
        errors = self.run_sync_check(workflow(
            PROD,
            extra_sync='aws s3 sync out/ s3://bucket/ --cache-control "public, max-age=0"'))
        self.assertTrue(errors, errors)

    # --- 本番の承認ゲート ---

    def test_prod_without_environment_is_detected(self):
        """承認なしで本番に出せる状態を防ぐ。"""
        errors = self.run_check(workflow(PROD, environment=None))
        self.assertTrue(any("environment" in e for e in errors), errors)

    def test_dev_with_production_environment_is_detected(self):
        """dev に承認ゲートが付くと自動デプロイが止まる。"""
        errors = self.run_check(
            workflow(DEV, triggers=["push", "workflow_dispatch"],
                     environment="production", env_name="dev", validate=DEV_REF_CHECK),
            DEV, "deploy-web-dev.yml")
        self.assertTrue(any("environment" in e for e in errors), errors)

    # --- トリガーの非対称 ---

    def test_prod_with_push_trigger_is_detected(self):
        """prod が自動デプロイになっていたら弾く。"""
        errors = self.run_check(workflow(PROD, triggers=["push", "workflow_dispatch"]))
        self.assertTrue(any("トリガー" in e for e in errors), errors)

    def test_dev_without_push_trigger_is_detected(self):
        """dev だけ手動のまま取り残されるのを防ぐ（化学版で実際に起きた）。"""
        errors = self.run_check(workflow(DEV, triggers=["workflow_dispatch"], environment=None,
                                         env_name="dev", validate=DEV_REF_CHECK),
                                DEV, "deploy-web-dev.yml")
        self.assertTrue(any("トリガー" in e for e in errors), errors)

    def test_wrong_region_is_detected(self):
        env = dict(PROD, NEXT_PUBLIC_COGNITO_REGION="ap-southeast-1")
        errors = self.run_check(workflow(env))
        self.assertTrue(any("NEXT_PUBLIC_COGNITO_REGION" in e for e in errors), errors)


if __name__ == "__main__":
    unittest.main()
