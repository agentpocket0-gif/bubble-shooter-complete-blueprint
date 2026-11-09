#!/usr/bin/env python3
"""Dept 2: only original, credited project art may enter a release."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "godot_project"
OWN = PROJECT / "assets" / "own"
REGISTRY = PROJECT / "autoload" / "AssetRegistry.gd"

def main() -> int:
    if not (PROJECT / "project.godot").exists() or not REGISTRY.exists():
        print("Godot project or AssetRegistry is missing", file=sys.stderr)
        return 1
    if not OWN.exists():
        print("Original art is missing; run tools/generate_original_assets.py first", file=sys.stderr)
        return 1
    project_settings = (PROJECT / "project.godot").read_text(encoding="utf-8")
    if 'config/icon="res://assets/own/ui/app_icon.svg"' not in project_settings:
        print("Original launcher icon is not configured", file=sys.stderr)
        return 1
    if not (OWN / "ui" / "app_icon.svg").is_file():
        print("Original launcher icon artwork is missing", file=sys.stderr)
        return 1
    registry = REGISTRY.read_text(encoding="utf-8")
    if "real_pack" in registry:
        print("ERROR: AssetRegistry refers to the non-publishable extracted asset pack", file=sys.stderr)
        return 1
    relative_assets = re.findall(r'ROOT\s*\+\s*"([^"]+)"', registry)
    missing = [rel for rel in relative_assets if not (OWN / rel).is_file()]
    for frame in range(1, 9):
        rel = f"effects/pop_{frame:02d}.svg"
        if not (OWN / rel).is_file():
            missing.append(rel)
    if missing:
        print("Missing registry assets: " + ", ".join(missing), file=sys.stderr)
        return 1
    if not (ROOT / "ASSET_CREDITS.md").exists():
        print("ASSET_CREDITS.md is missing", file=sys.stderr)
        return 1
    code = "\n".join(path.read_text(encoding="utf-8", errors="ignore") for path in PROJECT.rglob("*.gd"))
    if "res://assets/real_pack/" in code or "draw_circle(" in code or "AudioStreamGenerator" in code:
        print("Forbidden reference asset or placeholder drawing/audio found in game scripts", file=sys.stderr)
        return 1
    if "ads_enabled = true" in code or "iap_enabled = true" in code:
        print("Monetization must remain off until SDK and compliance integration is complete", file=sys.stderr)
        return 1
    print(f"Asset audit passed: {len(list(OWN.rglob('*.svg')))} authored SVGs; no extracted assets in runtime.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
