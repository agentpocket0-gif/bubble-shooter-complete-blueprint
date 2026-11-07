#!/usr/bin/env python3
"""
Normalise a user-supplied Android package into an analysable tree.

Input : a single .apk, or a split bundle (.xapk / .apks / .zip containing .apk parts)
Output: work/raw_apk/      merged contents of EVERY apk in the bundle
        work/decoded_apk/  apktool output for the base apk
        work/package_meta.json

No network access. The package must already exist on disk.
"""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path

WORK = Path("work")
RAW = WORK / "raw_apk"
DECODED = WORK / "decoded_apk"
PARTS = WORK / "parts"
META = WORK / "package_meta.json"

BUNDLE_EXT = {".xapk", ".apks", ".zip"}
SKIP_PREFIXES = ("META-INF/",)
TARGET_HINT = "bubbleshooter.orig"


def die(msg: str) -> None:
    print(f"::error::{msg}")
    sys.exit(1)


def safe_extract(zf: zipfile.ZipFile, dest: Path, label: str) -> int:
    """Extract skipping signature files and refusing path traversal."""
    dest.mkdir(parents=True, exist_ok=True)
    count = 0
    for info in zf.infolist():
        name = info.filename
        if info.is_dir():
            continue
        if name.startswith(SKIP_PREFIXES):
            continue
        if name.startswith("/") or ".." in Path(name).parts:
            print(f"  skipping unsafe entry in {label}: {name}")
            continue
        target = dest / name
        target.parent.mkdir(parents=True, exist_ok=True)
        try:
            with zf.open(info) as src, open(target, "wb") as out:
                shutil.copyfileobj(src, out, 1024 * 256)
            count += 1
        except Exception as exc:  # noqa: BLE001
            print(f"  WARN could not extract {name}: {exc}")
    return count


def verify(path: Path) -> None:
    if not zipfile.is_zipfile(path):
        die(f"{path} is not a valid zip/apk archive")
    with zipfile.ZipFile(path) as zf:
        bad = zf.testzip()
        if bad:
            die(f"{path} failed CRC check at member {bad}")
    print(f"  archive integrity OK ({path.stat().st_size / 1e6:.1f} MB)")


def inner_apks(bundle: Path) -> list[Path]:
    PARTS.mkdir(parents=True, exist_ok=True)
    found: list[Path] = []
    with zipfile.ZipFile(bundle) as zf:
        names = [n for n in zf.namelist() if n.lower().endswith(".apk")]
        if not names:
            return []
        for n in names:
            out = PARTS / Path(n).name
            with zf.open(n) as src, open(out, "wb") as dst:
                shutil.copyfileobj(src, dst, 1024 * 256)
            found.append(out)
    return found


def manifest_package(apk: Path) -> str | None:
    """Best-effort package name from a (binary) AndroidManifest inside an apk.

    Binary AXML keeps everything in a string pool, so namespace URIs sit right
    next to the real package name. Filter the obvious URIs out, then prefer the
    dotted identifier that looks like an application id.
    """
    import re

    try:
        with zipfile.ZipFile(apk) as zf:
            data = zf.read("AndroidManifest.xml")
    except Exception:  # noqa: BLE001
        return None
    text = data.decode("utf-8", "ignore")

    # a decoded (plain-text) manifest gives it away directly
    m = re.search(r'package="([^"]+)"', text)
    if m:
        return m.group(1)

    cands = re.findall(r"[a-zA-Z][a-zA-Z0-9_]*(?:\.[a-zA-Z0-9_]+){2,5}", text)
    bad = ("http", "schemas", "android.com", "w3.org", "apache.org", "google.com")
    cands = [c for c in cands
             if not any(b in c for b in bad)
             and not c.endswith((".com", ".org", ".net", ".xml", ".png"))]
    if not cands:
        return None
    cands.sort(key=lambda c: (TARGET_HINT not in c, -c.count(".")))
    return cands[0]


def choose_base(apks: list[Path]) -> Path:
    """Pick the base apk: matches the target package, else has a manifest, else largest."""
    scored = []
    for apk in apks:
        pkg = manifest_package(apk)
        is_config = apk.name.lower().startswith("config.") or "config." in apk.name.lower()
        score = 0
        if pkg and TARGET_HINT in (pkg or ""):
            score += 100
        if pkg:
            score += 10
        if not is_config:
            score += 5
        score += min(apk.stat().st_size / 1e9, 1.0)
        scored.append((score, apk, pkg))
    scored.sort(key=lambda t: -t[0])
    best = scored[0]
    print(f"  base apk -> {best[1].name} (package={best[2]})")
    return best[1]


def run_apktool(base: Path, apktool_cmd: str) -> bool:
    if DECODED.exists():
        shutil.rmtree(DECODED)
    cmd = f"{apktool_cmd} d -f --no-debug-info -o {DECODED} {base}"
    print(f"  $ {cmd}")
    proc = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    tail = (proc.stdout or "")[-2500:] + (proc.stderr or "")[-2500:]
    print(tail)
    if proc.returncode != 0 or not (DECODED / "AndroidManifest.xml").exists():
        print("::warning::apktool did not produce a decodable manifest - "
              "raw_apk/ analysis will continue without res/ values")
        return False
    return True


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    apktool_cmd = "apktool"
    for a in sys.argv[1:]:
        if a.startswith("--apktool="):
            apktool_cmd = a.split("=", 1)[1]
    if not args:
        die("usage: prepare_package.py <package.apk|.xapk|.apks|.zip>")

    pkg = Path(args[0]).resolve()
    if not pkg.exists():
        die(f"package not found: {pkg}")
    print(f"Preparing {pkg.name}")
    verify(pkg)

    WORK.mkdir(parents=True, exist_ok=True)
    if RAW.exists():
        shutil.rmtree(RAW)
    RAW.mkdir(parents=True, exist_ok=True)

    is_bundle = pkg.suffix.lower() in BUNDLE_EXT
    apks: list[Path] = []
    if is_bundle:
        apks = inner_apks(pkg)
        if not apks:
            # not a split bundle after all - treat as a plain apk
            print("  bundle contains no .apk parts; treating as single apk")
            is_bundle = False

    merged_files = 0
    if is_bundle:
        print(f"  split bundle with {len(apks)} apk part(s)")
        for apk in apks:
            with zipfile.ZipFile(apk) as zf:
                n = safe_extract(zf, RAW, apk.name)
            print(f"    {apk.name}: {n} entries")
            merged_files += n
        base = choose_base(apks)
    else:
        base = pkg
        with zipfile.ZipFile(pkg) as zf:
            merged_files = safe_extract(zf, RAW, pkg.name)
        print(f"  single apk: {merged_files} entries")

    ok = run_apktool(base, apktool_cmd)

    meta = {
        "input": str(pkg),
        "input_name": pkg.name,
        "is_split_bundle": is_bundle,
        "parts": [a.name for a in apks],
        "base_apk": base.name,
        "merged_entries": merged_files,
        "apktool_ok": ok,
        "raw_apk": str(RAW),
        "decoded_apk": str(DECODED) if ok else None,
    }
    META.write_text(json.dumps(meta, indent=2), encoding="utf-8")

    has_manifest = (DECODED / "AndroidManifest.xml").exists() or (RAW / "AndroidManifest.xml").exists()
    has_assets = (RAW / "assets").exists()
    has_libs = any(RAW.glob("lib/**/*.so"))
    print(json.dumps({"manifest": has_manifest, "assets": has_assets,
                      "native_libs": has_libs}, indent=2))
    if not (has_manifest or has_assets or has_libs):
        die("nothing usable was extracted - the package may be corrupt or protected")
    if not (DECODED / "AndroidManifest.xml").exists():
        print("::warning::decoded manifest missing: res/values analysis will be skipped, "
              "raw tree analysis continues")
    return 0


if __name__ == "__main__":
    sys.exit(main())
