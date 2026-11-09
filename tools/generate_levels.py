#!/usr/bin/env python3
"""Generate 600 deterministic campaign levels; solvability remains a separate gate."""
from __future__ import annotations
import json
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "godot_project" / "levels"
TARGET_LEVELS = 600
COLS = 11
MAX_ROWS = 20
COLORS = ["red", "blue", "green", "yellow", "purple", "orange"]
ROW_PATTERNS = [(0, 4, 8), (1, 4, 8), (0, 3, 7), (1, 5, 8), (0, 4, 7), (1, 4, 7)]
OBJECTIVES = ["clear_all", "clear_all", "clear_all", "clear_color", "pop_count", "score"]

def build_level(level_id: int) -> dict:
    if not 1 <= level_id <= TARGET_LEVELS:
        raise ValueError(f"level_id must be within 1..{TARGET_LEVELS}")
    rng = random.Random(20261109 + level_id * 7919)
    color_count = min(6, 3 + (level_id - 1) // 100)
    palette = COLORS[:color_count]
    row_count = min(14, 4 + (level_id - 1) // 48)
    layout: list[str] = []
    for row_no in range(row_count):
        cells = ["."] * COLS
        starts = list(ROW_PATTERNS[(row_no + level_id) % len(ROW_PATTERNS)])
        rng.shuffle(starts)
        group_colors = rng.sample(palette, 3)
        for start, color in zip(sorted(starts), group_colors):
            token = str(palette.index(color) + 1)
            for offset in range(3):
                cells[start + offset] = token
        layout.append("".join(cells))

    objective_kind = OBJECTIVES[(level_id - 1) % len(OBJECTIVES)]
    if objective_kind == "clear_color":
        objectives = [{"type": "clear_color", "color": palette[(level_id * 7) % color_count]}]
    elif objective_kind == "pop_count":
        objectives = [{"type": "pop_count", "count": max(6, row_count * 3)}]
    elif objective_kind == "score":
        objectives = [{"type": "score", "target": row_count * 180}]
    else:
        objectives = [{"type": "clear_all"}]

    blockers = []
    if level_id >= 25 and level_id % 6 == 0:
        candidates = [(r, c) for r, line in enumerate(layout) for c, token in enumerate(line) if token == "."]
        if candidates:
            row, col = candidates[rng.randrange(len(candidates))]
            blockers.append({"row": row, "col": col, "type": "ice", "hp": 1 if level_id < 200 else 2})

    bubble_count = sum(ch.isdigit() for line in layout for ch in line)
    estimated_clusters = max(3, row_count * 3)
    shots = min(60, max(12, estimated_clusters + 5))
    score_target = max(100, bubble_count * 18)
    stars = {
        "1": max(50, int(score_target * 0.45)),
        "2": max(100, int(score_target * 0.68)),
        "3": max(150, int(score_target * 0.9))
    }
    return {
        "id": level_id,
        "world": 1 + (level_id - 1) // 100,
        "name": f"Bubble Bay {level_id:03d}",
        "mode": "campaign",
        "grid": {"cols": COLS, "rows": MAX_ROWS, "seed": 20261109 + level_id * 7919},
        "shots": shots,
        "palette": palette,
        "layout": layout,
        "blockers": blockers,
        "objectives": objectives,
        "stars": stars,
        "rewards": {"coins": 40, "firstClearBonus": 100},
        "content_status": "generated_structural_only",
        "playability_status": "requires_trajectory_solver",
        "notes": "Deterministic generated content. Do not label playable-verified until the trajectory-aware solver passes."
    }

def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    index = []
    signatures = set()
    for level_id in range(1, TARGET_LEVELS + 1):
        data = build_level(level_id)
        signature = tuple(data["layout"])
        if signature in signatures:
            raise SystemExit(f"Duplicate layout signature at level {level_id}")
        signatures.add(signature)
        path = OUT / f"level_{level_id:03d}.json"
        path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        index.append({"id": level_id, "world": data["world"], "file": path.name, "name": data["name"], "status": data["playability_status"]})
    (OUT / "index.json").write_text(json.dumps(index, indent=2) + "\n", encoding="utf-8")
    print(f"Generated {len(index)} deterministic campaign level records.")
    print("Status: structurally generated only; trajectory-aware solvability is not asserted.")

if __name__ == "__main__":
    main()
