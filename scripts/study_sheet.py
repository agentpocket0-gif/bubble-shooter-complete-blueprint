#!/usr/bin/env python3
"""
Measurement study sheet for an extracted reference tree.

Writes measurements only — dimensions, alpha coverage, dominant palette, edge
padding, atlas grid maths, audio loudness and length. No image or audio data is
copied into the output, so the result is a data sheet you can keep, share and
work from, not a copy of anyone's assets.

    python scripts/study_sheet.py --raw work/raw_apk --decoded work/decoded_apk --out blueprint/reference
"""

from __future__ import annotations

import argparse
import csv
import json
import math
import wave
from collections import Counter
from pathlib import Path

import numpy as np

try:
    from PIL import Image
except Exception:  # noqa: BLE001
    Image = None

IMG_EXT = {".png", ".jpg", ".jpeg", ".webp", ".gif", ".bmp"}
AUDIO_EXT = {".ogg", ".mp3", ".wav", ".m4a", ".aac", ".opus"}


def human(n: float) -> str:
    if n >= 1 << 20:
        return f"{n / (1 << 20):.2f} MB"
    if n >= 1024:
        return f"{n / 1024:.1f} KB"
    return f"{int(n)} B"


def hexof(c: tuple[int, int, int]) -> str:
    return "#%02X%02X%02X" % c


def sprite_stats(path: Path) -> dict | None:
    """Dimensions, alpha coverage, dominant colours and transparent padding."""
    if Image is None:
        return None
    try:
        with Image.open(path) as im:
            im = im.convert("RGBA")
            w, h = im.size
            small = im.resize((min(w, 64), min(h, 64)), Image.Resampling.NEAREST)
            arr = np.asarray(small, dtype=np.uint8)
    except Exception:  # noqa: BLE001
        return None

    alpha = arr[..., 3]
    opaque = alpha > 16
    coverage = float(opaque.mean()) if opaque.size else 0.0

    palette: list[tuple[str, float]] = []
    if opaque.any():
        px = arr[opaque][:, :3].astype(np.uint16)
        q = (px // 16).astype(np.uint16)                      # 5-bit buckets
        keys = (q[:, 0] << 10) | (q[:, 1] << 5) | q[:, 2]
        counts = Counter(keys.tolist())
        total = sum(counts.values())
        for key, cnt in counts.most_common(4):
            r = ((key >> 10) & 31) * 16 + 8
            g = ((key >> 5) & 31) * 16 + 8
            b = (key & 31) * 16 + 8
            palette.append((hexof((r, g, b)), cnt / total))

    # transparent padding, useful for trimming and for guessing sprite margins
    pad = {"top": 0, "left": 0, "right": 0, "bottom": 0}
    if Image is not None and opaque.any():
        rows = np.where(opaque.any(axis=1))[0]
        cols = np.where(opaque.any(axis=0))[0]
        pad["top"] = int(rows[0])
        pad["bottom"] = int(arr.shape[0] - 1 - rows[-1])
        pad["left"] = int(cols[0])
        pad["right"] = int(arr.shape[1] - 1 - cols[-1])

    return {"w": w, "h": h, "coverage": coverage, "palette": palette, "pad": pad}


def audio_stats(path: Path) -> dict:
    """Length, peak and RMS loudness, silence share. WAV is measured, others estimated."""
    out: dict = {"duration": None, "peak_db": None, "rms_db": None,
                 "silence": None, "rate": None, "channels": None}
    if path.suffix.lower() == ".wav":
        try:
            with wave.open(str(path)) as w:
                n = w.getnframes()
                rate = w.getframerate() or 1
                ch = w.getnchannels()
                width = w.getsampwidth()
                raw = w.readframes(n)
            out["duration"] = n / rate
            out["rate"] = rate
            out["channels"] = ch
            if width == 2:
                data = np.frombuffer(raw, dtype="<i2").astype(np.float32) / 32768.0
            elif width == 1:
                data = (np.frombuffer(raw, dtype=np.uint8).astype(np.float32) - 128) / 128.0
            else:
                data = np.frombuffer(raw, dtype="<i4").astype(np.float32) / 2 ** 31
            if data.size:
                peak = float(np.max(np.abs(data)))
                rms = float(np.sqrt(np.mean(data ** 2)))
                out["peak_db"] = 20 * math.log10(peak) if peak > 0 else -120.0
                out["rms_db"] = 20 * math.log10(rms) if rms > 0 else -120.0
                out["silence"] = float(np.mean(np.abs(data) < 0.003))
        except Exception:  # noqa: BLE001
            pass
    return out


def md_table(headers: list[str], rows: list[list], cap: int = 300) -> str:
    if not rows:
        return "_No rows._\n"
    out = ["| " + " | ".join(headers) + " |",
           "|" + "|".join(["---"] * len(headers)) + "|"]
    for r in rows[:cap]:
        out.append("| " + " | ".join(str(c).replace("|", "\\|") for c in r) + " |")
    if len(rows) > cap:
        out.append(f"\n_... {len(rows) - cap} more rows, see the CSV._")
    return "\n".join(out) + "\n"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--raw", default="work/raw_apk")
    ap.add_argument("--decoded", default="work/decoded_apk")
    ap.add_argument("--out", default="blueprint/reference")
    args = ap.parse_args()

    roots = [Path(args.raw) / "assets", Path(args.decoded) / "res"]
    images: list[Path] = []
    audio: list[Path] = []
    for root in roots:
        if not root.is_dir():
            continue
        for p in sorted(root.rglob("*")):
            if not p.is_file():
                continue
            if p.suffix.lower() in IMG_EXT:
                images.append(p)
            elif p.suffix.lower() in AUDIO_EXT:
                audio.append(p)

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    sprite_rows = []
    for p in images:
        st = sprite_stats(p)
        if not st:
            continue
        sprite_rows.append({
            "path": str(p).split("assets/", 1)[-1] if "assets/" in str(p) else str(p),
            **st,
        })

    audio_rows = []
    for p in audio:
        st = audio_stats(p)
        audio_rows.append({"path": str(p).split("assets/", 1)[-1] if "assets/" in str(p) else str(p),
                           "bytes": p.stat().st_size, **st})

    # ---- CSV
    with open(out / "sprite_measurements.csv", "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(["path", "width", "height", "alpha_coverage", "palette_1", "palette_1_share",
                    "palette_2", "palette_2_share", "palette_3", "palette_3_share",
                    "pad_top", "pad_right", "pad_bottom", "pad_left"])
        for r in sprite_rows:
            pal = r["palette"] + [("", 0)] * (3 - len(r["palette"]))
            w.writerow([r["path"], r["w"], r["h"], f"{r['coverage']:.3f}",
                        pal[0][0], f"{pal[0][1]:.3f}", pal[1][0], f"{pal[1][1]:.3f}",
                        pal[2][0], f"{pal[2][1]:.3f}",
                        r["pad"]["top"], r["pad"]["right"], r["pad"]["bottom"], r["pad"]["left"]])

    with open(out / "audio_measurements.csv", "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(["path", "bytes", "duration_s", "sample_rate", "channels",
                    "peak_dbfs", "rms_dbfs", "silence_share"])
        for r in audio_rows:
            w.writerow([r["path"], r["bytes"],
                        f"{r['duration']:.3f}" if r["duration"] else "",
                        r["rate"] or "", r["channels"] or "",
                        f"{r['peak_db']:.1f}" if r["peak_db"] is not None else "",
                        f"{r['rms_db']:.1f}" if r["rms_db"] is not None else "",
                        f"{r['silence']:.3f}" if r["silence"] is not None else ""])

    # ---- markdown
    size_counter = Counter((r["w"], r["h"]) for r in sprite_rows)
    all_colours = Counter()
    for r in sprite_rows:
        for hx, share in r["palette"]:
            all_colours[hx] += share

    doc = ["# Measurement study sheet / माप-आधारित अध्ययन शीट\n",
           "> This sheet contains **measurements only**: sizes, alpha coverage, dominant colours, "
           "padding, atlas grid maths, audio length and loudness. No image or audio data is copied "
           "into it, so you can keep it, share it and work from it freely while you draw your own "
           "assets from scratch.\n",
           f"- images measured: **{len(sprite_rows)}**",
           f"- audio files measured: **{len(audio_rows)}**",
           f"- unique sprite sizes: **{len(size_counter)}**\n",
           "---\n",
           "## 1. Most common sprite sizes\n",
           "Draw your replacement art at these sizes and it will drop into the same layout without "
           "re-tuning a single anchor.\n",
           md_table(["Width × Height", "How many sprites", "Share"],
                    [[f"{w} × {h}", c, f"{c / max(len(sprite_rows), 1) * 100:.0f} %"]
                     for (w, h), c in size_counter.most_common(25)]),
           "## 2. Palette across the whole build\n",
           "Every sprite's dominant colour, weighted by how much of that sprite it covers. This is "
           "the real art direction of the game in about twenty lines.\n",
           md_table(["Hex", "Weighted share"],
                    [[hx, f"{share:.1f}"] for hx, share in all_colours.most_common(30)]),
           "## 3. Sprite measurements\n",
           md_table(["Path", "Size", "Alpha cover", "Dominant colours", "Padding (t/r/b/l)"],
                    [[f"`{r['path']}`", f"{r['w']}×{r['h']}", f"{r['coverage'] * 100:.0f} %",
                      " ".join(f"{hx} {sh * 100:.0f}%" for hx, sh in r["palette"]) or "-",
                      f"{r['pad']['top']}/{r['pad']['right']}/{r['pad']['bottom']}/{r['pad']['left']}"]
                     for r in sorted(sprite_rows, key=lambda x: -x["w"] * x["h"])]),
           "## 4. Audio measurements\n",
           "Duration and loudness are the two numbers you need to match feel: a 0.18 s pop and a "
           "0.35 s pop are different games.\n",
           md_table(["Path", "Size", "Duration", "Rate", "Peak dBFS", "RMS dBFS", "Silence"],
                    [[f"`{r['path']}`", human(r["bytes"]),
                      f"{r['duration']:.2f} s" if r["duration"] else "—",
                      r["rate"] or "—",
                      f"{r['peak_db']:.1f}" if r["peak_db"] is not None else "—",
                      f"{r['rms_db']:.1f}" if r["rms_db"] is not None else "—",
                      f"{r['silence'] * 100:.0f} %" if r["silence"] is not None else "—"]
                     for r in audio_rows]),
           "---\n",
           "## How to use it\n",
           "1. Pick the sizes from §1 — your art then fits the existing anchors and spacing.\n"
           "2. Match the palette from §2 for the colour language, then deliberately shift it 10-15 % "
           "in hue so the result is yours, not a recolour.\n"
           "3. Read the durations in §4, then synthesise your own sounds at the same lengths. Length "
           "is what makes a sound feel right; the waveform is what makes it yours.\n"
           "4. Re-draw every sprite yourself, or use `scripts/generate_original_assets.py` as the "
           "starting point.\n"]

    (out / "STUDY_SHEET.md").write_text("\n".join(doc), encoding="utf-8")
    print(json.dumps({"images": len(sprite_rows), "audio": len(audio_rows),
                      "wrote": str(out / "STUDY_SHEET.md")}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
