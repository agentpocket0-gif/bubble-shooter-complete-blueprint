#!/usr/bin/env python3
"""Inject the publisher's persistent Android upload key without committing it."""
from __future__ import annotations
import base64
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "godot_project"
PRESET = PROJECT / "export_presets.cfg"
KEYSTORE = PROJECT / "build" / "upload-key.keystore"

def quote(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'

def main() -> int:
    required = ["ANDROID_KEYSTORE_BASE64", "ANDROID_KEYSTORE_PASSWORD", "ANDROID_KEY_ALIAS", "ANDROID_KEY_PASSWORD"]
    missing = [name for name in required if not os.environ.get(name)]
    if missing:
        raise SystemExit("Missing required signing secrets: " + ", ".join(missing))
    try:
        key_bytes = base64.b64decode(os.environ["ANDROID_KEYSTORE_BASE64"], validate=True)
    except Exception as exc:
        raise SystemExit("ANDROID_KEYSTORE_BASE64 is not valid base64") from exc
    if not key_bytes:
        raise SystemExit("Decoded Android keystore is empty")
    KEYSTORE.parent.mkdir(parents=True, exist_ok=True)
    KEYSTORE.write_bytes(key_bytes)
    text = PRESET.read_text(encoding="utf-8")
    changes = {
        'keystore/release="build/upload-key.keystore"': 'keystore/release=' + quote("build/upload-key.keystore"),
        'keystore/release_user="UPLOAD_KEY_ALIAS"': 'keystore/release_user=' + quote(os.environ["ANDROID_KEY_ALIAS"]),
        'keystore/release_password="UPLOAD_KEY_PASSWORD"': 'keystore/release_password=' + quote(os.environ["ANDROID_KEY_PASSWORD"])
    }
    for marker, replacement in changes.items():
        if marker not in text:
            raise SystemExit("Signing preset placeholder missing: " + marker)
        text = text.replace(marker, replacement)
    PRESET.write_text(text, encoding="utf-8")
    print("Publisher upload keystore staged; key contents and passwords were not printed.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
