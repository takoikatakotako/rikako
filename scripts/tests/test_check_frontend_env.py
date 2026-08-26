"""check-frontend-env.py が「実際にビルドへ渡らない env」を検出できることを確かめる。

ガード自体が退行すると、守っているつもりで守れていない状態になるため。
標準ライブラリだけで動く（python3 -m unittest discover scripts/tests）。
"""
import importlib.util
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path

MODULE_PATH = Path(__file__).resolve().parent.parent / "check-frontend-env.py"
spec = importlib.util.spec_from_file_location("check_frontend_env", MODULE_PATH)
mod = importlib.util.module_from_spec(spec)
sys.modules["check_frontend_env"] = mod
spec.loader.exec_module(mod)


def workflow(env_block: str, *, working_dir: str = "web", extra: str = "") -> str:
    """env_block（KEY: VALUE の行）を Build step の env に埋めたワークフローを組み立てる。"""
    env_lines = [l for l in env_block.strip("\n").split("\n") if l.strip()]
    env_yaml = "\n".join(" " * 10 + l.strip() for l in env_lines)
    lines = [
        "name: Deploy",
        "on:",
        "  workflow_dispatch:",
        "jobs:",
        "  deploy:",
        "    runs-on: ubuntu-latest",
        "    steps:",
        "      - name: Install",
        f"        working-directory: {working_dir}",
        "        run: npm ci",
        "      - name: Build",
        f"        working-directory: {working_dir}",
        "        run: npm run build",
        "        env:",
        env_yaml,
    ]
    if extra:
        lines.append(extra.rstrip("\n"))
    return "\n".join(lines) + "\n"


VALID_PROD = """\
NEXT_PUBLIC_SITE: it
NEXT_PUBLIC_CONTENT_BASE_URL: https://content.rikako.org/v1
NEXT_PUBLIC_API_BASE_URL: https://api.rikako.org
NEXT_PUBLIC_COGNITO_REGION: ap-northeast-1
NEXT_PUBLIC_COGNITO_CLIENT_ID: abc123
"""


class CheckFrontendEnvTest(unittest.TestCase):
    def run_check(self, content: str, name: str = "deploy-it-frontend-prod.yml"):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / name
            path.write_text(content, encoding="utf-8")
            return mod.check(path)

    def test_valid_workflow_passes(self):
        self.assertEqual(self.run_check(workflow(VALID_PROD)), [])

    def test_missing_key_is_detected(self):
        env = VALID_PROD.replace("NEXT_PUBLIC_COGNITO_CLIENT_ID: abc123\n", "")
        errors = self.run_check(workflow(env))
        self.assertTrue(any("NEXT_PUBLIC_COGNITO_CLIENT_ID が無い" in e for e in errors), errors)

    def test_empty_value_is_detected(self):
        env = VALID_PROD.replace("NEXT_PUBLIC_COGNITO_CLIENT_ID: abc123", "NEXT_PUBLIC_COGNITO_CLIENT_ID: ''")
        errors = self.run_check(workflow(env))
        self.assertTrue(any("NEXT_PUBLIC_COGNITO_CLIENT_ID が空" in e for e in errors), errors)

    def test_key_outside_build_step_is_detected(self):
        """別 step にだけ置かれていてもビルドには渡らない。"""
        env = VALID_PROD.replace("NEXT_PUBLIC_COGNITO_CLIENT_ID: abc123\n", "")
        extra = "\n".join([
            "      - name: Deploy",
            "        run: echo deploy",
            "        env:",
            "          NEXT_PUBLIC_COGNITO_CLIENT_ID: abc123",
        ])
        errors = self.run_check(workflow(env, extra=extra))
        self.assertTrue(any("NEXT_PUBLIC_COGNITO_CLIENT_ID が無い" in e for e in errors), errors)

    def test_prod_pointing_at_dev_api_is_detected(self):
        env = VALID_PROD.replace("https://api.rikako.org", "https://api.dev.rikako.org")
        errors = self.run_check(workflow(env))
        self.assertTrue(any("NEXT_PUBLIC_API_BASE_URL" in e for e in errors), errors)

    def test_unexpected_host_is_detected(self):
        """dev / prod のどちらでもない別ホストも弾く（部分一致では拾えない）。"""
        env = VALID_PROD.replace("https://api.rikako.org", "https://api.staging.rikako.org")
        errors = self.run_check(workflow(env))
        self.assertTrue(any("NEXT_PUBLIC_API_BASE_URL" in e for e in errors), errors)

    def test_dev_workflow_expects_dev_api(self):
        env = VALID_PROD.replace("https://api.rikako.org", "https://api.dev.rikako.org")
        self.assertEqual(self.run_check(workflow(env), "deploy-it-frontend-dev.yml"), [])

    def test_non_web_workflow_is_not_a_target(self):
        """管理画面など web/ をビルドしないものは対象外。"""
        content = workflow(VALID_PROD, working_dir="admin-frontend")
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / "deploy-admin-frontend-prod.yml"
            path.write_text(content, encoding="utf-8")
            self.assertEqual(mod.targets(Path(d)), [])


if __name__ == "__main__":
    unittest.main()
