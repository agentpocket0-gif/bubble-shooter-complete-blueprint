#!/usr/bin/env python3
"""Validate 600 boards in each of three modes; does not assert playability."""
from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
LEVEL_DIR = ROOT / "godot_project" / "levels"
EXPECTED = 600
MODES = ("classic", "hard", "challenge")
ALLOWED = set(".123456xic")
OBJECTIVES = {"clear_all", "clear_color", "pop_count", "rescue", "score", "survive"}


def validate_level(data: dict[str, Any], expected_id: int, expected_mode: str, source: str) -> list[str]:
    errors: list[str] = []
    if int(data.get("id", 0)) != expected_id:
        errors.append(f"{source}: expected id {expected_id}, got {data.get('id')}")
    if data.get("mode") != expected_mode:
        errors.append(f"{source}: expected mode {expected_mode}, got {data.get('mode')}")
    grid = data.get("grid", {})
    if not isinstance(grid, dict):
        errors.append(f"{source}: grid must be an object")
        return errors
    try:
        cols, rows = int(grid.get("cols", 0)), int(grid.get("rows", 0))
    except (TypeError, ValueError):
        errors.append(f"{source}: invalid grid dimensions")
        return errors
    if not 9 <= cols <= 13 or not 10 <= rows <= 70:
        errors.append(f"{source}: grid dimensions outside authored limits")

    palette = data.get("palette", [])
    layout = data.get("layout", [])
    if not isinstance(palette, list) or not 3 <= len(palette) <= 6 or len(set(palette)) != len(palette):
        errors.append(f"{source}: palette must contain 3..6 unique colours")
        palette = []
    if not isinstance(layout, list) or not layout or len(layout) > rows:
        errors.append(f"{source}: layout row count invalid")
        return errors

    counts: dict[str, int] = {}
    for row_no, line in enumerate(layout):
        if not isinstance(line, str) or len(line) != cols:
            errors.append(f"{source}: row {row_no} must contain exactly {cols} cells")
            continue
        for char in line:
            if char not in ALLOWED:
                errors.append(f"{source}: unsupported layout token {char!r}")
            elif char.isdigit():
                if int(char) < 1 or int(char) > len(palette):
                    errors.append(f"{source}: palette index {char} is out of range")
                counts[char] = counts.get(char, 0) + 1
    if not counts:
        errors.append(f"{source}: board contains no coloured bubbles")
    elif max(counts.values()) < 3:
        errors.append(f"{source}: no colour has a starting match of 3+")

    try:
        shots = int(data.get("shots", 0))
        if shots < 5:
            errors.append(f"{source}: fewer than 5 moves")
        stars = [int(data["stars"][key]) for key in ("1", "2", "3")]
        if not stars[0] < stars[1] < stars[2]:
            errors.append(f"{source}: star thresholds are not increasing")
    except (KeyError, TypeError, ValueError):
        errors.append(f"{source}: shots or star thresholds are invalid")

    objectives = data.get("objectives", [])
    if not isinstance(objectives, list) or not objectives:
        errors.append(f"{source}: objective list is empty")
        objectives = []
    for item in objectives:
        if not isinstance(item, dict) or item.get("type") not in OBJECTIVES:
            errors.append(f"{source}: unsupported objective {item!r}")
            continue
        kind = item.get("type")
        if kind == "clear_color" and item.get("color") not in palette:
            errors.append(f"{source}: clear_color target is outside the palette")
        if kind in ("pop_count", "score", "rescue", "survive"):
            field = {"pop_count": "count", "score": "target", "rescue": "count", "survive": "shots"}[kind]
            try:
                if int(item.get(field, 0)) < 1:
                    errors.append(f"{source}: {kind}.{field} must be positive")
            except (TypeError, ValueError):
                errors.append(f"{source}: {kind}.{field} must be an integer")

    blockers = data.get("blockers", [])
    if not isinstance(blockers, list):
        errors.append(f"{source}: blockers must be a list")
        blockers = []
    for blocker in blockers:
        if not isinstance(blocker, dict):
            errors.append(f"{source}: blocker row must be an object")
            continue
        try:
            row, col = int(blocker.get("row", -1)), int(blocker.get("col", -1))
            hp = int(blocker.get("hp", 1))
        except (TypeError, ValueError):
            errors.append(f"{source}: blocker coordinates/hp must be integers")
            continue
        if not 0 <= row < rows or not 0 <= col < cols:
            errors.append(f"{source}: blocker coordinate outside grid")
        elif row < len(layout) and isinstance(layout[row], str) and col < len(layout[row]) and layout[row][col] != ".":
            errors.append(f"{source}: blocker overlaps a bubble")
        if blocker.get("type") not in {"ice", "stone", "chain"}:
            errors.append(f"{source}: invalid blocker type {blocker.get('type')!r}")
        if hp < 1:
            errors.append(f"{source}: blocker hp must be positive")

    if data.get("content_status") != "generated_structural_only":
        errors.append(f"{source}: content status missing or misleading")
    if data.get("playability_status") != "requires_trajectory_solver":
        errors.append(f"{source}: playability status missing or misleading")
    return errors


def main() -> int:
    errors: list[str] = []
    files = sorted(LEVEL_DIR.glob("level_[0-9][0-9][0-9].json"))
    if len(files) != EXPECTED:
        errors.append(f"expected {EXPECTED} compatibility level files, found {len(files)}")
    classic_files: dict[int, dict[str, Any]] = {}
    for path in files:
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
            level_id = int(data.get("id", 0))
            classic_files[level_id] = data
            errors.extend(validate_level(data, level_id, "classic", path.name))
        except Exception as exc:
            errors.append(f"{path.name}: invalid JSON or record: {exc}")

    pack_file = LEVEL_DIR / "campaign_600.json"
    if not pack_file.exists():
        errors.append("runtime campaign_600.json pack is missing")
    else:
        try:
            pack = json.loads(pack_file.read_text(encoding="utf-8"))
            if int(pack.get("campaign_levels", 0)) != EXPECTED:
                errors.append("campaign_levels must equal 600")
            if int(pack.get("mode_count", 0)) != len(MODES):
                errors.append("mode_count must equal 3")
            if int(pack.get("logical_variants", 0)) != EXPECTED * len(MODES):
                errors.append("logical_variants must equal 1800")
            mode_data = pack.get("modes", {})
            if not isinstance(mode_data, dict) or set(mode_data.keys()) != set(MODES):
                errors.append("runtime pack must contain exactly classic, hard and challenge")
                mode_data = {}

            for mode in MODES:
                entries = mode_data.get(mode, [])
                if not isinstance(entries, list) or len(entries) != EXPECTED:
                    errors.append(f"{mode}: expected exactly {EXPECTED} variants")
                    continue
                ids: list[int] = []
                signatures: set[tuple[str, ...]] = set()
                for index, item in enumerate(entries, start=1):
                    if not isinstance(item, dict):
                        errors.append(f"{mode} level {index}: record is not an object")
                        continue
                    ids.append(int(item.get("id", 0)))
                    errors.extend(validate_level(item, index, mode, f"{mode}/{index:03d}"))
                    signature = tuple(item.get("layout", []))
                    if signature in signatures:
                        errors.append(f"{mode}: duplicate layout signature at level {index}")
                    signatures.add(signature)
                if ids != list(range(1, EXPECTED + 1)):
                    errors.append(f"{mode}: IDs must be continuous from 1 to 600")

            if pack.get("levels", []) != mode_data.get("classic", []):
                errors.append("legacy levels alias must exactly match classic mode")
        except Exception as exc:
            errors.append(f"campaign pack could not be validated: {exc}")

    if sorted(classic_files.keys()) != list(range(1, EXPECTED + 1)):
        errors.append("classic compatibility file IDs must be continuous from 1 to 600")

    if errors:
        print("\n".join(errors[:300]), file=sys.stderr)
        if len(errors) > 300:
            print(f"... {len(errors) - 300} additional errors suppressed", file=sys.stderr)
        return 1

    print("STRUCTURAL PASS: 600 classic + 600 hard + 600 challenge records (1,800 total).")
    print("IDs, mode labels, layouts, palettes, objectives, blockers and star ordering passed.")
    print("PLAYABILITY STATUS: NOT VERIFIED. A trajectory-aware solver and human review remain required.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
