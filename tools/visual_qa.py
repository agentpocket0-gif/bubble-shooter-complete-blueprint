#!/usr/bin/env python3
"""
Visual QA gate. Reads the screenshots the game captured in qa_proof/ and fails
the build if a screen is blank, if two screens that must differ look identical,
or if a screenshot is missing.

    python3 tools/visual_qa.py qa_proof

Uses Pillow + NumPy rather than OpenCV: the checks are mean brightness, pixel
variance and a normalised difference, none of which need cv2, and skipping it
keeps the CI image small.
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

EXPECTED = [
    "01_splash_screen.png",
    "02_saga_world_map.png",
    "03_piggy_bank_open.png",
    "04_piggy_bank_closed_back_to_map.png",
    "05_store_and_spin_wheel.png",
    "06_level_1_active_gameplay.png",
    "07_after_shot.png",
    "08_booster_activation_or_combo_pop.png",
    "09_level_win_result_popup.png",
]

MIN_BRIGHTNESS = 20.0
MIN_STDDEV = 12.0
# Fraction of pixels that must differ. A full screen change is obvious; a
# single 96 px bubble on a 1080x1920 frame is only ~0.4 %, so that pair gets a
# threshold sized to what it is actually proving.
MIN_DIFFERENCE = 0.02


def load(path: Path) -> np.ndarray:
    img = Image.open(path).convert("RGB")
    return np.asarray(img, dtype=np.float32)


def stats(a: np.ndarray) -> tuple[float, float]:
    return float(a.mean()), float(a.std())


def difference(a: np.ndarray, b: np.ndarray) -> float:
    if a.shape != b.shape:
        b = np.asarray(Image.fromarray(b.astype(np.uint8)).resize(
            (a.shape[1], a.shape[0])), dtype=np.float32)
    delta = np.abs(a - b).mean(axis=2)
    return float((delta > 12.0).mean())


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else "qa_proof")
    problems: list[str] = []
    rows: list[str] = []
    images: dict[str, np.ndarray] = {}

    for name in EXPECTED:
        path = root / name
        if not path.exists():
            problems.append(f"{name}: missing")
            continue
        a = load(path)
        mean, std = stats(a)
        images[name] = a
        rows.append(f"| {name} | {a.shape[1]}x{a.shape[0]} | {mean:.1f} | {std:.1f} |")
        if mean < MIN_BRIGHTNESS:
            problems.append(f"{name}: mean brightness {mean:.1f} < {MIN_BRIGHTNESS} (blank or black)")
        if std < MIN_STDDEV:
            problems.append(f"{name}: stddev {std:.1f} < {MIN_STDDEV} (flat image, nothing rendered)")

    pairs = [
        ("03_piggy_bank_open.png", "04_piggy_bank_closed_back_to_map.png",
         "the Close button must visibly close the popup", MIN_DIFFERENCE),
        ("02_saga_world_map.png", "06_level_1_active_gameplay.png",
         "tapping Level 1 must visibly open the board", MIN_DIFFERENCE),
        ("06_level_1_active_gameplay.png", "07_after_shot.png",
         "a shot must visibly change the board", 0.004),
        ("06_level_1_active_gameplay.png", "08_booster_activation_or_combo_pop.png",
         "activating a booster must visibly change the board", 0.004),
        ("02_saga_world_map.png", "09_level_win_result_popup.png",
         "the win popup must be its own screen", MIN_DIFFERENCE),
    ]
    pair_rows: list[str] = []
    for a_name, b_name, why, threshold in pairs:
        if a_name not in images or b_name not in images:
            continue
        d = difference(images[a_name], images[b_name])
        pair_rows.append(f"| {a_name} vs {b_name} | {d * 100:.1f}% (min {threshold * 100:.1f}%) | {why} |")
        if d < threshold:
            problems.append(f"{a_name} and {b_name} are {d * 100:.1f}% different - {why}")

    report = ["# Visual QA report", ""]
    report.append("| screenshot | size | mean brightness | stddev |")
    report.append("|---|---|---|---|")
    report.extend(rows)
    report.append("")
    report.append("| pair | pixels differing | why it matters |")
    report.append("|---|---|---|")
    report.extend(pair_rows)
    report.append("")
    if problems:
        report.append("## Result: FAILED")
        report.append("")
        for p in problems:
            report.append(f"- {p}")
    else:
        report.append("## Result: PASSED")
        report.append("")
        report.append("Every screen rendered real content, and every pair that must "
                      "differ does.")
    (root / "VISUAL_QA_REPORT.md").write_text("\n".join(report) + "\n")

    for p in problems:
        print("PROBLEM", p)
    print(f"{len(EXPECTED) - len([p for p in problems if 'missing' in p])}/{len(EXPECTED)} screenshots checked, "
          f"{len(problems)} problems")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
