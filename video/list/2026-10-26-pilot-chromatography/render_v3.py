#!/usr/bin/env python3
"""Render the style-guide variant of the chromatography short."""

from __future__ import annotations

import html
import shutil
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent
FRAMES = ROOT / "frames/v3"
HERO_QUESTION = ROOT / "assets/hero-chromatography-question-v2.webp"
HERO_REVEAL = ROOT / "assets/hero-chromatography-v2.webp"
TURTLE = ROOT.parents[1] / "assets/rikako-turtle-v1.png"
APP_ICON = ROOT.parents[1] / "assets/app-icon-chemistry.png"
PAPER = "#F4F0E7"
WHITE = "#FFFCF7"
INK = "#102B25"
MUTED = "#66776D"
LIME = "#CDEB79"
CYAN = "#50BDD1"
PINK = "#E75C91"
PURPLE = "#75559A"
FONT = "Hiragino Sans"
SCENES = ["hook", "choices", "three", "two", "one", "answer", "setup", "moving", "separated", "outro"]


def run(*args: str) -> None:
    subprocess.run(args, check=True)


def text(x: int, y: int, value: str, size: int, *, color: str = INK,
         weight: int = 700, anchor: str = "start", spacing: int = 0) -> str:
    return (f'<text x="{x}" y="{y}" text-anchor="{anchor}" font-family="{FONT}" '
            f'font-size="{size}" font-weight="{weight}" letter-spacing="{spacing}" '
            f'fill="{color}" stroke="none">{html.escape(value)}</text>')


def rect(x: int, y: int, w: int, h: int, fill: str, radius: int = 0,
         stroke: str = "none", sw: int = 0) -> str:
    return (f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{radius}" '
            f'fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>')


def line(x1: int, y1: int, x2: int, y2: int, color: str, width: int = 3,
         dash: str = "") -> str:
    dash_attr = f' stroke-dasharray="{dash}"' if dash else ""
    return (f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" '
            f'stroke="{color}" stroke-width="{width}"{dash_attr}/>')


def circle(x: int, y: int, radius: int, fill: str, stroke: str = "none", sw: int = 0) -> str:
    return (f'<circle cx="{x}" cy="{y}" r="{radius}" fill="{fill}" '
            f'stroke="{stroke}" stroke-width="{sw}"/>')


def svg(parts: list[str]) -> str:
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="1080" height="1920" '
            'viewBox="0 0 1080 1920">' + "".join(parts) + "</svg>")


def header(index: int, *, dark: bool = False) -> list[str]:
    fg = WHITE if dark else INK
    sub = "#C4D1C3" if dark else MUTED
    p = [
        rect(0, 0, 1080, 1920, INK if dark else PAPER),
        rect(70, 77, 72, 72, LIME, 18),
        text(106, 131, "理", 45, color=INK, anchor="middle"),
        text(165, 129, "RIKAKO  /  化学基礎", 38, color=fg, weight=700, spacing=1),
        text(1008, 128, f"{index+1:02d} / 10", 32, color=sub, weight=500, anchor="end"),
        line(70, 1781, 1010, 1781, "#476057" if dark else "#D5DCD1", 3),
        text(70, 1850, "1問でわかる化学", 29, color=sub, weight=600),
    ]
    return p


def hook() -> str:
    # This SVG is composited over the generated still life.
    p = [
        rect(70, 77, 72, 72, LIME, 18),
        text(106, 131, "理", 45, color=INK, anchor="middle"),
        text(165, 129, "RIKAKO  /  化学基礎", 38, color=WHITE, spacing=1),
        text(1008, 128, "01 / 10", 32, color=WHITE, weight=500, anchor="end"),
        text(70, 300, "黒いインクは", 106, color=WHITE),
        text(70, 432, "本当に1色？", 106, color=WHITE),
        rect(70, 488, 355, 69, LIME, 30),
        text(247, 537, "紙と水で確かめよう", 36, color=INK, anchor="middle"),
        rect(70, 1510, 400, 120, WHITE, 24),
        text(270, 1595, "考えてみて！", 58, color=INK, anchor="middle"),
        line(70, 1781, 1010, 1781, "#476057", 3),
        text(70, 1850, "1問でわかる化学", 29, color=WHITE, weight=600),
    ]
    return svg(p)


OPTIONS = [("A", "ろ過"), ("B", "蒸留"), ("C", "クロマトグラフィー"), ("D", "再結晶")]


def choices() -> str:
    p = header(1)
    p += [
        text(72, 299, "QUESTION", 38, color=MUTED, weight=600, spacing=4),
        text(70, 430, "紙でインクの色を", 91),
        text(70, 548, "分ける方法は？", 91),
    ]
    for i, (letter, label) in enumerate(OPTIONS):
        y = 680 + i * 245
        p += [
            rect(70, y, 940, 195, WHITE, 25),
            circle(154, y + 97, 55, INK),
            text(154, y + 121, letter, 66, color=WHITE, anchor="middle"),
            text(252, y + 123, label, 65 if letter == "C" else 76),
        ]
    return svg(p)


def countdown(number: int, index: int) -> str:
    p = header(index, dark=True)
    p += [
        text(72, 350, "紙で色を分ける方法は？", 68, color=WHITE),
        text(72, 537, "THINK", 42, color=LIME, spacing=4),
        text(540, 1265, str(number), 700, color=WHITE, weight=800, anchor="middle"),
        line(70, 1418, 1010, 1418, "#476057", 12),
        line(70, 1418, 70 + 940 * (4-number) // 3, 1418, LIME, 12),
        text(72, 1572, "どれだと思う？", 64, color=LIME),
    ]
    return svg(p)


def answer() -> str:
    p = header(5, dark=True)
    p += [
        text(72, 307, "ANSWER", 36, color=LIME, spacing=5),
        rect(70, 390, 215, 215, LIME, 38),
        text(177, 552, "C", 178, color=INK, anchor="middle"),
        text(72, 771, "ペーパー", 98, color=WHITE),
        text(72, 899, "クロマトグラフィー", 79, color=WHITE),
        line(70, 1000, 1010, 1000, "#597469", 3),
        text(72, 1136, "色素が進む速さの差で", 65, color=WHITE),
        text(72, 1234, "いくつかの色に分かれる。", 65, color=WHITE),
        text(72, 1335, "RESULT  /  分かれた色", 36, color=LIME, spacing=2),
    ]
    return svg(p)


def diagram(stage: int) -> str:
    index = 6 + stage
    titles = ["点は、水面より上。", "水が紙を上がる。", "色素ごとに分かれる。"]
    subtitles = ["黒インクを紙の線につける", "水と一緒に色素が移動する", "進む速さが違うから、色が見える"]
    p = header(index)
    p += [
        text(72, 291, f"STEP 0{stage + 1} / 03", 35, color=MUTED, spacing=3),
        text(70, 425, titles[stage], 81),
        text(72, 508, subtitles[stage], 45, color=MUTED, weight=500),
        rect(70, 588, 940, 1085, WHITE, 40, "#DEDCD2", 3),
        # Subtle lab-sheet grid, avoiding the oversized white card look.
        line(150, 757, 930, 757, "#ECE9DE", 2),
        line(150, 1012, 930, 1012, "#ECE9DE", 2),
        line(150, 1267, 930, 1267, "#ECE9DE", 2),
        # Beaker and water. The sample spot remains above the waterline.
        rect(190, 1264, 700, 270, "#DDF2F0"),
        rect(190, 1435, 700, 98, "#B8E3E3"),
        '<path d="M190 830 L190 1482 Q190 1535 244 1535 H836 Q890 1535 890 1482 V830" '
        'fill="none" stroke="#35524D" stroke-width="12" stroke-linecap="round"/>',
        line(175, 829, 290, 829, "#35524D", 12),
        line(790, 829, 905, 829, "#35524D", 12),
        rect(435, 640, 210, 780, "#FBF8EE", 8, "#C9CCBC", 4),
        line(445, 1185, 635, 1185, "#8A8A73", 4, "10 9"),
    ]
    if stage == 0:
        p += [
            circle(540, 1163, 30, INK),
            line(660, 1163, 760, 1163, INK, 3),
            text(672, 1117, "インク", 40),
            text(540, 1628, "●  水面より上に点を置く", 40, color=INK, anchor="middle"),
        ]
    elif stage == 1:
        p += [
            rect(445, 977, 190, 443, "#E6F5EF"),
            circle(540, 1145, 33, PURPLE),
            circle(540, 1083, 31, PINK),
            circle(540, 1023, 29, CYAN),
            line(680, 997, 780, 997, INK, 3),
            text(673, 949, "上がる水", 39),
            text(540, 1628, "↑  水と色素が紙を移動", 40, color=INK, anchor="middle"),
        ]
    else:
        p += [
            rect(445, 890, 190, 530, "#E6F5EF"),
            rect(486, 868, 108, 55, CYAN, 26),
            rect(486, 995, 108, 55, PURPLE, 26),
            rect(486, 1108, 108, 55, PINK, 26),
            line(650, 896, 735, 896, CYAN, 4),
            text(666, 856, "速い", 42, color=INK),
            line(650, 1136, 735, 1136, PINK, 4),
            text(666, 1101, "遅い", 42, color=INK),
            text(540, 1628, "色素ごとに、進む距離が違う", 40, color=INK, anchor="middle"),
        ]
    return svg(p)


def outro() -> str:
    p = header(9, dark=True)
    p += [
        text(72, 386, "見えない色を、", 102, color=WHITE),
        text(72, 519, "見つけよう。", 102, color=WHITE),
        rect(72, 695, 940, 265, LIME, 43),
        text(130, 808, "化学の続きは", 62, color=INK),
        text(130, 902, "理科子で、もう1問。", 75, color=INK),
        text(72, 1130, "アプリで1問、試してみてね。", 57, color=WHITE),
        text(72, 1650, "chemistry.rikako.org", 45, color=WHITE, weight=500),
    ]
    return svg(p)


SVG = {
    "hook": hook,
    "choices": choices,
    "three": lambda: countdown(3, 2),
    "two": lambda: countdown(2, 3),
    "one": lambda: countdown(1, 4),
    "answer": answer,
    "setup": lambda: diagram(0),
    "moving": lambda: diagram(1),
    "separated": lambda: diagram(2),
    "outro": outro,
}


def main() -> None:
    FRAMES.mkdir(parents=True, exist_ok=True)
    turtle = FRAMES / "rikako-turtle.png"
    app_icon = FRAMES / "app-icon-chemistry.png"
    run("magick", str(TURTLE), "-resize", "500x333", str(turtle))
    run("magick", str(APP_ICON), "-resize", "280x280", str(app_icon))
    for name in SCENES:
        source = FRAMES / f"{name}.svg"
        background = FRAMES / f"{name}-background.png"
        preview = FRAMES / f"{name}.png"
        source.write_text(SVG[name](), encoding="utf-8")
        if name == "hook":
            overlay = FRAMES / "hook-overlay.png"
            run("magick", "-background", "none", str(source), str(overlay))
            run("magick", str(HERO_QUESTION), "-fill", "#09251D", "-colorize", "25%",
                str(overlay), "-compose", "over", "-composite", str(background))
        elif name == "answer":
            reveal = FRAMES / "answer-photo.png"
            run("magick", str(HERO_REVEAL), "-crop", "936x390+72+900", "+repage",
                "-resize", "600x250", str(reveal))
            run("magick", "-background", "none", str(source), str(background))
            run("magick", str(background), str(reveal), "-geometry", "+70+1390",
                "-compose", "over", "-composite", str(background))
        else:
            run("magick", "-background", "none", str(source), str(background))
        if name in {"hook", "answer", "outro"}:
            run("magick", str(background), str(turtle), "-geometry", "+575+1390",
                "-compose", "over", "-composite", str(background))
        if name == "outro":
            run("magick", str(background), str(app_icon), "-geometry", "+70+1270",
                "-compose", "over", "-composite", str(background))
        shutil.copyfile(background, preview)
    run("magick", "montage", *(str(FRAMES / f"{name}.png") for name in SCENES),
        "-thumbnail", "216x384", "-tile", "5x2", "-geometry", "+8+8",
        str(ROOT / "storyboard-style-guide.png"))


if __name__ == "__main__":
    main()
