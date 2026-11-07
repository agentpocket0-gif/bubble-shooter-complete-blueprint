#!/usr/bin/env python3
"""
Locate the reference Android package for analysis.

This script does NOT scrape APK mirror sites. It only accepts a package that
you supplied yourself, in one of three places:

  1. --url / REFERENCE_PACKAGE_URL   a direct link you control
  2. a release asset on THIS repository (default tag: v1.0-apk)
  3. a file committed under reference/

If nothing is found it exits 0 and reports FOUND= so the workflow can stop
cleanly instead of failing.

Outputs (when GITHUB_OUTPUT is set, GitHub Actions reads them):
  FOUND=<absolute path>   or  FOUND=
  SOURCE=<description>
"""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

VALID_EXT = {".apk", ".xapk", ".apks", ".zip"}
WORK = Path("work")
DEST = WORK / "input_pkg"


def emit(**kv: str) -> None:
    out = os.environ.get("GITHUB_OUTPUT")
    if out:
        with open(out, "a", encoding="utf-8") as fh:
            for k, v in kv.items():
                fh.write(f"{k}={v}\n")
    for k, v in kv.items():
        print(f"{k}={v}")


def api_get(url: str, token: str, accept: str = "application/vnd.github+json"):
    req = urllib.request.Request(url, headers={
        "Authorization": f"Bearer {token}",
        "Accept": accept,
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "rea-extract",
    })
    return urllib.request.urlopen(req, timeout=180)


def download(url: str, out: Path, token: str | None = None,
             accept: str | None = None, api_asset: bool = False) -> Path:
    out.parent.mkdir(parents=True, exist_ok=True)
    headers = {"User-Agent": "rea-extract"}
    if token and api_asset:
        headers["Authorization"] = f"Bearer {token}"
        headers["Accept"] = accept or "application/octet-stream"
    req = urllib.request.Request(url, headers=headers)
    total = 0
    with urllib.request.urlopen(req, timeout=600) as resp, open(out, "wb") as fh:
        while True:
            chunk = resp.read(1024 * 512)
            if not chunk:
                break
            fh.write(chunk)
            total += len(chunk)
    print(f"  downloaded {total / 1e6:.1f} MB -> {out}")
    return out


def pick_asset(assets: list[dict]) -> dict | None:
    cands = [a for a in assets if Path(a["name"]).suffix.lower() in VALID_EXT]
    if not cands:
        return None
    # prefer xapk/apks bundles, then the largest file
    order = {".xapk": 0, ".apks": 1, ".apk": 2, ".zip": 3}
    cands.sort(key=lambda a: (order.get(Path(a["name"]).suffix.lower(), 9), -a["size"]))
    return cands[0]


def try_release(token: str, repo: str, tag: str) -> tuple[Path, str] | None:
    if not (token and repo):
        return None
    try:
        with api_get(f"https://api.github.com/repos/{repo}/releases?per_page=100", token) as r:
            releases = json.load(r)
    except Exception as exc:  # noqa: BLE001
        print(f"  release lookup failed: {exc}")
        return None

    ordered = [x for x in releases if x.get("tag_name") == tag] + \
              [x for x in releases if x.get("tag_name") != tag]
    for rel in ordered:
        asset = pick_asset(rel.get("assets") or [])
        if not asset:
            continue
        url = asset["url"] if rel.get("draft") else asset.get("browser_download_url") or asset["url"]
        name = asset["name"]
        print(f"  found release asset: {rel.get('tag_name')} / {name} ({asset['size']/1e6:.1f} MB)")
        path = download(url, DEST / name, token=token, api_asset=True)
        return path, f"release asset {rel.get('tag_name')}/{name}"
    return None


def try_reference_dir() -> tuple[Path, str] | None:
    ref = Path("reference")
    if not ref.is_dir():
        return None
    cands = [p for p in ref.rglob("*") if p.is_file() and p.suffix.lower() in VALID_EXT]
    if not cands:
        return None
    cands.sort(key=lambda p: (-p.stat().st_size,))
    src = cands[0]
    DEST.mkdir(parents=True, exist_ok=True)
    dst = DEST / src.name
    dst.write_bytes(src.read_bytes())
    print(f"  using committed file: {src} ({src.stat().st_size/1e6:.1f} MB)")
    return dst, f"committed file {src}"


def main() -> int:
    tag = os.environ.get("REFERENCE_RELEASE_TAG", "v1.0-apk")
    token = os.environ.get("GITHUB_TOKEN", "")
    repo = os.environ.get("GITHUB_REPOSITORY", "")
    url = os.environ.get("REFERENCE_PACKAGE_URL", "").strip()

    for i, arg in enumerate(sys.argv[1:]):
        if arg == "--url" and i + 2 <= len(sys.argv) - 1:
            url = sys.argv[i + 2].strip()

    print("Resolving reference package ...")
    result = None

    if url:
        name = url.split("?")[0].rstrip("/").split("/")[-1] or "reference_package.apk"
        if Path(name).suffix.lower() not in VALID_EXT:
            name += ".apk"
        print(f"  using supplied URL: {url}")
        result = (download(url, DEST / name), f"url {url}")

    if not result:
        result = try_release(token, repo, tag)
    if not result:
        result = try_reference_dir()

    if not result:
        print("No reference package found.")
        print("Add your .apk / .xapk as an asset of release 'v1.0-apk', "
              "or commit it under reference/, then re-run this workflow.")
        emit(FOUND="", SOURCE="none")
        return 0

    path, source = result
    size = path.stat().st_size
    if size < 1_000_000:
        print(f"WARNING: package is only {size} bytes - probably not a real build.")
    emit(FOUND=str(path.resolve()), SOURCE=source)
    return 0


if __name__ == "__main__":
    sys.exit(main())
