#!/usr/bin/env python3
"""
Validate every level file plus the index. Run in CI before any export.

    python3 tools/validate_levels.py godot_project/levels
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from levelgen import validate  # noqa: E402


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else "godot_project/levels")
    if not root.is_dir():
        print(f"no such directory: {root}")
        return 2

    index_path = root / "index.json"
    if not index_path.exists():
        print("index.json is missing")
        return 2
    index = json.loads(index_path.read_text())
    entries = index.get("levels", [])

    errors: list[str] = []
    ids = []
    for e in entries:
        path = root / e["file"]
        if not path.exists():
            errors.append(f"index points at a missing file: {e['file']}")
            continue
        level = json.loads(path.read_text())
        ids.append(level["id"])
        errors.extend(validate(level))
        if level["id"] != e["id"]:
            errors.append(f"{e['file']}: id {level['id']} does not match index id {e['id']}")
        if not level.get("greedy"):
            errors.append(f"{e['file']}: no solver record - the level was never balanced")

    if len(set(ids)) != len(ids):
        errors.append("duplicate level ids in the index")
    if sorted(ids) != list(range(1, len(ids) + 1)):
        errors.append("level ids are not a contiguous 1..N range")

    for err in errors:
        print("ERROR", err)
    print(f"checked {len(entries)} levels, {len(errors)} problems")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
