#!/usr/bin/env python3
"""
Sanity-check an exported APK: it is a zip, it contains the Godot native
libraries and a dex, and the binary manifest names the expected package.

    python3 tools/verify_apk.py out/app-debug.apk --package com.classicblast.bubbleshooter

This is a smoke test, not a substitute for `bundletool validate` or Play's own
pre-launch report.
"""
from __future__ import annotations

import argparse
import sys
import zipfile


def manifest_strings(data: bytes) -> str:
    """Android binary XML keeps its strings in a UTF-16LE pool; decode what we can."""
    try:
        text = data.decode("utf-16-le", errors="ignore")
    except Exception:
        return ""
    cleaned = "".join(ch if 32 <= ord(ch) < 127 else " " for ch in text)
    return cleaned


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("apk")
    ap.add_argument("--package", default="")
    args = ap.parse_args()

    try:
        zf = zipfile.ZipFile(args.apk)
    except Exception as exc:  # noqa: BLE001
        print(f"not a zip: {exc}")
        return 1

    names = zf.namelist()
    problems = []

    if "AndroidManifest.xml" not in names:
        problems.append("no AndroidManifest.xml")
    if "classes.dex" not in names:
        problems.append("no classes.dex")
    if not any(n.endswith("libgodot_android.so") for n in names):
        problems.append("no libgodot_android.so")
    if not any(n.startswith("assets/") for n in names):
        problems.append("no assets/ payload - the game pck is missing")

    if args.package and "AndroidManifest.xml" in names:
        text = manifest_strings(zf.read("AndroidManifest.xml"))
        if args.package not in text:
            problems.append(f"package {args.package} not found in the manifest")

    print(f"{len(names)} entries, {sum(i.file_size for i in zf.infolist()) / 1e6:.1f} MB uncompressed")
    for p in problems:
        print("PROBLEM", p)
    if problems:
        return 1
    print("APK looks structurally sound")
    return 0


if __name__ == "__main__":
    sys.exit(main())
