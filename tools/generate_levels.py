#!/usr/bin/env python3
"""Generate 120 original, deterministic Bubble Shooter levels."""
from __future__ import annotations
import json
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "godot_project" / "levels"
COLORS = ["red", "blue", "green", "yellow", "purple", "orange"]
OBJECTIVES = ["clear_all", "clear_color", "pop_count", "rescue", "score", "survive"]

def build_level(level_id: int) -> dict:
    rng = random.Random(86000 + level_id)
    color_count = min(6, 3 + (level_id - 1) // 20)
    palette = COLORS[:color_count]
    row_count = min(14, 3 + (level_id - 1) // 9)
    layout = []
    for row in range(row_count):
        row_colors = [palette[(row + n + level_id // 8) % color_count] for n in range(3)]
        rng.shuffle(row_colors)
        cells = []
        for color in row_colors:
            cells.extend([str(palette.index(color) + 1)] * 3)
        layout.append("".join(cells) + "..")
    objective_kind = OBJECTIVES[(level_id - 1) % len(OBJECTIVES)]
    objectives = [{"type": "clear_all"}]
    if objective_kind == "clear_color":
        objectives = [{"type": "clear_color", "color": palette[(level_id // 6) % color_count]}]
    elif objective_kind == "pop_count":
        objectives = [{"type": "pop_count", "count": min(90, row_count * 6)}]
    elif objective_kind == "rescue":
        objectives = [{"type": "rescue", "count": 1}]
    elif objective_kind == "score":
        objectives = [{"type": "score", "target": max(60, row_count * 9 * 8)}]
    elif objective_kind == "survive":
        objectives = [{"type": "survive", "shots": 8 + level_id // 10}]
    bubble_count = sum(ch.isdigit() for line in layout for ch in line)
    shots = min(55, max(12, bubble_count // 3 + 8))
    three_star = max(100, int(bubble_count * 10 * 0.85))
    stars = {"1": max(25, three_star // 3), "2": max(50, three_star * 7 // 10), "3": three_star}
    blockers = []
    if objective_kind == "rescue" or (level_id >= 13 and level_id % 3 == 0):
        blockers.append({"row": row_count - 1, "col": 9, "type": "ice", "hp": 1})
    return {
        "id": level_id, "world": 1 + (level_id - 1) // 40, "name": f"Bubble Bay {level_id:03d}",
        "grid": {"cols": 11, "rows": 20, "seed": 86000 + level_id}, "shots": shots,
        "palette": palette, "layout": layout, "blockers": blockers, "objectives": objectives,
        "stars": stars, "rewards": {"coins": 40, "firstClearBonus": 100},
        "notes": "Original procedural level. Validate the aim path and progression on device before release."
    }

def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    index = []
    for level_id in range(1, 121):
        data = build_level(level_id)
        path = OUT / f"level_{level_id:03d}.json"
        path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        index.append({"id": level_id, "world": data["world"], "file": path.name, "name": data["name"]})
    (OUT / "index.json").write_text(json.dumps(index, indent=2) + "\n", encoding="utf-8")
    print(f"Generated {len(index)} original levels in {OUT}")

if __name__ == "__main__":
    main()
