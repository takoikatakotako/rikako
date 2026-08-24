#!/usr/bin/env python3
"""openapi.yaml の全パスが API Gateway の明示ルートに含まれるかを検証する。

API Gateway には先頭セグメント単位の明示ルートを置いてあり、$default も残している。
そのため route_keys の更新を忘れても 404 にはならないが、そのパスはアクセスログ上
routeKey が "$default" になり、**未定義パスへのアクセス（スキャン）と区別できなくなる**。
ラベル付けの網羅性を保つために CI で検出する。
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OPENAPI = ROOT / "openapi.yaml"
TF = ROOT / "terraform/modules/api_gateway/main.tf"


def openapi_paths() -> list[str]:
    return re.findall(r"^  (/[^\s:]*):", OPENAPI.read_text(encoding="utf-8"), re.M)


def route_keys() -> list[str]:
    tf = TF.read_text(encoding="utf-8")
    block = re.search(r"route_keys\s*=\s*\[(.*?)\]", tf, re.S)
    if not block:
        sys.exit(f"route_keys が {TF} に見つからない")
    return re.findall(r'"ANY (/[^"]*)"', block.group(1))


def covered(path: str, routes: list[str]) -> bool:
    for r in routes:
        if r == path:
            return True
        # ANY /users/{proxy+} は /users/ 以下のすべてに一致する
        if r.endswith("/{proxy+}") and path.startswith(r[: -len("{proxy+}")]):
            return True
    return False


def main() -> int:
    routes = route_keys()
    missing = [p for p in openapi_paths() if not covered(p, routes)]
    if missing:
        print("API Gateway のルートに含まれていないパスがあります:", file=sys.stderr)
        for p in missing:
            print(f"  {p}", file=sys.stderr)
        print(
            f"\n{TF.relative_to(ROOT)} の route_keys に追加してください"
            "（既存の先頭セグメント配下なら {proxy+} で既に覆われているはずです）。\n"
            "$default があるため 404 にはなりませんが、アクセスログ上でスキャンと"
            "区別できなくなります。",
            file=sys.stderr,
        )
        return 1
    print(f"OK: openapi.yaml の {len(openapi_paths())} パスはすべてルートに含まれています")
    return 0


if __name__ == "__main__":
    sys.exit(main())
