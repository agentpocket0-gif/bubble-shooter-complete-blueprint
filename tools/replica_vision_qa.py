#!/usr/bin/env python3
"""Dept 6: OpenCV screenshot integrity and state-difference checks, plus optional vision."""
from __future__ import annotations
import base64
import json
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
QA = ROOT / "qa_proof"
NAMES = [
    "01_splash_screen.png", "02_intro_screen.png", "03_loading_screen.png",
    "04_mode_select_screen.png", "05_saga_world_map.png", "06_settings_popup.png",
    "07_booster_shop_popup.png", "08_daily_spin_popup.png", "09_piggy_bank_popup.png",
    "10_events_popup.png", "11_level_1_gameplay.png", "12_level_1_aim_preview.png",
    "13_projectile_shot.png", "14_booster_and_pop_effects.png", "15_pause_overlay.png",
    "16_level_win_result.png", "17_level_lose_result.png"
]

def main() -> int:
    try:
        import cv2
    except ImportError as exc:
        print(f"OpenCV not installed: {exc}", file=sys.stderr)
        return 2
    report = ["# Six-Department Studio: Replica Vision QA", "", "## Screenshot integrity"]
    errors: list[str] = []
    loaded = []
    for name in NAMES:
        path = QA / name
        img = cv2.imread(str(path), cv2.IMREAD_COLOR)
        if img is None:
            errors.append(f"Missing or unreadable screenshot: {name}")
            continue
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        mean, deviation = float(gray.mean()), float(gray.std())
        if mean < 3.0 or deviation < 5.0:
            errors.append(f"Blank, black, or nearly uniform screenshot: {name}")
        if img.shape[1] < 720 or img.shape[0] < 1280:
            errors.append(f"Screenshot below full-HD mobile proof size: {name} ({img.shape[1]}x{img.shape[0]})")
        loaded.append((name, img))
        report.append(f"- {name}: {img.shape[1]}x{img.shape[0]}, mean={mean:.1f}, std={deviation:.1f}")
    report.extend(["", "## State transition visual differences"])
    differences = []
    for (name_a, a), (name_b, b) in zip(loaded, loaded[1:]):
        if a.shape != b.shape:
            b = cv2.resize(b, (a.shape[1], a.shape[0]))
        delta = float(cv2.absdiff(a, b).mean())
        differences.append({"from": name_a, "to": name_b, "mean_absolute_difference": round(delta, 4)})
        report.append(f"- {name_a} -> {name_b}: mean pixel difference {delta:.2f}")
        if delta < 0.35:
            errors.append(f"Adjacent screenshots appear nearly identical: {name_a}, {name_b}")
    report.extend(["", "## Optional multimodal vision inspection"])
    vision_configured = bool(os.environ.get("GEMINI_API_KEY") or os.environ.get("NVIDIA_API_KEY"))
    if vision_configured:
        try:
            from llm_router import LLMRouter
            router = LLMRouter()
            sample = QA / "16_level_win_result.png"
            prompt = ("Inspect this screenshot of the current mobile bubble puzzle game rebuild. "
                      "List only clear visual defects: blank areas, clipped text, missing controls, "
                      "overlapping panels, or a result state that is not visible. Do not identify another game.")
            answer = router.complete(prompt, purpose="vision", image_b64=base64.b64encode(sample.read_bytes()).decode("ascii"))
            report.append(answer[:3000])
        except Exception as exc:
            report.append("Remote multimodal review unavailable; OpenCV checks remain the automated visual gate. " + str(exc))
    else:
        report.append("No provider key configured. OpenCV integrity checks ran; multimodal review was skipped.")
    report.extend(["", "## Result", "", "PASS" if not errors else "FAIL"])
    if errors:
        report.extend(["", "### Errors"] + [f"- {item}" for item in errors])
    QA.mkdir(parents=True, exist_ok=True)
    (QA / "STUDIO_6DEPT_VISION_REPORT.md").write_text("\n".join(report) + "\n", encoding="utf-8")
    (QA / "replica_vision_report.json").write_text(json.dumps({"passed": not errors, "errors": errors, "differences": differences}, indent=2) + "\n", encoding="utf-8")
    print("\n".join(report))
    return 1 if errors else 0

if __name__ == "__main__":
    raise SystemExit(main())
