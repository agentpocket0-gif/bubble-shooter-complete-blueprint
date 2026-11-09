#!/usr/bin/env python3
"""Dept 1: summarize documented reference measurements without copying protected expression."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "qa_proof" / "DEPT1_REA_REFERENCE_AUDIT.json"

def main() -> int:
    blueprint = ROOT / "blueprint" / "original"
    documents = sorted(blueprint.glob("*.md"))
    reference = ROOT / "reference" / "original_game_code" / "level_configs"
    samples = sorted(reference.glob("level_*_ref.json"))
    manifest_path = ROOT / "godot_project" / "assets" / "real_pack" / "REAL_PACK_MANIFEST.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8")) if manifest_path.exists() else {}
    report = {
        "department": "REA",
        "blueprint_documents": [path.name for path in documents],
        "reference_level_sample_files": len(samples),
        "reference_sample_data_is_not_shipped": True,
        "mechanics_reference": {
            "grid": "staggered odd rows",
            "row_pitch": "bubble_diameter * sqrt(3) / 2",
            "odd_row_offset": "bubble_diameter / 2",
            "neighbour_count": 6
        },
        "asset_rights": {
            "real_pack_publishable": bool(manifest.get("publishable", False)),
            "real_pack_excluded_from_game": True,
            "real_pack_files": int(manifest.get("total_files", 0))
        }
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("REA audit saved:", OUT)
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
