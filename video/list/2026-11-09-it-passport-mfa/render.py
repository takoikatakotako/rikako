#!/usr/bin/env python3
"""Draw the nine vertical slides for the IT Passport MFA pilot."""

from __future__ import annotations

import html
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent
FRAMES = ROOT / "frames"
TURTLE = ROOT.parents[1] / "assets/rikako-turtle-v1.png"
W, H = 1080, 1920
NAVY = "#102B25"
PAPER = "#F4F0E7"
WHITE = "#FFFCF7"
MINT = "#CDEB79"
BLUE = "#50BDD1"
AMBER = "#F4C17E"
MUTED = "#66776D"
LINE = "#D5DCD1"
DARK_MID = "#33594D"
FONT = "Hiragino Sans"
SCENES = ("hook", "choices", "three", "two", "one", "answer", "knowledge", "possession", "outro")


def rect(x: int, y: int, w: int, h: int, color: str, radius: int = 0) -> str:
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{radius}" fill="{color}" stroke="none"/>'


def label(x: int, y: int, value: str, size: int, color: str = NAVY,
          weight: int = 700, anchor: str = "start") -> str:
    return (f'<text x="{x}" y="{y}" text-anchor="{anchor}" font-family="{FONT}" '
            f'font-size="{size}" font-weight="{weight}" fill="{color}" stroke="none">{html.escape(value)}</text>')


def stroke(x1: int, y1: int, x2: int, y2: int, color: str = LINE, width: int = 3) -> str:
    return f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{color}" stroke-width="{width}"/>'


def circle(x: int, y: int, radius: int, color: str) -> str:
    return f'<circle cx="{x}" cy="{y}" r="{radius}" fill="{color}" stroke="none"/>'


def svg(parts: list[str]) -> str:
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">' + "".join(parts) + "</svg>"


def base(number: int, dark: bool = False) -> list[str]:
    fg = WHITE if dark else NAVY
    secondary = "#C4D1C3" if dark else MUTED
    background = NAVY if dark else PAPER
    parts = [
        rect(0, 0, W, H, background),
        rect(70, 78, 71, 71, MINT, 17),
        label(106, 130, "理", 43, NAVY, 800, "middle"),
        label(166, 126, "RIKAKO  /  ITパスポート", 35, fg),
        label(1010, 126, f"{number:02d} / 09", 29, secondary, 500, "end"),
        stroke(70, 1781, 1010, 1781, DARK_MID if dark else LINE, 3),
        label(70, 1850, "1問で覚えるIT", 29, secondary, 600),
    ]
    return parts


def lock_icon(x: int, y: int, color: str) -> list[str]:
    return [
        f'<path d="M{x+44} {y+83} V{y+51} a52 52 0 0 1 104 0 V{y+83}" fill="none" stroke="{color}" stroke-width="18" stroke-linecap="round"/>',
        rect(x + 17, y + 82, 158, 133, color, 25),
        circle(x + 96, y + 139, 14, NAVY),
        rect(x + 90, y + 137, 12, 37, NAVY, 5),
    ]


def hook() -> str:
    p = base(1, True)
    p += [
        label(70, 378, "パスワードを", 100, WHITE),
        label(70, 510, "2つ使えば…", 112, WHITE),
        rect(70, 622, 940, 118, MINT, 24),
        label(540, 706, "多要素認証になる？", 80, NAVY, 800, "middle"),
        rect(118, 955, 844, 180, DARK_MID, 30),
        rect(118, 1170, 844, 180, DARK_MID, 30),
        label(190, 1070, "● ● ● ● ● ●", 62, WHITE, 700),
        label(190, 1285, "● ● ● ● ● ●", 62, WHITE, 700),
        label(910, 1072, "1", 71, MINT, 700, "end"),
        label(910, 1287, "2", 71, MINT, 700, "end"),
        rect(70, 1510, 425, 130, WHITE, 24),
        label(282, 1600, "考えてみて！", 58, NAVY, 700, "middle"),
    ]
    return svg(p)


OPTIONS = (("A", "暗証番号"), ("B", "秘密の質問"), ("C", "スマホの認証アプリ"), ("D", "合言葉"))


def choices() -> str:
    p = base(2)
    p += [
        label(70, 307, "QUESTION", 38, MUTED, 600),
        label(70, 438, "パスワードに足すなら、", 73),
        label(70, 548, "どれが多要素認証？", 82),
    ]
    for i, (letter, option) in enumerate(OPTIONS):
        y = 675 + i * 245
        p += [
            rect(70, y, 940, 195, WHITE, 25),
            circle(154, y + 97, 55, NAVY),
            label(154, y + 121, letter, 66, WHITE, 800, "middle"),
            label(252, y + 123, option, 65 if letter == "C" else 76),
        ]
    return svg(p)


def countdown(number: int, index: int) -> str:
    p = base(index, True)
    p += [
        label(70, 356, "パスワードに足すなら？", 70, WHITE),
        label(70, 525, "THINK", 44, MINT, 700),
        label(540, 1240, str(number), 710, WHITE, 800, "middle"),
        stroke(70, 1432, 1010, 1432, DARK_MID, 13),
        stroke(70, 1432, 70 + (4 - number) * 313, 1432, MINT, 13),
        label(70, 1602, "要素の種類に注目", 58, MINT),
    ]
    return svg(p)


def answer() -> str:
    p = base(6, True)
    p += [
        label(70, 337, "ANSWER", 42, MINT, 700),
        rect(70, 446, 250, 250, MINT, 35),
        label(195, 629, "C", 178, NAVY, 800, "middle"),
        label(70, 859, "スマホの", 105, WHITE),
        label(70, 1005, "認証アプリ", 105, WHITE),
        stroke(70, 1100, 1010, 1100, DARK_MID, 3),
        label(70, 1252, "知識 ＋ 所持", 102, MINT),
        label(70, 1383, "種類の違う2つを使う", 60, WHITE),
    ]
    return svg(p)


def knowledge() -> str:
    p = base(7)
    p += [
        label(70, 333, "同じ種類を重ねても…", 76),
        rect(70, 500, 940, 287, WHITE, 30),
        label(118, 617, "パスワード", 78),
        label(118, 713, "覚えている情報", 47, MUTED, 500),
        rect(70, 826, 940, 287, WHITE, 30),
        label(118, 943, "暗証番号", 78),
        label(118, 1039, "覚えている情報", 47, MUTED, 500),
        rect(70, 1215, 940, 235, AMBER, 28),
        label(540, 1344, "知識 ＋ 知識", 92, NAVY, 800, "middle"),
        label(540, 1421, "要素は1種類", 44, NAVY, 600, "middle"),
    ]
    return svg(p)


def possession() -> str:
    p = base(8)
    p += [
        label(70, 333, "種類を変えると…", 86),
        rect(70, 540, 435, 494, WHITE, 30),
        rect(575, 540, 435, 494, WHITE, 30),
        *lock_icon(185, 615, BLUE),
        label(287, 945, "知識", 74, NAVY, 800, "middle"),
        rect(699, 610, 184, 270, NAVY, 30),
        rect(717, 635, 148, 205, MINT, 14),
        circle(791, 861, 9, MINT),
        label(792, 945, "所持", 74, NAVY, 800, "middle"),
        rect(70, 1174, 940, 265, MINT, 30),
        label(540, 1306, "知識 ＋ 所持", 100, NAVY, 800, "middle"),
        label(540, 1390, "これが多要素認証", 49, NAVY, 600, "middle"),
    ]
    return svg(p)


def outro() -> str:
    p = base(9, True)
    p += [
        label(70, 383, "覚えるポイント", 68, MINT),
        label(70, 574, "入力回数より", 116, WHITE),
        label(70, 730, "要素の種類。", 116, WHITE),
        rect(70, 891, 940, 254, MINT, 31),
        label(540, 1053, "知識・所持・生体", 82, NAVY, 800, "middle"),
        label(70, 1422, "あなたは解けた？", 88, WHITE),
        label(70, 1534, "ITパスポート  /  1問で覚える", 41, "#C4D1C3", 500),
    ]
    return svg(p)


DRAW = {
    "hook": hook,
    "choices": choices,
    "three": lambda: countdown(3, 3),
    "two": lambda: countdown(2, 4),
    "one": lambda: countdown(1, 5),
    "answer": answer,
    "knowledge": knowledge,
    "possession": possession,
    "outro": outro,
}


def main() -> None:
    FRAMES.mkdir(exist_ok=True)
    turtle_resized = FRAMES / "turtle.png"
    subprocess.run(["magick", str(TURTLE), "-resize", "500x333", str(turtle_resized)], check=True)
    for name in SCENES:
        source = FRAMES / f"{name}.svg"
        source.write_text(DRAW[name](), encoding="utf-8")
        background = FRAMES / f"{name}.png"
        subprocess.run(["magick", "-background", "none", str(source), str(background)], check=True)
        if name in {"hook", "answer", "outro"}:
            subprocess.run(["magick", str(background), str(turtle_resized), "-geometry", "+545+1395",
                            "-compose", "over", "-composite", str(background)], check=True)
    subprocess.run([
        "magick", "montage", *(str(FRAMES / f"{name}.png") for name in SCENES),
        "-thumbnail", "216x384", "-tile", "3x3", "-geometry", "+8+8",
        str(ROOT / "storyboard.png"),
    ], check=True)


if __name__ == "__main__":
    main()
