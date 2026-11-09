#!/usr/bin/env python3
"""Validate structure and entry conditions for the generated level set."""
from __future__ import annotations
import json
from collections import Counter
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
LEVEL_DIR = ROOT / "godot_project" / "levels"
EXPECTED = 120
ALLOWED = set(".123456xic")

def validate(path: Path) -> list[str]:
    errors = []
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        return [f"{path.name}: invalid JSON: {exc}"]
    level_id = data.get("id")
    grid = data.get("grid", {})
    cols, rows = int(grid.get("cols", 0)), int(grid.get("rows", 0))
    palette, layout = data.get("palette", []), data.get("layout", [])
    if not isinstance(level_id, int) or not 1 <= level_id <= EXPECTED:
        errors.append(f"{path.name}: id must be in 1..{EXPECTED}")
    if not 9 <= cols <= 13 or not 10 <= rows <= 20:
        errors.append(f"{path.name}: grid dimensions outside mobile limits")
    if not 3 <= len(palette) <= 6:
        errors.append(f"{path.name}: palette must contain 3..6 colours")
    if not isinstance(layout, list) or len(layout) > rows:
        errors.append(f"{path.name}: layout row count invalid")
        return errors
    counts = Counter()
    for row_no, line in enumerate(layout):
        if not isinstance(line, str) or len(line) != cols:
            errors.append(f"{path.name}: row {row_no} must contain exactly {cols} cells")
            continue
        for char in line:
            if char not in ALLOWED:
                errors.append(f"{path.name}: unsupported layout token {char!r}")
            elif char.isdigit():
                if int(char) > len(palette):
                    errors.append(f"{path.name}: palette index {char} is out of range")
                counts[char] += 1
    if counts and max(counts.values()) < 3:
        errors.append(f"{path.name}: no colour has a 3+ match")
    if any(count < 3 for count in counts.values()):
        errors.append(f"{path.name}: a used colour has fewer than 3 starting bubbles")
    if int(data.get("shots", 0)) < 5:
        errors.append(f"{path.name}: fewer than 5 moves")
    try:
        stars = [int(data["stars"][key]) for key in ("1", "2", "3")]
        if not stars[0] < stars[1] < stars[2]:
            errors.append(f"{path.name}: star thresholds are not increasing")
    except Exception:
        errors.append(f"{path.name}: star thresholds missing")
    valid_objectives = {"clear_all", "clear_color", "pop_count", "rescue", "score", "survive"}
    objectives = data.get("objectives", [])
    if not objectives or any(item.get("type") not in valid_objectives for item in objectives):
        errors.append(f"{path.name}: objective list missing or unsupported")
    for blocker in data.get("blockers", []):
        row, col = int(blocker.get("row", -1)), int(blocker.get("col", -1))
        if not 0 <= row < rows or not 0 <= col < cols:
            errors.append(f"{path.name}: blocker coordinate is outside grid")
        elif row < len(layout) and layout[row][col] != ".":
            errors.append(f"{path.name}: blocker overlaps a bubble")
        if blocker.get("type") not in {"ice", "stone", "chain"}:
            errors.append(f"{path.name}: invalid blocker type")
        if int(blocker.get("hp", 1)) < 1:
            errors.append(f"{path.name}: blocker hp must be positive")
    if any(item.get("type") == "rescue" for item in objectives) and not data.get("blockers"):
        errors.append(f"{path.name}: rescue objective must include a blocker")
    return errors

def main() -> int:
    files = sorted(LEVEL_DIR.glob("level_*.json"))
    if len(files) != EXPECTED:
        print(f"ERROR: expected {EXPECTED} levels, found {len(files)}", file=sys.stderr)
        return 1
    errors = [error for path in files for error in validate(path)]
    ids = [json.loads(path.read_text(encoding="utf-8"))["id"] for path in files]
    if sorted(ids) != list(range(1, EXPECTED + 1)):
        errors.append("level IDs must be unique and continuous")
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print(f"Validated {len(files)} original level JSON files; schema and structural checks passed.")
    print("Note: full trajectory-aware solvability still requires runtime playtesting.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
