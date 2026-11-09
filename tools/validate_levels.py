#!/usr/bin/env python3
"""Validate the full 600-level campaign data set; does not claim trajectory solvability."""
from __future__ import annotations
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
LEVEL_DIR = ROOT / "godot_project" / "levels"
EXPECTED = 600
ALLOWED = set(".123456xic")
OBJECTIVES = {"clear_all", "clear_color", "pop_count", "rescue", "score", "survive"}

def validate(path: Path) -> list[str]:
    errors: list[str] = []
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
    if not 3 <= len(palette) <= 6 or len(set(palette)) != len(palette):
        errors.append(f"{path.name}: palette must contain 3..6 unique colours")
    if not isinstance(layout, list) or not layout or len(layout) > rows:
        errors.append(f"{path.name}: layout row count invalid")
        return errors
    for row_no, line in enumerate(layout):
        if not isinstance(line, str) or len(line) != cols:
            errors.append(f"{path.name}: row {row_no} must contain exactly {cols} cells")
            continue
        for char in line:
            if char not in ALLOWED:
                errors.append(f"{path.name}: unsupported layout token {char!r}")
            elif char.isdigit() and int(char) > len(palette):
                errors.append(f"{path.name}: palette index {char} is out of range")
    if int(data.get("shots", 0)) < 5:
        errors.append(f"{path.name}: fewer than 5 moves")
    try:
        stars = [int(data["stars"][key]) for key in ("1", "2", "3")]
        if not stars[0] < stars[1] < stars[2]:
            errors.append(f"{path.name}: star thresholds are not increasing")
    except Exception:
        errors.append(f"{path.name}: star thresholds missing")
    objectives = data.get("objectives", [])
    if not objectives or any(item.get("type") not in OBJECTIVES for item in objectives):
        errors.append(f"{path.name}: objective list missing or unsupported")
    for item in objectives:
        if item.get("type") == "clear_color" and item.get("color") not in palette:
            errors.append(f"{path.name}: clear_color objective is not in the palette")
    for blocker in data.get("blockers", []):
        row, col = int(blocker.get("row", -1)), int(blocker.get("col", -1))
        if not 0 <= row < rows or not 0 <= col < cols:
            errors.append(f"{path.name}: blocker coordinate outside grid")
        elif row < len(layout) and layout[row][col] != ".":
            errors.append(f"{path.name}: blocker overlaps a bubble")
        if blocker.get("type") not in {"ice", "stone", "chain"}:
            errors.append(f"{path.name}: invalid blocker type")
        if int(blocker.get("hp", 1)) < 1:
            errors.append(f"{path.name}: blocker hp must be positive")
    if data.get("content_status") != "generated_structural_only":
        errors.append(f"{path.name}: content status missing or misleading")
    if data.get("playability_status") != "requires_trajectory_solver":
        errors.append(f"{path.name}: playability status missing or misleading")
    return errors

def main() -> int:
    files = sorted(LEVEL_DIR.glob("level_*.json"))
    if len(files) != EXPECTED:
        print(f"ERROR: expected {EXPECTED} levels, found {len(files)}", file=sys.stderr)
        return 1
    errors = [error for path in files for error in validate(path)]
    try:
        ids = [json.loads(path.read_text(encoding="utf-8"))["id"] for path in files]
        if sorted(ids) != list(range(1, EXPECTED + 1)):
            errors.append("level IDs must be unique and continuous")
        signatures = [tuple(json.loads(path.read_text(encoding="utf-8"))["layout"]) for path in files]
        if len(set(signatures)) != EXPECTED:
            errors.append("level layouts must be unique in this generated set")
    except Exception as exc:
        errors.append(f"index verification failed: {exc}")
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print("Validated exactly 600 level records: IDs, schema, blockers, objectives and unique layouts passed.")
    print("IMPORTANT: structural validation only. No trajectory-aware solvability claim is made.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
