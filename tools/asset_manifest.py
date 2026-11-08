#!/usr/bin/env python3
"""
Asset authenticity gate.

Writes (or verifies) a SHA-256 manifest of everything in godot_project/assets/.
CI verifies it before exporting, so a build can never ship a texture tree that
differs from the one that was reviewed and screenshotted.

    python3 tools/asset_manifest.py --write
    python3 tools/asset_manifest.py --verify

This proves the shipped tree is exactly the reviewed tree. It cannot, on its
own, prove where the art came from - that is what ASSET_CREDITS.md records.
"""
from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

ASSETS = Path("godot_project/assets")
MANIFEST = Path("godot_project/assets_manifest.json")


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def build() -> dict:
    files = {}
    for path in sorted(ASSETS.rglob("*")):
        if path.is_file():
            rel = path.relative_to(ASSETS).as_posix()
            files[rel] = {"sha256": digest(path), "size": path.stat().st_size}
    total = sum(v["size"] for v in files.values())
    return {"root": "godot_project/assets", "count": len(files),
            "total_bytes": total, "files": files}


def main() -> int:
    mode = sys.argv[1] if len(sys.argv) > 1 else "--verify"
    if not ASSETS.is_dir():
        print(f"no assets directory at {ASSETS}")
        return 2

    current = build()
    if mode == "--write":
        MANIFEST.write_text(json.dumps(current, indent=1, sort_keys=True) + "\n")
        print(f"wrote {MANIFEST}: {current['count']} files, {current['total_bytes'] / 1e6:.1f} MB")
        return 0

    if not MANIFEST.exists():
        print("no manifest - run --write")
        return 1
    expected = json.loads(MANIFEST.read_text())

    problems = []
    if current["count"] != expected["count"]:
        problems.append(f"file count {current['count']} != manifest {expected['count']}")
    for rel, meta in expected["files"].items():
        if rel not in current["files"]:
            problems.append(f"missing: {rel}")
        elif current["files"][rel]["sha256"] != meta["sha256"]:
            problems.append(f"changed: {rel}")
    for rel in current["files"]:
        if rel not in expected["files"]:
            problems.append(f"unexpected new file: {rel}")

    for p in problems[:20]:
        print("PROBLEM", p)
    print(f"verified {current['count']} assets, {len(problems)} problems")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
