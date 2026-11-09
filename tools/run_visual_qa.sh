#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p qa_proof
command -v xvfb-run >/dev/null 2>&1 || { echo "xvfb-run is required." >&2; exit 2; }
command -v godot >/dev/null 2>&1 || { echo "Godot is required." >&2; exit 2; }
export QA_OUTPUT_DIR="$ROOT/qa_proof"
xvfb-run -a -s "-screen 0 1080x1920x24" godot --path godot_project --script res://tests/qa_capture.gd
python3 tools/replica_vision_qa.py
