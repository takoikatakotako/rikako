#!/usr/bin/env python3
"""Export one WAV per voice from Daihon's generated audio cache."""

import json
import shutil
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent
VOICES = ("Kore", "Leda", "Achernar", "Aoede", "Zephyr", "Sulafat")


def main() -> None:
    output = ROOT / "out"
    output.mkdir(exist_ok=True)
    for number, voice in enumerate(VOICES, start=1):
        result = subprocess.run(
            ["daihon", "timeline", "-f", "movie.yml", "-scene", voice.lower(), "-o", "-"],
            cwd=ROOT,
            check=True,
            capture_output=True,
            text=True,
        )
        tracks = json.loads(result.stdout)["tracks"]
        events = next(track["events"] for track in tracks if track["type"] == "voice")
        if len(events) != 1:
            raise ValueError(f"Expected one voice clip for {voice}, got {len(events)}")
        source = ROOT / events[0]["src"]
        destination = output / f"{number:02d}-{voice}.wav"
        shutil.copy2(source, destination)
        print(f"{voice}: {destination.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
