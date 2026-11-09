#!/usr/bin/env python3
"""Six-department coordinator with a four-stage, allow-listed GDScript repair loop."""
from __future__ import annotations
import argparse
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
ALLOWED_PREFIXES = ("godot_project/scripts/", "godot_project/autoload/", "godot_project/tests/")
ERROR_MARKERS = ("SCRIPT ERROR:", "Parse Error:", "ERROR: Failed loading resource", "Cannot open file", "Invalid call.")

def run(command: list[str], label: str, check: bool = True) -> subprocess.CompletedProcess:
    print(f"\n=== {label} ===", flush=True)
    result = subprocess.run(command, cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    print(result.stdout, flush=True)
    if check and result.returncode != 0:
        raise RuntimeError(f"{label} failed with exit code {result.returncode}")
    return result

def changed_paths(patch: str) -> list[str]:
    paths = []
    for line in patch.splitlines():
        if line.startswith("diff --git "):
            parts = line.split()
            if len(parts) != 4:
                raise RuntimeError("Malformed unified diff header; refusing to apply.")
            for value in parts[2:4]:
                path = value[2:] if value.startswith(("a/", "b/")) else value
                if path != "/dev/null":
                    paths.append(path)
    return paths

def propose_and_apply_patch(log_text: str) -> None:
    from llm_router import LLMRouter
    prompt = (
        "You are a senior Godot 4.7 GDScript engineer. Diagnose and fix only the errors shown below. "
        "Return ONLY a valid unified git diff; no markdown fences or commentary. "
        "You may edit only files under godot_project/scripts/, godot_project/autoload/, and godot_project/tests/. "
        "Do not change project settings, Android export settings, workflows, credentials, asset ownership, or level data. "
        "Preserve the game design and make the smallest safe change.\n\nERROR LOG:\n" + log_text[-16000:]
    )
    patch = LLMRouter().complete(prompt, purpose="code")
    if not patch.lstrip().startswith("diff --git "):
        raise RuntimeError("Model did not return a unified diff. No patch was applied.")
    paths = changed_paths(patch)
    if not paths or any(not path.startswith(ALLOWED_PREFIXES) for path in paths):
        raise RuntimeError("Patch attempted to modify a file outside the GDScript repair allow-list.")
    patch_file = ROOT / "qa_proof" / "self_heal.patch"
    patch_file.parent.mkdir(parents=True, exist_ok=True)
    patch_file.write_text(patch, encoding="utf-8")
    run(["git", "apply", "--check", str(patch_file)], "Layer 3 · Validate proposed code repair")
    run(["git", "apply", str(patch_file)], "Layer 4 · Apply scoped code repair")

def self_heal(max_rounds: int = 4) -> None:
    last_log = ""
    for attempt in range(1, max_rounds + 1):
        result = run(["godot", "--headless", "--path", "godot_project", "--editor", "--quit"], f"Layer 1-2 · Godot diagnosis round {attempt}", check=False)
        last_log = result.stdout
        if result.returncode == 0 and not any(marker in last_log for marker in ERROR_MARKERS):
            print("Self-healing gate passed: project imported without reported parse/resource errors.")
            return
        print(f"Self-healing round {attempt}: engine reported errors; attempting a scoped repair.")
        propose_and_apply_patch(last_log)
    raise RuntimeError("Godot errors remain after four repair attempts.\n" + last_log[-5000:])

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--pass", dest="studio_pass", choices=["1", "2", "all"], default="all")
    parser.add_argument("--heal-log", type=Path)
    args = parser.parse_args()
    if args.heal_log:
        path = args.heal_log if args.heal_log.is_absolute() else ROOT / args.heal_log
        propose_and_apply_patch(path.read_text(encoding="utf-8", errors="replace"))
        print("Scoped GDScript repair applied.")
        return 0
    if args.studio_pass in ("1", "all"):
        run([sys.executable, "tools/rea_analyzer.py"], "Dept 1 · REA reference analysis")
        run([sys.executable, "tools/generate_original_assets.py"], "Dept 2 · Generate original artwork")
        run([sys.executable, "tools/generate_levels.py"], "Dept 3 · Generate 120 original levels")
        run([sys.executable, "tools/validate_levels.py"], "Dept 3 · Validate level catalogue")
        run([sys.executable, "tools/asset_audit.py"], "Dept 2 · Check asset rights and registry")
        self_heal()
    if args.studio_pass in ("2", "all"):
        run([sys.executable, "tools/replica_vision_qa.py"], "Dept 6 · Replica screenshot integrity and vision review")
    print("\nSix-department orchestration completed.")
    return 0

if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print("STUDIO FAILURE: " + str(exc), file=sys.stderr)
        raise SystemExit(1)