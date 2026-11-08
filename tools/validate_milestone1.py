#!/usr/bin/env python3
"""Static checks for the Godot Milestone 1 project foundation."""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "godot_project"

REQUIRED_FILES = [
    PROJECT / "project.godot",
    PROJECT / "GODOT_VERSION",
    PROJECT / "export_presets.cfg",
    PROJECT / "scenes/bootstrap/Splash.tscn",
    PROJECT / "scripts/ui/bootstrap_splash.gd",
    PROJECT / "scripts/core/game_manager.gd",
    PROJECT / "scripts/core/save_manager.gd",
    PROJECT / "scripts/core/asset_registry.gd",
    PROJECT / "scripts/core/audio_manager.gd",
    PROJECT / "assets/manifest.json",
]

ERRORS: list[str] = []

for path in REQUIRED_FILES:
    if not path.is_file():
        ERRORS.append(f"Missing required file: {path.relative_to(ROOT)}")

if ERRORS:
    print("\n".join(ERRORS))
    sys.exit(1)

project_text = (PROJECT / "project.godot").read_text(encoding="utf-8")
required_settings = [
    'config/name="Bubble Shooter: Classic Blast"',
    'run/main_scene="res://scenes/bootstrap/Splash.tscn"',
    'run/max_fps=60',
    'config/features=PackedStringArray("4.7", "GL Compatibility")',
    "window/size/viewport_width=1080",
    "window/size/viewport_height=1920",
    'window/stretch/mode="canvas_items"',
    "window/handheld/orientation=1",
    'GameManager="*res://scripts/core/game_manager.gd"',
    'SaveManager="*res://scripts/core/save_manager.gd"',
    'AssetRegistry="*res://scripts/core/asset_registry.gd"',
    'AudioManager="*res://scripts/core/audio_manager.gd"',
]
for setting in required_settings:
    if setting not in project_text:
        ERRORS.append(f"Missing project setting: {setting}")

version = (PROJECT / "GODOT_VERSION").read_text(encoding="utf-8").strip()
if version != "4.7.2-stable":
    ERRORS.append(f"Unexpected Godot version pin: {version}")

preset_text = (PROJECT / "export_presets.cfg").read_text(encoding="utf-8")
if 'package/unique_name="com.classicblast.bubbleshooter"' not in preset_text:
    ERRORS.append("Android package ID is missing or incorrect.")

manifest_path = PROJECT / "assets/manifest.json"
try:
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
except json.JSONDecodeError as exc:
    ERRORS.append(f"Asset manifest JSON is invalid: {exc}")
    manifest = {}

assets = manifest.get("assets", {})
if not isinstance(assets, dict):
    ERRORS.append("Asset manifest 'assets' must be an object.")
    assets = {}

asset_root = (PROJECT / "assets").resolve()
for key, record in assets.items():
    if not isinstance(record, dict):
        ERRORS.append(f"Asset '{key}' must be an object with a relative path.")
        continue
    relative = record.get("path", "")
    if not isinstance(relative, str) or not relative or relative.startswith(("/", "\\")):
        ERRORS.append(f"Asset '{key}' has an invalid relative path.")
        continue
    candidate = (asset_root / relative).resolve()
    if asset_root not in candidate.parents:
        ERRORS.append(f"Asset '{key}' points outside the assets folder.")
    elif not candidate.is_file():
        ERRORS.append(f"Asset '{key}' is registered but its file is missing.")

if ERRORS:
    print("Milestone 1 static validation FAILED:")
    print("\n".join(f"- {error}" for error in ERRORS))
    sys.exit(1)

print("Milestone 1 static validation PASSED.")
print("Engine pin: Godot 4.7.2-stable.")
print("Project settings: portrait 1080x1920, canvas_items, 60 FPS.")
print("Android package ID: com.classicblast.bubbleshooter.")
print("Autoload services: 4.")
print(f"Registered production assets: {len(assets)}.")
if not assets:
    print("NOTICE: no production assets are imported; Drive asset sync remains pending.")
