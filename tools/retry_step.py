#!/usr/bin/env python3
"""Run one CI step and request a restricted script repair before retrying failures."""
from __future__ import annotations
import argparse
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--retries", type=int, default=2)
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command and args.command[0] == "--" else args.command
    if not command:
        parser.error("provide a command after --")
    for attempt in range(max(0, args.retries) + 1):
        result = subprocess.run(command, cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        print(result.stdout, flush=True)
        if result.returncode == 0:
            return 0
        log = ROOT / "qa_proof" / f"retry_failure_{attempt + 1}.log"
        log.parent.mkdir(parents=True, exist_ok=True)
        log.write_text(result.stdout[-20000:], encoding="utf-8")
        if attempt >= max(0, args.retries):
            print(f"Step failed. Log saved to {log}", file=sys.stderr)
            return result.returncode
        heal = subprocess.run(
            [sys.executable, "tools/autonomous_studio_orchestrator.py", "--heal-log", str(log)],
            cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT
        )
        print(heal.stdout, flush=True)
        if heal.returncode != 0:
            print("Restricted self-healing could not repair this failed step.", file=sys.stderr)
            return heal.returncode
    return 1

if __name__ == "__main__":
    raise SystemExit(main())
