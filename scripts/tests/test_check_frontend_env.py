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

PROD_IT = mod.EXPECTED["deploy-it-frontend-prod.yml"]


def workflow(env: dict, *, working_dir: str = "web", build_cmd: str = "npm run build",
             extra_step_env: dict | None = None, triggers: list | None = None) -> str:
    """Build step の env に指定した値を持つワークフローを組み立てる。"""
    trigger_lines = ["on:"]
    for t in (triggers or ["workflow_dispatch"]):
        trigger_lines.append(f"  {t}:")
    lines = [
        "name: Deploy", *trigger_lines, "jobs:", "  deploy:",
        "    runs-on: ubuntu-latest", "    steps:",
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
                  name: str = "deploy-it-frontend-prod.yml"):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / name
            path.write_text(content, encoding="utf-8")
            return mod.check(path, expected or PROD_IT)

    # --- 正常系 ---

    def test_valid_workflow_passes(self):
        self.assertEqual(self.run_check(workflow(PROD_IT)), [])

    def test_valid_dev_workflow_passes(self):
        dev = mod.EXPECTED["deploy-it-frontend-dev.yml"]
        self.assertEqual(
            self.run_check(workflow(dev, triggers=["push", "workflow_dispatch"]),
                           dev, "deploy-it-frontend-dev.yml"), [])

    def test_all_four_workflows_are_checked(self):
        """対象が黙って減らないこと。自動検出をやめた理由そのもの。"""
        self.assertEqual(
            sorted(mod.EXPECTED),
            sorted([
                "deploy-chemistry-frontend-dev.yml",
                "deploy-chemistry-frontend-prod.yml",
                "deploy-it-frontend-dev.yml",
                "deploy-it-frontend-prod.yml",
            ]),
        )

    def test_real_workflows_pass(self):
        """リポジトリの実ファイルが期待値どおりであること。"""
        for name, expected in mod.EXPECTED.items():
            self.assertEqual(mod.check(mod.WORKFLOWS / name, expected), [], name)

    # --- 欠落・空・配置ミス ---

    def test_missing_key_is_detected(self):
        env = {k: v for k, v in PROD_IT.items() if k != "NEXT_PUBLIC_COGNITO_CLIENT_ID"}
        errors = self.run_check(workflow(env))
        self.assertTrue(any("NEXT_PUBLIC_COGNITO_CLIENT_ID が無い" in e for e in errors), errors)

    def test_empty_value_is_detected(self):
        env = dict(PROD_IT, NEXT_PUBLIC_COGNITO_CLIENT_ID="")
        errors = self.run_check(workflow(env))
        self.assertTrue(any("NEXT_PUBLIC_COGNITO_CLIENT_ID が空" in e for e in errors), errors)

    def test_key_outside_build_step_is_detected(self):
        env = {k: v for k, v in PROD_IT.items() if k != "NEXT_PUBLIC_COGNITO_CLIENT_ID"}
        errors = self.run_check(workflow(
            env, extra_step_env={"NEXT_PUBLIC_COGNITO_CLIENT_ID": PROD_IT["NEXT_PUBLIC_COGNITO_CLIENT_ID"]}))
        self.assertTrue(any("NEXT_PUBLIC_COGNITO_CLIENT_ID が無い" in e for e in errors), errors)

    # --- Build step を見失うケース（以前は黙って対象外になっていた）---

    def test_wrong_working_directory_is_detected(self):
        errors = self.run_check(workflow(PROD_IT, working_dir="wep"))
        self.assertTrue(any("ビルドする step が見つからない" in e for e in errors), errors)

    def test_build_command_change_is_detected(self):
        errors = self.run_check(workflow(PROD_IT, build_cmd="npm run bulid"))
        self.assertTrue(any("ビルドする step が見つからない" in e for e in errors), errors)

    def test_missing_file_is_detected(self):
        with tempfile.TemporaryDirectory() as d:
            errors = mod.check(Path(d) / "deploy-it-frontend-prod.yml", PROD_IT)
        self.assertTrue(any("見つからない" in e for e in errors), errors)

    # --- dev/prod の取り違え ---

    def test_prod_with_dev_api_is_detected(self):
        env = dict(PROD_IT, NEXT_PUBLIC_API_BASE_URL="https://api.dev.rikako.org")
        errors = self.run_check(workflow(env))
        self.assertTrue(any("NEXT_PUBLIC_API_BASE_URL" in e for e in errors), errors)

    def test_prod_with_dev_cognito_client_id_is_detected(self):
        """ログイン不能につながる取り違え。API だけ見ていた頃は通っていた。"""
        dev_id = mod.EXPECTED["deploy-it-frontend-dev.yml"]["NEXT_PUBLIC_COGNITO_CLIENT_ID"]
        env = dict(PROD_IT, NEXT_PUBLIC_COGNITO_CLIENT_ID=dev_id)
        errors = self.run_check(workflow(env))
        self.assertTrue(any("NEXT_PUBLIC_COGNITO_CLIENT_ID" in e for e in errors), errors)

    def test_prod_with_dev_content_url_is_detected(self):
        env = dict(PROD_IT, NEXT_PUBLIC_CONTENT_BASE_URL="https://content.dev.rikako.org/v1")
        errors = self.run_check(workflow(env))
        self.assertTrue(any("NEXT_PUBLIC_CONTENT_BASE_URL" in e for e in errors), errors)

    def test_wrong_site_is_detected(self):
        """IT のワークフローに chemistry が入っている、など。"""
        env = dict(PROD_IT, NEXT_PUBLIC_SITE="chemistry")
        errors = self.run_check(workflow(env))
        self.assertTrue(any("NEXT_PUBLIC_SITE" in e for e in errors), errors)

    # --- トリガーの非対称 ---

    def test_prod_with_push_trigger_is_detected(self):
        """prod が自動デプロイになっていたら弾く。"""
        errors = self.run_check(workflow(PROD_IT, triggers=["push", "workflow_dispatch"]))
        self.assertTrue(any("トリガー" in e for e in errors), errors)

    def test_dev_without_push_trigger_is_detected(self):
        """dev だけ手動のまま取り残されるのを防ぐ（化学版で実際に起きた）。"""
        dev = mod.EXPECTED["deploy-it-frontend-dev.yml"]
        errors = self.run_check(workflow(dev, triggers=["workflow_dispatch"]),
                                dev, "deploy-it-frontend-dev.yml")
        self.assertTrue(any("トリガー" in e for e in errors), errors)

    def test_wrong_region_is_detected(self):
        env = dict(PROD_IT, NEXT_PUBLIC_COGNITO_REGION="ap-southeast-1")
        errors = self.run_check(workflow(env))
        self.assertTrue(any("NEXT_PUBLIC_COGNITO_REGION" in e for e in errors), errors)


if __name__ == "__main__":
    unittest.main()
