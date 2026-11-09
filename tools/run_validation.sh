#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
python3 tools/generate_original_assets.py
python3 tools/generate_levels.py
python3 tools/validate_levels.py
python3 tools/asset_audit.py
python3 tools/rea_analyzer.py
if ! command -v godot >/dev/null 2>&1; then
  echo "Godot is required for engine validation." >&2
  exit 2
fi
godot --headless --path godot_project --editor --quit
godot --headless --path godot_project --script res://tests/test_gameplay.gd
