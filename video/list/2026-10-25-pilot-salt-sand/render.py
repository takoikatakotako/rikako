#!/usr/bin/env python3
"""Render a 30-second, 1080x1920 Japanese chemistry short.

Run `python3 render.py --graphics`, then `python3 render.py --voice` on a
machine with macOS Japanese speech, then `python3 render.py --video`.
Use `python3 render.py --mix-bgm` to make two BGM comparison exports.
"""

from __future__ import annotations

import argparse
import html
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent
FRAMES = ROOT / "frames"
VOICE = ROOT / "voice"
OUTPUT = ROOT / "salt-sand-short.mp4"
BGM_DIR = ROOT.parents[1] / "assets" / "bgm"
BGM_LEAD_IN_SECONDS = 1.0
BGM_TRACKS = {
    # Gains bring the first 30 seconds of both source tracks to about -32 dB mean.
    "hiyoko": ("bgmer-hiyoko-no-bouken-short.mp3", -12),
    "happy-create": ("bgmer-happy-create-short.mp3", -19),
}

INK = "#1d2a16"
BODY = "#41513a"
GREEN = "#48ac01"
DARK = "#348500"
PALE = "#f4fbef"
SOFT = "#eaf6e0"
BLUE = "#84cce8"
SAND = "#d7aa6b"
WHITE = "#ffffff"
FONT = "Hiragino Sans"

SCENES = [
    ("hook", 4.0, "食塩と砂。食塩だけを取り出すには？"),
    ("choices", 4.5, "正しいのはどれ？"),
    ("three", 1.0, ""),
    ("two", 1.0, ""),
    ("one", 1.0, ""),
    ("answer", 2.5, "正解は、B。"),
    ("dissolve", 4.5, "まず水に溶かす。食塩は溶けて、砂は残ります。"),
    ("filter", 3.5, "ろ過して、砂を取り除きます。"),
    ("evaporate", 4.0, "水を蒸発させれば、食塩だけが残ります。"),
    ("outro", 4.0, "続きは、プロフィールから無料で一問どうぞ。"),
]


def run(*args: str) -> None:
    subprocess.run(args, check=True)


def txt(x: int, y: int, value: str, size: int, *, color: str = INK,
        weight: int = 700, anchor: str = "start") -> str:
    return (f'<text x="{x}" y="{y}" text-anchor="{anchor}" '
            f'font-family="{FONT}" font-size="{size}" font-weight="{weight}" '
            f'fill="{color}">{html.escape(value)}</text>')


def rect(x: int, y: int, w: int, h: int, fill: str, radius: int = 0,
         stroke: str = "none", sw: int = 0) -> str:
    return (f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{radius}" '
            f'fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>')


def circle(x: int, y: int, r: int, fill: str, stroke: str = "none", sw: int = 0) -> str:
    return (f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}" '
            f'stroke="{stroke}" stroke-width="{sw}"/>')


def base(*, dark: bool = False) -> list[str]:
    bg = GREEN if dark else PALE
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="1080" height="1920" viewBox="0 0 1080 1920">',
             rect(0, 0, 1080, 1920, bg)]
    return parts


def particles(parts: list[str], *, x: int, y: int, scale: float = 1.0) -> None:
    salt = [(0, 0), (76, 15), (141, -8), (43, 83), (131, 91), (195, 55)]
    sand = [(31, 155), (96, 178), (167, 153), (210, 182), (62, 235), (142, 227)]
    for dx, dy in salt:
        parts.append(rect(round(x + dx * scale), round(y + dy * scale),
                          round(27 * scale), round(27 * scale), WHITE, 3, DARK, 4))
    for dx, dy in sand:
        parts.append(circle(round(x + dx * scale), round(y + dy * scale),
                            round(16 * scale), SAND))


def beaker(parts: list[str], *, water: bool = False, x: int = 245, y: int = 750) -> None:
    parts.append(rect(x + 30, y + 208, 530, 445, "#e8f7fd" if water else WHITE, 20))
    if water:
        parts.append(rect(x + 37, y + 340, 516, 306, BLUE, 0))
    parts.append(f'<path d="M{x + 20} {y + 185} L{x + 20} {y + 640} Q{x + 20} {y + 680} {x + 65} {y + 680} L{x + 525} {y + 680} Q{x + 570} {y + 680} {x + 570} {y + 640} L{x + 570} {y + 185}" fill="none" stroke="{BODY}" stroke-width="14" stroke-linecap="round"/>')
    parts.append(f'<path d="M{x - 4} {y + 184} H{x + 595}" stroke="{BODY}" stroke-width="14" stroke-linecap="round"/>')


def make_hook() -> str:
    p = base()
    p += [txt(78, 450, "食塩と砂、", 112), txt(78, 585, "どう分ける？", 112),
          txt(80, 683, "食塩だけ取り出したい。", 58, color=BODY, weight=500),
          rect(108, 790, 864, 760, WHITE, 48)]
    beaker(p, x=235, y=730)
    particles(p, x=393, y=1030, scale=1.25)
    p += [rect(302, 1467, 38, 38, WHITE, 4, DARK, 4),
          txt(355, 1506, "食塩", 52, color=BODY),
          circle(603, 1486, 20, SAND),
          txt(640, 1506, "砂", 52, color=BODY)]
    return "".join(p) + "</svg>"


OPTIONS = [("A", "磁石で集める"), ("B", "水→ろ過→蒸発"),
           ("C", "そのまま加熱"), ("D", "冷やして分ける")]


def option_card(letter: str, label: str, y: int, *, correct: bool = False) -> str:
    stroke = GREEN if correct else "#e4ebdf"
    fill = SOFT if correct else WHITE
    return (rect(82, y, 916, 185, fill, 36, stroke, 5 if correct else 2)
            + circle(190, y + 92, 62, GREEN if correct else "#eff3eb")
            + txt(190, y + 112, letter, 62, color=WHITE if correct else INK, anchor="middle")
            + txt(294, y + 112, label, 64, color=INK))


def make_choices(*, countdown: int | None = None) -> str:
    p = base()
    p += [txt(82, 398, "どれを選ぶ？", 102),
          txt(84, 481, "考えてから答えを見てね", 47, color=BODY, weight=500)]
    for i, (letter, label) in enumerate(OPTIONS):
        p.append(option_card(letter, label, 550 + i * 220))
    if countdown is not None:
        p += [circle(868, 168, 112, GREEN),
              txt(868, 212, str(countdown), 132, color=WHITE, anchor="middle")]
    return "".join(p) + "</svg>"


def make_countdown(number: int) -> str:
    return make_choices(countdown=number)


def make_answer() -> str:
    p = base(dark=True)
    p += [txt(82, 450, "正解は", 100, color=WHITE),
          txt(82, 765, "B", 320, color=WHITE),
          rect(78, 910, 924, 262, WHITE, 42),
          txt(540, 1075, "水 → ろ過 → 蒸発", 65, anchor="middle"),
          txt(84, 1330, "水に溶ける性質を", 67, color=WHITE),
          txt(84, 1422, "利用するよ", 67, color=WHITE)]
    return "".join(p) + "</svg>"


def step_header(number: str, headline: str, sub: str) -> list[str]:
    p = base()
    p += [circle(126, 392, 60, GREEN),
          txt(126, 413, number, 55, color=WHITE, anchor="middle"),
          txt(214, 416, headline, 91),
          txt(83, 515, sub, 53, color=BODY, weight=500),
          rect(88, 638, 904, 894, WHITE, 48)]
    return p


def make_dissolve() -> str:
    p = step_header("1", "水に溶かす", "食塩は溶ける。砂は溶けない。")
    beaker(p, water=True, x=230, y=635)
    for x, y in [(380, 1100), (530, 1130), (660, 1060), (470, 1220)]:
        p.append(circle(x, y, 16, WHITE))
    for x, y in [(380, 1257), (430, 1262), (520, 1259), (590, 1262), (670, 1257)]:
        p.append(circle(x, y, 17, SAND))
    p += [txt(540, 1460, "砂は底に残る", 59, color=BODY, anchor="middle")]
    return "".join(p) + "</svg>"


def make_filter() -> str:
    p = step_header("2", "ろ過する", "溶けない砂だけを取り除く。")
    # The receiving beaker sits behind the funnel stem.
    p += [rect(387, 1275, 306, 120, "#d9f3fc", 15),
          f'<path d="M375 1150 V1378 Q375 1412 409 1412 H671 Q705 1412 705 1378 V1150" fill="none" stroke="{BODY}" stroke-width="11" stroke-linecap="round"/>',
          f'<path d="M355 1150 H388 M692 1150 H725" fill="none" stroke="{BODY}" stroke-width="11" stroke-linecap="round"/>',
          f'<path d="M268 800 H812 L558 1080 V1185 H522 V1080 Z" fill="#e8f7fd" stroke="{BODY}" stroke-width="11" stroke-linejoin="round"/>',
          f'<path d="M320 850 Q540 874 760 850 L540 1035 Z" fill="{WHITE}" stroke="#91a596" stroke-width="7" stroke-linejoin="round"/>']
    for x, y in [(483, 941), (520, 968), (557, 953), (588, 935), (540, 996)]:
        p.append(circle(x, y, 15, SAND))
    p += [circle(540, 1218, 10, BLUE), circle(540, 1253, 8, BLUE),
          txt(540, 1492, "ろ紙に砂が残る", 55, color=BODY, anchor="middle")]
    return "".join(p) + "</svg>"


def make_evaporate() -> str:
    p = step_header("3", "水を蒸発", "残った液体から水を飛ばす。")
    for x in [390, 540, 690]:
        p.append(f'<path d="M{x} 960 C{x-55} 900 {x+55} 845 {x} 780" fill="none" stroke="{BLUE}" stroke-width="13" stroke-linecap="round"/>')
    # Tripod and alcohol lamp make the heating step explicit.
    p += [f'<path d="M340 1188 H740 M365 1190 L320 1400 M715 1190 L760 1400" fill="none" stroke="{BODY}" stroke-width="13" stroke-linecap="round" stroke-linejoin="round"/>',
          rect(475, 1320, 130, 88, "#eef5e9", 24, BODY, 10),
          rect(505, 1292, 70, 36, WHITE, 8, BODY, 8),
          f'<path d="M540 1295 C510 1270 521 1230 540 1205 C559 1230 570 1270 540 1295 Z" fill="#f4c17e" stroke="#d98236" stroke-width="7"/>',
          f'<path d="M270 1050 Q540 1190 810 1050 Z" fill="#eef5e9" stroke="{BODY}" stroke-width="10" stroke-linejoin="round"/>',
          f'<ellipse cx="540" cy="1048" rx="270" ry="56" fill="{SOFT}" stroke="{BODY}" stroke-width="10"/>']
    for x, y in [(420, 1036), (480, 1060), (548, 1028), (612, 1052), (676, 1035)]:
        p.append(rect(x, y, 33, 33, WHITE, 3, DARK, 5))
    p.append(txt(540, 1492, "食塩が残る！", 66, color=DARK, anchor="middle"))
    return "".join(p) + "</svg>"


def make_outro() -> str:
    p = base(dark=True)
    p += [txt(80, 510, "1問から、", 111, color=WHITE),
          txt(80, 652, "化学を得意に。", 111, color=WHITE),
          rect(80, 835, 920, 388, WHITE, 48),
          txt(540, 978, "続きも無料で解ける", 70, anchor="middle"),
          txt(540, 1113, "プロフィールのリンクから", 57, color=DARK, anchor="middle"),
          txt(540, 1418, "４択化学", 104, color=WHITE, anchor="middle"),
          txt(540, 1500, "chemistry.rikako.org", 44, color=WHITE, weight=500, anchor="middle")]
    return "".join(p) + "</svg>"


SVG = {
    "hook": make_hook,
    "choices": make_choices,
    "three": lambda: make_countdown(3),
    "two": lambda: make_countdown(2),
    "one": lambda: make_countdown(1),
    "answer": make_answer,
    "dissolve": make_dissolve,
    "filter": make_filter,
    "evaporate": make_evaporate,
    "outro": make_outro,
}


def graphics() -> None:
    FRAMES.mkdir(exist_ok=True)
    for name, _, _ in SCENES:
        svg = FRAMES / f"{name}.svg"
        png = FRAMES / f"{name}.png"
        svg.write_text(SVG[name](), encoding="utf-8")
        run("magick", "-background", "none", str(svg), str(png))


def voice() -> None:
    VOICE.mkdir(exist_ok=True)
    for name, _, line in SCENES:
        if line:
            run("say", "-v", "Kyoko", "-r", "190", "-o", str(VOICE / f"{name}.aiff"), line)


def duration(path: Path) -> float:
    result = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "json", str(path)],
        check=True, capture_output=True, text=True,
    )
    return float(json.loads(result.stdout)["format"]["duration"])


def video() -> None:
    for name, _, line in SCENES:
        if not (FRAMES / f"{name}.png").exists():
            raise SystemExit(f"Missing frame: {name}; run --graphics first")
        if line and not (VOICE / f"{name}.aiff").exists():
            raise SystemExit(f"Missing narration: {name}; run --voice first")

    args = ["ffmpeg", "-hide_banner", "-y"]
    for name, seconds, _ in SCENES:
        args += ["-loop", "1", "-framerate", "30", "-t", str(seconds), "-i", str(FRAMES / f"{name}.png")]
    spoken = [(i, name, line) for i, (name, _, line) in enumerate(SCENES) if line]
    for _, name, _ in spoken:
        args += ["-i", str(VOICE / f"{name}.aiff")]

    filters = [
        f"[{i}:v]zoompan=z='min(zoom+0.00025,1.035)':"
        "x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':"
        f"d=1:s=1080x1920:fps=30,format=yuv420p,setpts=PTS-STARTPTS[v{i}]"
        for i in range(len(SCENES))
    ]
    filters.append("".join(f"[v{i}]" for i in range(len(SCENES))) + f"concat=n={len(SCENES)}:v=1:a=0[v]")
    starts: list[float] = []
    elapsed = 0.0
    for _, seconds, _ in SCENES:
        starts.append(elapsed)
        elapsed += seconds
    for audio_index, (scene_index, name, _) in enumerate(spoken):
        audio_file = VOICE / f"{name}.aiff"
        available = SCENES[scene_index][1] - 0.35
        if duration(audio_file) > available:
            raise SystemExit(f"Narration for {name} is {duration(audio_file):.2f}s; only {available:.2f}s available")
        delay_ms = round((starts[scene_index] + 0.22) * 1000)
        filters.append(f"[{len(SCENES)+audio_index}:a]aresample=48000,adelay={delay_ms}:all=1,volume=1.4[a{audio_index}]")
    filters.append("".join(f"[a{i}]" for i in range(len(spoken))) +
                   f"amix=inputs={len(spoken)}:duration=longest:normalize=0,apad=whole_dur={elapsed}[a]")

    args += ["-filter_complex", ";".join(filters), "-map", "[v]", "-map", "[a]",
             "-t", str(elapsed), "-c:v", "libx264", "-preset", "medium", "-crf", "20",
             "-pix_fmt", "yuv420p", "-r", "30", "-c:a", "aac", "-b:a", "160k",
             "-movflags", "+faststart", str(OUTPUT)]
    run(*args)
    print(OUTPUT)


def mix_bgm() -> None:
    if not OUTPUT.exists():
        raise SystemExit(f"Missing base video: {OUTPUT}; run --video first")
    total_seconds = sum(seconds for _, seconds, _ in SCENES)
    output_seconds = total_seconds + BGM_LEAD_IN_SECONDS
    for name, (filename, gain_db) in BGM_TRACKS.items():
        source = BGM_DIR / filename
        if not source.exists():
            raise SystemExit(f"Missing BGM: {source}")
        if duration(source) < output_seconds:
            raise SystemExit(f"BGM is shorter than the video: {source}")
        destination = ROOT / f"salt-sand-{name}.mp4"
        filters = (
            f"[0:v]tpad=start_mode=clone:start_duration={BGM_LEAD_IN_SECONDS}[v];"
            f"[0:a]adelay={round(BGM_LEAD_IN_SECONDS * 1000)}:all=1[voice];"
            f"[1:a]atrim=duration={output_seconds},asetpts=PTS-STARTPTS,"
            f"aresample=48000,volume={gain_db}dB,"
            f"afade=t=in:st=0:d=0.5,"
            f"afade=t=out:st={output_seconds - 1.5}:d=1.5[bgm];"
            "[voice][bgm]amix=inputs=2:duration=first:normalize=0[a]"
        )
        run("ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
            "-i", str(OUTPUT), "-i", str(source),
            "-filter_complex", filters,
            "-map", "[v]", "-map", "[a]",
            "-t", str(output_seconds),
            "-c:v", "libx264", "-preset", "medium", "-crf", "20",
            "-pix_fmt", "yuv420p", "-r", "30",
            "-c:a", "aac", "-b:a", "160k", "-ar", "48000",
            "-movflags", "+faststart", str(destination))
        print(destination)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--graphics", action="store_true")
    group.add_argument("--voice", action="store_true")
    group.add_argument("--video", action="store_true")
    group.add_argument("--mix-bgm", action="store_true")
    opt = parser.parse_args()
    if opt.graphics:
        graphics()
    elif opt.voice:
        voice()
    elif opt.video:
        video()
    else:
        mix_bgm()
