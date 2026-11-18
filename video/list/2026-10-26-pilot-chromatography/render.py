#!/usr/bin/env python3
"""Render a chemistry short with Rikako's existing standing illustration."""

from __future__ import annotations

import argparse
import html
import json
import shutil
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent
FRAMES = ROOT / "frames"
VOICE = ROOT / "voice"
OUTPUT = ROOT / "chromatography-standing-short.mp4"
MASCOT_SOURCE = ROOT.parents[1] / "assets/rikako-standing.png"
INK_WASH_SOURCE = ROOT / "assets/ink-wash.png"

INK = "#183324"
MUTED = "#4c6255"
GREEN = "#36a917"
DARK = "#257d14"
PALE = "#f2faee"
SOFT = "#e7f5df"
WHITE = "#ffffff"
BLUE = "#5ab7dc"
PINK = "#e760a1"
FONT = "Hiragino Sans"

# Name, duration, narration, show Rikako.
SCENES = [
    ("hook", 3.8, "黒い水性インク、ほんとうに一色かな？", True),
    ("choices", 4.5, "紙でインクの色を分ける方法は、どれ？", False),
    ("three", 1.0, "", False),
    ("two", 1.0, "", False),
    ("one", 1.0, "", False),
    ("answer", 3.8, "正解は、シー。ペーパークロマトグラフィー。", True),
    ("setup", 3.8, "紙の線にインクをつけて、水にひたします。", False),
    ("moving", 3.2, "水が上がると、色素も動きます。", False),
    ("separated", 3.4, "色素によって、進む速さが違います。", False),
    ("outro", 4.5, "続きは理科子で、一問解いてみてね。", True),
]


def run(*args: str) -> None:
    subprocess.run(args, check=True)


def text(x: int, y: int, value: str, size: int, *, color: str = INK,
         weight: int = 700, anchor: str = "start") -> str:
    return (f'<text x="{x}" y="{y}" text-anchor="{anchor}" '
            f'font-family="{FONT}" font-size="{size}" font-weight="{weight}" '
            f'fill="{color}">{html.escape(value)}</text>')


def rect(x: int, y: int, w: int, h: int, fill: str, radius: int = 0,
         stroke: str = "none", sw: int = 0) -> str:
    return (f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{radius}" '
            f'fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>')


def circle(x: int, y: int, radius: int, fill: str) -> str:
    return f'<circle cx="{x}" cy="{y}" r="{radius}" fill="{fill}"/>'


def base(index: int, *, dark: bool = False) -> list[str]:
    bg = GREEN if dark else PALE
    fg = WHITE if dark else INK
    bar = "#b8e7a6" if dark else SOFT
    return [
        '<svg xmlns="http://www.w3.org/2000/svg" width="1080" height="1920" viewBox="0 0 1080 1920">',
        rect(0, 0, 1080, 1920, bg),
        rect(68, 78, 92, 92, WHITE if dark else GREEN, 25),
        text(114, 143, "理", 60, color=GREEN if dark else WHITE, anchor="middle"),
        text(190, 145, "４択化学", 54, color=fg),
        rect(68, 1795, 944, 12, bar, 6),
        rect(68, 1795, round(944 * (index + 1) / len(SCENES)), 12, WHITE if dark else GREEN, 6),
        text(68, 1859, "化学基礎  |  理科子", 32, color=fg, weight=500),
    ]


def make_hook() -> str:
    p = base(0)
    p += [
        text(78, 425, "黒インクは", 106),
        text(78, 560, "本当に1色？", 106),
        text(82, 660, "紙と水で確かめてみよう", 56, color=MUTED, weight=500),
        rect(75, 805, 540, 730, WHITE, 43),
    ]
    return "".join(p) + "</svg>"


OPTIONS = [("A", "ろ過"), ("B", "蒸留"),
           ("C", "クロマトグラフィー"), ("D", "再結晶")]


def make_choices() -> str:
    p = base(1)
    p += [text(80, 375, "紙で色を分ける", 98),
          text(80, 493, "方法はどれ？", 98)]
    for i, (letter, label) in enumerate(OPTIONS):
        y = 590 + i * 235
        p += [rect(75, y, 930, 192, WHITE, 36, "#dfe9d9", 3),
              circle(185, y + 96, 65, SOFT),
              text(185, y + 118, letter, 70, anchor="middle"),
              text(295, y + 117, label, 62 if letter == "C" else 72)]
    return "".join(p) + "</svg>"


def make_countdown(number: int, index: int) -> str:
    p = base(index)
    p += [text(540, 560, "考えてみよう", 88, anchor="middle"),
          circle(540, 985, 260, GREEN),
          text(540, 1130, str(number), 420, color=WHITE, anchor="middle")]
    return "".join(p) + "</svg>"


def make_answer() -> str:
    p = base(5, dark=True)
    p += [text(82, 400, "正解は C！", 112, color=WHITE),
          rect(74, 500, 930, 365, WHITE, 45),
          text(540, 650, "ペーパー", 105, anchor="middle"),
          text(540, 790, "クロマトグラフィー", 76, anchor="middle"),
          text(82, 1030, "色素の動く速さの差で", 66, color=WHITE),
          text(82, 1125, "分けられる", 85, color=WHITE)]
    return "".join(p) + "</svg>"


def paper_diagram(index: int, title: str, subtitle: str, stage: int) -> str:
    p = base(index)
    p += [text(78, 365, title, 102),
          text(82, 466, subtitle, 54, color=MUTED, weight=500),
          rect(75, 558, 930, 1030, WHITE, 45),
          rect(200, 1100, 680, 365, "#e5f5fb", 18),
          rect(205, 1250, 670, 210, "#b9e9f7"),
          f'<path d="M200 1060 L200 1430 Q200 1465 235 1465 H845 Q880 1465 880 1430 V1060" '
          f'fill="none" stroke="{MUTED}" stroke-width="13" stroke-linecap="round"/>',
          rect(420, 620, 240, 665, "#fffdf4", 9, "#c5d5c3", 5),
          f'<path d="M430 1155 H650" stroke="{MUTED}" stroke-width="5" stroke-dasharray="11 10"/>',
          text(540, 1535, ["水に端だけひたす", "水が紙を上がる", "色素が分かれて見える"][stage],
               60, color=DARK, anchor="middle"),
    ]
    if stage == 0:
        p.append(circle(540, 1137, 31, INK))
    elif stage == 1:
        p += [rect(430, 1060, 220, 215, "#e1f5fc"),
              circle(540, 1090, 34, "#765183"),
              circle(540, 990, 29, BLUE),
              circle(540, 1035, 28, PINK)]
    else:
        p += [rect(430, 900, 220, 375, "#e1f5fc"),
              rect(477, 870, 126, 48, BLUE, 21),
              rect(477, 1010, 126, 48, PINK, 21),
              text(690, 913, "速い", 55, color=BLUE),
              text(690, 1053, "遅い", 55, color=PINK)]
    return "".join(p) + "</svg>"


def make_outro() -> str:
    p = base(9, dark=True)
    p += [text(80, 435, "見えない色を", 110, color=WHITE),
          text(80, 565, "見つけよう。", 110, color=WHITE),
          rect(80, 730, 920, 300, WHITE, 46),
          text(540, 860, "化学の続きは理科子で", 69, anchor="middle"),
          text(540, 955, "無料で1問", 80, color=DARK, anchor="middle"),
          text(80, 1510, "chemistry.rikako.org", 51, color=WHITE, weight=500)]
    return "".join(p) + "</svg>"


SVG = {
    "hook": make_hook,
    "choices": make_choices,
    "three": lambda: make_countdown(3, 2),
    "two": lambda: make_countdown(2, 3),
    "one": lambda: make_countdown(1, 4),
    "answer": make_answer,
    "setup": lambda: paper_diagram(6, "① 点をつける", "水性インクを紙の線に", 0),
    "moving": lambda: paper_diagram(7, "② 水が上がる", "色素が紙の上を移動", 1),
    "separated": lambda: paper_diagram(8, "③ 色が分かれる", "進む速さが違うから", 2),
    "outro": make_outro,
}


def graphics() -> None:
    FRAMES.mkdir(exist_ok=True)
    mascot = FRAMES / "rikako-standing.png"
    ink_wash = FRAMES / "ink-wash.png"
    run("magick", str(MASCOT_SOURCE), "-resize", "390x520", str(mascot))
    run("magick", str(INK_WASH_SOURCE), "-resize", "450x675", str(ink_wash))
    for name, _, _, show_mascot in SCENES:
        svg = FRAMES / f"{name}.svg"
        background = FRAMES / f"{name}-background.png"
        png = FRAMES / f"{name}.png"
        svg.write_text(SVG[name](), encoding="utf-8")
        run("magick", "-background", "none", str(svg), str(background))
        shutil.copyfile(background, png)
        if name == "hook":
            run("magick", str(png), str(ink_wash), "-geometry", "+120+829", "-composite", str(png))
            shutil.copyfile(png, background)
        if show_mascot:
            run("magick", str(png), str(mascot), "-geometry", "+630+1190", "-composite", str(png))
    run("magick", "montage", *(str(FRAMES / f"{name}.png") for name, *_ in SCENES),
        "-thumbnail", "216x384", "-tile", "5x2", "-geometry", "+8+8", str(ROOT / "storyboard.png"))


def voice() -> None:
    VOICE.mkdir(exist_ok=True)
    for name, _, line, _ in SCENES:
        if line:
            run("say", "-v", "Kyoko", "-r", "195", "-o", str(VOICE / f"{name}.aiff"), line)


def duration(path: Path) -> float:
    result = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "json", str(path)],
        check=True, capture_output=True, text=True,
    )
    return float(json.loads(result.stdout)["format"]["duration"])


def video() -> None:
    for name, _, line, _ in SCENES:
        if not (FRAMES / f"{name}.png").exists():
            raise SystemExit(f"Missing frame: {name}; run --graphics")
        if line and not (VOICE / f"{name}.aiff").exists():
            raise SystemExit(f"Missing voice: {name}; run --voice")

    args = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y"]
    for name, seconds, _, _ in SCENES:
        args += ["-loop", "1", "-framerate", "30", "-t", str(seconds), "-i", str(FRAMES / f"{name}.png")]
    spoken = [(i, name) for i, (name, _, line, _) in enumerate(SCENES) if line]
    for _, name in spoken:
        args += ["-i", str(VOICE / f"{name}.aiff")]

    filters = [
        f"[{i}:v]zoompan=z='min(zoom+0.00025,1.035)':"
        "x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':"
        f"d=1:s=1080x1920:fps=30,format=yuv420p,setpts=PTS-STARTPTS[v{i}]"
        for i in range(len(SCENES))
    ]
    filters.append("".join(f"[v{i}]" for i in range(len(SCENES))) + f"concat=n={len(SCENES)}:v=1:a=0[v]")
    elapsed = 0.0
    starts = []
    for _, seconds, _, _ in SCENES:
        starts.append(elapsed)
        elapsed += seconds
    for audio_index, (scene_index, name) in enumerate(spoken):
        audio_file = VOICE / f"{name}.aiff"
        available = SCENES[scene_index][1] - 0.25
        if duration(audio_file) > available:
            raise SystemExit(f"Narration {name}: {duration(audio_file):.2f}s > {available:.2f}s")
        delay_ms = round((starts[scene_index] + 0.2) * 1000)
        filters.append(f"[{len(SCENES)+audio_index}:a]aresample=48000,adelay={delay_ms}:all=1,volume=1.4[a{audio_index}]")
    filters.append("".join(f"[a{i}]" for i in range(len(spoken))) +
                   f"amix=inputs={len(spoken)}:duration=longest:normalize=0,apad=whole_dur={elapsed}[a]")
    args += ["-filter_complex", ";".join(filters), "-map", "[v]", "-map", "[a]",
             "-t", str(elapsed), "-c:v", "libx264", "-preset", "medium", "-crf", "20",
             "-pix_fmt", "yuv420p", "-r", "30", "-c:a", "aac", "-b:a", "160k",
             "-movflags", "+faststart", str(OUTPUT)]
    run(*args)
    print(OUTPUT)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--graphics", action="store_true")
    group.add_argument("--voice", action="store_true")
    group.add_argument("--video", action="store_true")
    opt = parser.parse_args()
    if opt.graphics:
        graphics()
    elif opt.voice:
        voice()
    else:
        video()
