#!/usr/bin/env python3
"""
REA-style static analysis of an unpacked Android game build.

Reads : work/raw_apk/ (merged package contents) and work/decoded_apk/ (apktool output)
Writes: blueprint/reference/01..05 .md, _extraction_report.json, assets_inventory.csv

Design rule: nothing is invented. Every table cell is either read from the build
or explicitly marked as not present. Candidate identifiers scraped out of binary
strings are labelled as candidates, because string tables contain noise.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import subprocess
import sys
import wave
import xml.etree.ElementTree as ET
from collections import Counter, defaultdict
from pathlib import Path

IMG_EXT = {".png", ".jpg", ".jpeg", ".webp", ".gif", ".bmp", ".pvr", ".ktx", ".etc1", ".astc"}
AUDIO_EXT = {".ogg", ".mp3", ".wav", ".m4a", ".aac", ".opus", ".caf", ".xm", ".mod"}
FONT_EXT = {".ttf", ".otf", ".fnt", ".woff", ".woff2", ".bmfont"}
DATA_EXT = {".json", ".xml", ".plist", ".csv", ".txt", ".lvl", ".dat", ".bin", ".tmx", ".atlas", ".skel"}
SHEET_EXT = {".plist", ".atlas", ".json"}

AD_SDKS = [
    ("com/google/android/gms/ads", "Google AdMob"),
    ("com/google/android/ump", "Google UMP (consent)"),
    ("com/applovin", "AppLovin MAX"),
    ("com/ironsource", "ironSource / LevelPlay"),
    ("com/unity3d/ads", "Unity Ads"),
    ("com/unity3d/services", "Unity Services"),
    ("com/facebook/ads", "Meta Audience Network"),
    ("com/mintegral", "Mintegral"),
    ("com/mbridge", "Mintegral MBridge"),
    ("com/vungle", "Vungle / Liftoff"),
    ("com/inmobi", "InMobi"),
    ("com/chartboost", "Chartboost"),
    ("com/adcolony", "AdColony"),
    ("com/pangle", "Pangle / TikTok"),
    ("com/bytedance/sdk/openadsdk", "Pangle (ByteDance)"),
    ("com/tencent/qqgame", "Tencent GDT"),
    ("com/google/ads/mediation", "AdMob mediation adapters"),
    ("com/fyber", "Fyber / Digital Turbine"),
    ("com/smaato", "Smaato"),
    ("com/liftoff", "Liftoff"),
    ("com/appodeal", "Appodeal"),
    ("com/tapjoy", "Tapjoy"),
    ("com/supersonic", "ironSource (legacy)"),
    ("com/google/android/play/billing", "Google Play Billing"),
    ("com/android/billingclient", "Google Play Billing"),
    ("com/revmob", "RevMob"),
    ("com/mopub", "MoPub (sunset)"),
    ("com/amazon/device/ads", "Amazon Ads"),
]

OTHER_SDKS = [
    ("com/google/firebase", "Firebase"),
    ("com/google/android/gms/measurement", "Google Analytics"),
    ("com/adjust/sdk", "Adjust"),
    ("com/appsflyer", "AppsFlyer"),
    ("com/kochava", "Kochava"),
    ("com/singular", "Singular"),
    ("io/branch", "Branch"),
    ("com/onesignal", "OneSignal"),
    ("com/amplitude", "Amplitude"),
    ("com/mixpanel", "Mixpanel"),
    ("com/segment", "Segment"),
    ("com/clevertap", "CleverTap"),
    ("com/google/android/play/core", "Play Core (dynamic delivery)"),
    ("com/facebook/login", "Facebook Login"),
    ("com/facebook/appevents", "Facebook App Events"),
    ("org/cocos2dx", "Cocos2d-x"),
    ("com/cocos2dx", "Cocos2d-x (alt)"),
    ("com/unity3d/player", "Unity Engine"),
    ("com/epicgames", "Unreal Engine"),
    ("org/libsdl", "SDL2"),
    ("com/crashlytics", "Crashlytics"),
    ("com/google/firebase/crashlytics", "Crashlytics (Firebase)"),
    ("com/huawei", "Huawei HMS"),
    ("com/android/installreferrer", "Install Referrer"),
]

BOOSTER_KEYWORDS = [
    ("bomb", "Bomb / explosive bubble"),
    ("fire", "Fireball"),
    ("flame", "Flame"),
    ("rainbow", "Rainbow / colour-change"),
    ("lightning", "Lightning"),
    ("laser", "Laser / line clear"),
    ("rocket", "Rocket"),
    ("ice", "Ice / frosted blocker"),
    ("frost", "Frost blocker"),
    ("frozen", "Frozen blocker"),
    ("snow", "Snow / ice theme"),
    ("stone", "Stone blocker"),
    ("rock", "Rock blocker"),
    ("chain", "Chained blocker"),
    ("lock", "Locked bubble"),
    ("morph", "Morphing bubble"),
    ("ghost", "Ghost / invisible bubble"),
    ("star", "Star / score item"),
    ("coin", "Coin currency"),
    ("heart", "Life currency"),
    ("life", "Life currency"),
    ("gift", "Gift / reward"),
    ("wheel", "Daily spin wheel"),
    ("spin", "Spin wheel"),
    ("piggy", "Piggy bank"),
    ("chest", "Chest / reward container"),
    ("vip", "VIP"),
    ("crown", "Crown / trophy"),
]

SKU_HINT = re.compile(
    r"(coin|gem|diamond|pack|bundle|starter|vip|noads|no_ads|remove_ads|removeads|"
    r"booster|offer|special|subscription|sub_|pass|piggy|spin|life|lives|move|moves|"
    r"continue|revive|unlock)", re.I)
SKU_SHAPE = re.compile(r"^[a-z][a-z0-9]*(?:[._][a-z0-9]+){1,6}$")
CONFIG_HINT = re.compile(
    r"^(?:ad|ads|admob|applovin|is_|iron|interstitial|rewarded|banner|frequency|"
    r"show_|enable_|disable_|max_|min_|cap_|interval|cooldown|remote|config)", re.I)


# --------------------------------------------------------------------------- #
# helpers
# --------------------------------------------------------------------------- #
def human(n: int) -> str:
    if n >= 1 << 30:
        return f"{n / (1 << 30):.2f} GB"
    if n >= 1 << 20:
        return f"{n / (1 << 20):.2f} MB"
    if n >= 1024:
        return f"{n / 1024:.1f} KB"
    return f"{n} B"


def md_table(headers: list[str], rows: list[list], cap: int = 400) -> str:
    if not rows:
        return "_No rows._\n"
    out = ["| " + " | ".join(headers) + " |",
           "|" + "|".join(["---"] * len(headers)) + "|"]
    for r in rows[:cap]:
        cells = [str(c).replace("|", "\\|").replace("\n", " ") for c in r]
        out.append("| " + " | ".join(cells) + " |")
    if len(rows) > cap:
        out.append(f"\n_... {len(rows) - cap} more rows, see `assets_inventory.csv`._")
    return "\n".join(out) + "\n"


def h2(n: str, en: str, hi: str) -> str:
    return f"\n## {n}. {en}\n\n> **हिंदी:** {hi}\n"


def image_size(path: Path) -> tuple[int, int] | None:
    try:
        with open(path, "rb") as fh:
            head = fh.read(32)
            if head[:8] == b"\x89PNG\r\n\x1a\n":
                return int.from_bytes(head[16:20], "big"), int.from_bytes(head[20:24], "big")
            if head[:6] in (b"GIF87a", b"GIF89a"):
                return int.from_bytes(head[6:8], "little"), int.from_bytes(head[8:10], "little")
            if head[:4] == b"RIFF" and head[8:12] == b"WEBP":
                fh.seek(12)
                chunk = fh.read(4)
                if chunk == b"VP8 ":
                    fh.seek(26)
                    b = fh.read(4)
                    return int.from_bytes(b[:2], "little") & 0x3FFF, int.from_bytes(b[2:4], "little") & 0x3FFF
                if chunk == b"VP8L":
                    fh.seek(21)
                    b = fh.read(4)
                    v = int.from_bytes(b, "little")
                    return (v & 0x3FFF) + 1, ((v >> 14) & 0x3FFF) + 1
                if chunk == b"VP8X":
                    fh.seek(24)
                    b = fh.read(6)
                    return int.from_bytes(b[:3], "little") + 1, int.from_bytes(b[3:6], "little") + 1
            if head[:2] == b"\xff\xd8":
                fh.seek(2)
                while True:
                    marker = fh.read(2)
                    if len(marker) < 2 or marker[0] != 0xFF:
                        return None
                    if marker[1] in (0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7,
                                     0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF):
                        fh.read(3)
                        h, w = int.from_bytes(fh.read(2), "big"), int.from_bytes(fh.read(2), "big")
                        return w, h
                    seg = int.from_bytes(fh.read(2), "big")
                    fh.seek(seg - 2, 1)
    except Exception:  # noqa: BLE001
        return None
    return None


def parse_values(path: Path) -> list[tuple[str, str]]:
    rows: list[tuple[str, str]] = []
    try:
        root = ET.parse(path).getroot()
    except Exception:  # noqa: BLE001
        return rows
    for child in root:
        name = child.attrib.get("name", "")
        val = (child.text or "").strip()
        if name:
            rows.append((name, val))
    return rows


def plist_frames(path: Path) -> dict[str, str]:
    """Frame name -> frame rectangle, from a TexturePacker/cocos2d XML plist."""
    frames: dict[str, str] = {}
    try:
        root = ET.parse(path).getroot()
    except Exception:  # noqa: BLE001
        return frames
    for node in root.iter("dict"):
        kids = list(node)
        for i in range(0, len(kids) - 1, 2):
            if kids[i].tag != "key" or (kids[i].text or "") != "frames":
                continue
            fd = kids[i + 1]
            if fd.tag != "dict":
                continue
            items = list(fd)
            for j in range(0, len(items) - 1, 2):
                if items[j].tag != "key":
                    continue
                name = items[j].text or ""
                rect = None
                info = items[j + 1]
                if info.tag == "dict":
                    kv = list(info)
                    for k in range(0, len(kv) - 1, 2):
                        if kv[k].tag == "key" and (kv[k].text or "") in ("frame", "textureRect"):
                            rect = kv[k + 1].text
                if name:
                    frames[name] = rect or ""
    return frames


def audio_duration(path: Path) -> float | None:
    """Best-effort duration in seconds for wav / ogg / opus / mp3."""
    ext = path.suffix.lower()
    try:
        if ext == ".wav":
            with wave.open(str(path)) as w:
                return w.getnframes() / float(w.getframerate() or 1)
        if ext in (".ogg", ".opus"):
            with open(path, "rb") as fh:
                fh.seek(max(0, path.stat().st_size - 65536))
                blob = fh.read()
            idx = blob.rfind(b"OggS")
            if idx >= 0 and len(blob) >= idx + 14:
                granule = int.from_bytes(blob[idx + 6:idx + 14], "little")
                secs = granule / (48000.0 if ext == ".opus" else 44100.0)
                # granule positions can be missing or sentinel values; reject nonsense
                if 0 < secs < 3600:
                    return secs
                return None
        if ext in (".mp3", ".m4a", ".aac"):
            return path.stat().st_size * 8 / 128000.0   # 128 kbps assumption
    except Exception:  # noqa: BLE001
        return None
    return None


def walk(root: Path) -> list[dict]:
    items: list[dict] = []
    if not root.is_dir():
        return items
    for p in sorted(root.rglob("*")):
        if not p.is_file():
            continue
        try:
            size = p.stat().st_size
        except OSError:
            continue
        ext = p.suffix.lower()
        dims = image_size(p) if ext in IMG_EXT else None
        items.append({
            "path": str(p.relative_to(root)).replace("\\", "/"),
            "ext": ext,
            "size": size,
            "w": dims[0] if dims else "",
            "h": dims[1] if dims else "",
        })
    return items


def run(cmd: list[str], limit: int = 400_000) -> str:
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, errors="ignore", timeout=240)
        return (proc.stdout or "")[:limit]
    except Exception:  # noqa: BLE001
        return ""


def binary_strings(paths: list[Path], min_len: int = 5) -> set[str]:
    found: set[str] = set()
    for p in paths:
        out = run(["strings", f"-n{min_len}", str(p)], limit=8_000_000)
        for line in out.splitlines():
            s = line.strip()
            if 4 <= len(s) <= 120:
                found.add(s)
    return found


# --------------------------------------------------------------------------- #
# analysis
# --------------------------------------------------------------------------- #
class Build:
    def __init__(self, raw: Path, decoded: Path | None):
        self.raw = raw
        self.decoded = decoded
        self.manifest: dict = {}
        self.manifest_text = ""
        self.values: dict[str, list[tuple[str, str]]] = {}
        self.assets = walk(raw / "assets")
        self.res = walk(decoded / "res") if decoded and decoded.is_dir() else []
        self.libs = sorted(raw.glob("lib/**/*.so"))
        self.dex = sorted(raw.glob("*.dex"))
        self._so_strings: set[str] | None = None
        self._dex_strings: set[str] | None = None
        self.sdk_hits: dict[str, list[str]] = defaultdict(list)
        self._load_manifest()
        self._load_values()
        self._detect_sdks()

    # -- manifest ---------------------------------------------------------- #
    def _load_manifest(self) -> None:
        if not self.decoded:
            return
        mf = self.decoded / "AndroidManifest.xml"
        if not mf.exists():
            return
        self.manifest_text = mf.read_text(encoding="utf-8", errors="ignore")
        try:
            root = ET.parse(mf).getroot()
        except Exception:  # noqa: BLE001
            return
        ns = ""
        if root.tag.startswith("{"):
            ns = root.tag.split("}")[0] + "}"
        app = root.find(f"{ns}application")
        info = {
            "package": root.attrib.get("package", ""),
            "versionName": root.attrib.get(f"{{http://schemas.android.com/apk/res/android}}versionName", ""),
            "versionCode": root.attrib.get(f"{{http://schemas.android.com/apk/res/android}}versionCode", ""),
            "minSdk": "", "targetSdk": "",
            "permissions": [], "features": [], "components": [],
            "application": {}, "meta_data": [],
        }
        sdk = root.find(f"{ns}uses-sdk")
        if sdk is not None:
            a = sdk.attrib
            info["minSdk"] = a.get(f"{{http://schemas.android.com/apk/res/android}}minSdkVersion", "")
            info["targetSdk"] = a.get(f"{{http://schemas.android.com/apk/res/android}}targetSdkVersion", "")
        for p in root.findall(f"{ns}uses-permission"):
            info["permissions"].append(p.attrib.get(f"{{http://schemas.android.com/apk/res/android}}name", ""))
        for f in root.findall(f"{ns}uses-feature"):
            info["features"].append(f.attrib.get(f"{{http://schemas.android.com/apk/res/android}}name", ""))
        if app is not None:
            for key in ("name", "label", "icon", "theme", "allowBackup", "debuggable",
                        "hardwareAccelerated", "largeHeap", "extractNativeLibs"):
                info["application"][key] = app.attrib.get(
                    f"{{http://schemas.android.com/apk/res/android}}{key}", "")
            for tag in ("activity", "activity-alias", "service", "provider", "receiver"):
                for comp in app.findall(f"{ns}{tag}"):
                    name = comp.attrib.get(f"{{http://schemas.android.com/apk/res/android}}name", "")
                    actions, cats = [], []
                    for flt in comp.findall(f"{ns}intent-filter"):
                        for act in flt.findall(f"{ns}action"):
                            actions.append(act.attrib.get(f"{{http://schemas.android.com/apk/res/android}}name", ""))
                        for cat in flt.findall(f"{ns}category"):
                            cats.append(cat.attrib.get(f"{{http://schemas.android.com/apk/res/android}}name", ""))
                    info["components"].append({
                        "type": tag, "name": name,
                        "exported": comp.attrib.get(f"{{http://schemas.android.com/apk/res/android}}exported", ""),
                        "actions": actions, "categories": cats,
                    })
            for md in app.findall(f"{ns}meta-data"):
                info["meta_data"].append((
                    md.attrib.get(f"{{http://schemas.android.com/apk/res/android}}name", ""),
                    md.attrib.get(f"{{http://schemas.android.com/apk/res/android}}value", ""),
                ))
        self.manifest = info

    def _load_values(self) -> None:
        if not self.decoded:
            return
        vdir = self.decoded / "res" / "values"
        if not vdir.is_dir():
            return
        for f in sorted(vdir.glob("*.xml")):
            self.values[f.stem] = parse_values(f)

    # -- sdk detection ----------------------------------------------------- #
    def _haystack(self) -> str:
        parts = [self.manifest_text]
        parts += [a["path"] for a in self.assets]
        parts += [str(p.relative_to(self.raw)) for p in self.libs]
        return "\n".join(parts)

    def _detect_sdks(self) -> None:
        hay = self._haystack()
        dex = self.dex_strings()
        for pattern, label in AD_SDKS + OTHER_SDKS:
            dotted = pattern.replace("/", ".")
            evidence = []
            if pattern in hay or dotted in hay:
                evidence.append("manifest/assets path")
            hit = [s for s in dex if pattern in s.replace(".", "/") or dotted in s]
            if hit:
                evidence.append(f"{len(hit)} class refs in dex strings")
            if evidence:
                self.sdk_hits[label] = evidence
        for label in list(self.sdk_hits):
            if label.startswith("Google Play Billing"):
                self.sdk_hits[label].append("see billing section")

    # -- binary strings ---------------------------------------------------- #
    def so_strings(self) -> set[str]:
        if self._so_strings is None:
            self._so_strings = binary_strings(self.libs)
        return self._so_strings

    def dex_strings(self) -> set[str]:
        if self._dex_strings is None:
            self._dex_strings = binary_strings(self.dex)
        return self._dex_strings

    # -- derived views ----------------------------------------------------- #
    def colors(self) -> list[tuple[str, str]]:
        return self.values.get("colors", [])

    def strings(self) -> list[tuple[str, str]]:
        return self.values.get("strings", [])

    def booster_hits(self) -> dict[str, list[str]]:
        paths = [a["path"] for a in self.assets] + [r["path"] for r in self.res]
        out: dict[str, list[str]] = {}
        for kw, label in BOOSTER_KEYWORDS:
            hits = [p for p in paths if kw in p.lower()]
            if hits:
                out[label] = hits[:40]
        return out

    def level_files(self) -> dict[str, list[dict]]:
        grouped: dict[str, list[dict]] = defaultdict(list)
        for a in self.assets:
            if a["ext"] not in DATA_EXT:
                continue
            low = a["path"].lower()
            if not re.search(r"(level|stage|map|world|puzzle|board|grid)", low):
                continue
            if a["size"] > 8 * 1024 * 1024:
                continue
            grouped[str(Path(a["path"]).parent)].append(a)
        return dict(grouped)

    def atlas_summary(self) -> list[tuple[str, int, list[tuple[str, str]]]]:
        """(plist path, frame count, first few (frame name, rect)) for every spritesheet."""
        out = []
        for a in self.assets:
            if a["ext"] != ".plist":
                continue
            frames = plist_frames(self.raw / "assets" / a["path"])
            if frames:
                sample = [(k, v) for k, v in list(frames.items())[:4] if v]
                out.append((a["path"], len(frames), sample))
        out.sort(key=lambda t: -t[1])
        return out

    def audio_table(self) -> list[tuple[str, int, float | None]]:
        rows = []
        for a in self.assets:
            if a["ext"] in AUDIO_EXT:
                rows.append((a["path"], a["size"],
                             audio_duration(self.raw / "assets" / a["path"])))
        return rows

    def sku_candidates(self) -> list[str]:
        found = set()
        for s in self.dex_strings() | self.so_strings():
            if not SKU_SHAPE.match(s) or "." not in s:
                continue
            if len(s) < 8 or len(s) > 70:
                continue
            if SKU_HINT.search(s):
                found.add(s)
        return sorted(found)[:400]

    def config_candidates(self) -> list[str]:
        found = set()
        for s in self.dex_strings() | self.so_strings():
            if not re.match(r"^[a-z][a-z0-9_]{3,40}$", s):
                continue
            if CONFIG_HINT.match(s):
                found.add(s)
        return sorted(found)[:300]


# --------------------------------------------------------------------------- #
# document builders
# --------------------------------------------------------------------------- #
def doc_01(b: Build) -> str:
    m = b.manifest
    app = m.get("application", {})
    launchers = [c for c in m.get("components", [])
                 if c["type"] in ("activity", "activity-alias")
                 and any("LAUNCHER" in a for a in c["categories"])]
    boot = [c for c in m.get("components", [])
            if any("BOOT_COMPLETED" in a for a in c["actions"])]

    s = ["# 01 · Loading Screen, UI and Animations / लोडिंग स्क्रीन, UI और एनिमेशन\n",
         "> **हिंदी सार:** यह दस्तावेज़ आपके द्वारा दिए गए APK से निकाला गया है — ऐप कैसे शुरू होता है, "
         "कौन-सी स्क्रीन हैं, रंग (Hex) क्या हैं और कौन-सी एनिमेशन फ़ाइलें मौजूद हैं। "
         "जो चीज़ स्टैटिक विश्लेषण से साबित नहीं होती, उसे साफ़-साफ़ 'not derivable' लिखा गया है।\n",
         "> **English:** Everything below is read from the build you supplied. Values that cannot be "
         "proven by static analysis are marked as not derivable rather than guessed.\n",
         "---\n"]

    s.append(h2("1.1", "Build identity", "बिल्ड की पहचान"))
    s.append(md_table(["Field", "Value"], [
        ["Package", m.get("package") or "not found"],
        ["Version name", m.get("versionName") or "not found"],
        ["Version code", m.get("versionCode") or "not found"],
        ["Min SDK", m.get("minSdk") or "not declared"],
        ["Target SDK", m.get("targetSdk") or "not declared"],
        ["Application class", app.get("name") or "default android.app.Application"],
        ["Launcher activity", launchers[0]["name"] if launchers else "not found"],
        ["Native libs", f"{len(b.libs)} .so file(s)" if b.libs else "none (pure Java/Kotlin or asset-packed engine)"],
        ["Dex files", f"{len(b.dex)}"],
        ["Assets entries", f"{len(b.assets)}"],
    ]))

    s.append(h2("1.2", "Cold start chain", "ऐप शुरू होने का क्रम"))
    if launchers:
        s.append("Tapping the icon resolves to the launcher activity below. "
                 "The application class runs before any activity, so global SDK init happens there.\n")
        s.append(md_table(["Step", "Component"], [
            ["1", f"`{app.get('name') or 'Application'}` — process start, SDK init"],
            ["2", f"`{launchers[0]['name']}` — first Activity (LAUNCHER)"],
            ["3", "engine boot — see the native-lib section below for the engine that is present"],
        ]))
    else:
        s.append("_No LAUNCHER activity was found in the decoded manifest._\n")
    if boot:
        s.append("**Receivers that start the app in the background:** "
                 + ", ".join(f"`{c['name']}`" for c in boot) + "\n")

    s.append(h2("1.3", "All components", "मैनिफ़ेस्ट के सभी कंपोनेंट"))
    s.append(md_table(["Type", "Name", "Exported", "Intent actions"],
                      [[c["type"], f"`{c['name']}`", c["exported"] or "-",
                        ", ".join(a.split(".")[-1] for a in c["actions"]) or "-"]
                       for c in m.get("components", [])], cap=200))

    s.append(h2("1.4", "Colour palette (res/values/colors.xml)",
                "रंग पैलेट — असली Hex कोड"))
    cols = b.colors()
    if cols:
        s.append(f"{len(cols)} colours were declared. Use this table as the source of truth when you "
                 "rebuild the art direction for your own game.\n")
        s.append(md_table(["Token", "Hex / value"], cols, cap=250))
    else:
        s.append("_No `res/values/colors.xml` found — colours may be hard-coded in code or in engine config._\n")

    s.append(h2("1.5", "Dimensions and typography", "साइज़ और टाइपोग्राफ़ी"))
    dims = b.values.get("dimens", [])
    s.append(f"`dimens.xml` declares **{len(dims)}** entries.\n" if dims else "_No dimens.xml._\n")
    if dims:
        s.append(md_table(["Token", "Value"], dims, cap=80))
    styles = b.values.get("styles", [])
    if styles:
        s.append(f"\n`styles.xml` declares **{len(styles)}** styles — the list below is where the "
                 "splash/window theme and the HUD text styles live.\n")
        s.append(md_table(["Style", "Value"], styles, cap=80))

    s.append(h2("1.6", "UI strings that reveal the screen set", "स्क्रीन के नाम बताने वाले स्ट्रिंग्स"))
    keys = re.compile(r"(coin|life|lives|buy|shop|store|spin|wheel|piggy|vip|level|stage|"
                      r"daily|gift|event|offer|reward|ad|continue|move|booster|pause|win|lose|"
                      r"fail|star|setting|sound|music|privacy|terms|loading|tap)", re.I)
    picked = [(k, v) for k, v in b.strings() if keys.search(k) or keys.search(v)]
    s.append(f"{len(b.strings())} strings total; **{len(picked)}** look like UI copy for the HUD, "
             "store, popups and result screens.\n")
    s.append(md_table(["Key", "Value"], picked, cap=180))

    s.append(h2("1.7", "Layouts", "लेआउट फ़ाइलें"))
    layouts = [r for r in b.res if r["path"].startswith("layouts/") or "/layout" in "/" + r["path"]]
    if layouts:
        s.append(md_table(["Layout file", "Size"], [[f"`{r['path']}`", human(r["size"])] for r in layouts], cap=120))
    else:
        s.append("_No `res/layout/` XML — the UI is drawn by the game engine (canvas/GL), not by Android views. "
                 "That means every screen in this game is an engine scene, not an Activity._\n")

    s.append(h2("1.8", "Animation and VFX assets actually present",
                "मौजूद एनिमेशन और VFX फ़ाइलें"))
    anim_pat = re.compile(r"(anim|spine|skel|atlas|plist|particle|effect|fx|transition|pop|burst|"
                          r"explode|splash|loading|splash|logo)", re.I)
    anims = [a for a in b.assets if anim_pat.search(a["path"]) and a["ext"] in (SHEET_EXT | DATA_EXT | IMG_EXT)]
    if anims:
        s.append(f"{len(anims)} animation-related files. A `.plist` + `.png` pair is a sprite atlas "
                 "(frames + coordinates); `.skel` + `.atlas` is Spine skeletal animation.\n")
        s.append(md_table(["Path", "Size", "Dimensions"],
                          [[f"`{a['path']}`", human(a["size"]), f"{a['w']}×{a['h']}" if a["w"] else "-"]
                           for a in anims], cap=150))
    else:
        s.append("_No animation files matched. The engine may store them with opaque names — "
                 "check the atlas inventory in document 04._\n")

    s.append(h2("1.9", "Engine and native layer", "इंजन और नेटिव लेयर"))
    if b.libs:
        so_strings = b.so_strings()
        engines = [k for k in ("cocos2d", "cocos", "spine", "box2d", "chipmunk", "skia",
                               "lua", "unity", "unreal", "SDL", "libGDX", "fmod", "openal",
                               "libwebsockets", "curl")
                   if any(k.lower() in s.lower() for s in list(so_strings)[:200000])]
        s.append(md_table(["Library", "ABI", "Size", "Engine markers"],
                          [[f"`{p.name}`", p.parent.name, human(p.stat().st_size),
                            ", ".join(engines) or "-"] for p in b.libs], cap=60))
        s.append("\nReading the engine markers tells you what you are rebuilding: a Cocos2d-x game "
                 "is scene-graph based with `.plist` atlases and Lua/C++ logic; a Unity game ships "
                 "`libunity.so` with IL2CPP and asset bundles.\n")
    else:
        s.append("_No native libraries — logic lives in dex only._\n")

    s.append(h2("1.10", "What cannot be read statically", "जो स्टैटिक रूप से नहीं पढ़ा जा सकता"))
    s.append("Be honest with yourself about these gaps; they are where you must design your own values:\n\n"
             "- Exact splash timing, easing curves and transition durations — these live in engine code "
             "or in serialised scene files, not in a readable table.\n"
             "- Sprite-to-state mapping (which PNG is the 'loading bar' vs the 'coin icon') needs the "
             "atlas frame names plus a visual pass; open the atlases in document 04 and label them.\n"
             "- Server-driven UI (if any) only appears at runtime in network traffic.\n"
             "- Any value behind `FirebaseRemoteConfig` is fetched at runtime and is not in the APK.\n")
    return "\n".join(s)


def doc_02(b: Build) -> str:
    s = ["# 02 · Bubbles, Boosters and the Level System / बबल, बूस्टर और लेवल सिस्टम\n",
         "> **हिंदी सार:** इस फ़ाइल में बिल्ड से निकले बबल/बूस्टर/ब्लॉकर आर्ट, लेवल फ़ाइलों की सूची, "
         "लेवल डेटा का असली स्कीमा और स्कोर/स्टार से जुड़े सुराग हैं। लेवल की संख्या वही है जो "
         "आपके APK में असल में मौजूद है।\n",
         "> **English:** Bubble/booster/blocker art, the level files that are really in the build, "
         "their schema, and the scoring evidence. No level counts are invented.\n",
         "---\n"]

    s.append(h2("2.1", "Bubble and booster art inventory", "बबल और बूस्टर आर्ट"))
    hits = b.booster_hits()
    if hits:
        s.append("Files were grouped by keyword in their path. A keyword hit is evidence the asset "
                 "exists, not proof of its exact rule — pair this with a visual pass.\n")
        for label, paths in hits.items():
            s.append(f"\n**{label}** — {len(paths)} file(s)\n")
            s.append(md_table(["Path"], [[f"`{p}`"] for p in paths], cap=25))
    else:
        s.append("_No booster keywords in asset paths — names are likely opaque hashes. "
                 "Use the atlas frame names in document 04 instead._\n")

    s.append(h2("2.2", "Colour tokens for bubble skins", "बबल रंगों के टोकन"))
    colour_kw = re.compile(r"(red|blue|green|yellow|purple|orange|pink|cyan|white|black|brown|"
                           r"bubble|ball|orb|gem)", re.I)
    col_rows = [(k, v) for k, v in b.colors() if colour_kw.search(k)]
    s.append(md_table(["Token", "Hex"], col_rows, cap=80) if col_rows
             else "_No colour tokens matched bubble keywords._\n")

    s.append(h2("2.3", "Level files found in the build", "बिल्ड में मिली लेवल फ़ाइलें"))
    grouped = b.level_files()
    if grouped:
        total = sum(len(v) for v in grouped.values())
        s.append(f"**{total} level-like file(s)** across {len(grouped)} folder(s). "
                 "This is the real level count for your build — nothing added, nothing estimated.\n")
        s.append(md_table(["Folder", "Files", "Extension", "Total size", "Sample names"],
                          [[f"`{d}`", len(v), sorted({x['ext'] for x in v})[0],
                            human(sum(x["size"] for x in v)),
                            ", ".join(f"`{Path(x['path']).name}`" for x in v[:3])]
                           for d, v in grouped.items()], cap=40))
    else:
        s.append("_No level files matched the heuristics (path contains level/stage/map/world and a data "
                 "extension). Levels may be inside a binary bundle or an atlas-adjacent `.dat`. "
                 "Search document 04 for large `.json`/`.dat` files._\n")

    s.append(h2("2.4", "Level schema as decoded", "लेवल फ़ाइल का असली स्कीमा"))
    schema_found = False
    for d, files in list(grouped.items())[:3]:
        sample = sorted(files, key=lambda x: x["size"])[0]
        path = b.raw / "assets" / sample["path"]
        text = ""
        try:
            text = path.read_text(encoding="utf-8", errors="ignore")[:20000]
        except Exception:  # noqa: BLE001
            pass
        if sample["ext"] != ".json" or not text.strip():
            continue
        try:
            data = json.loads(text)
        except Exception:  # noqa: BLE001
            s.append(f"`{sample['path']}` is not plain JSON (maybe encoded/compressed).\n")
            continue
        schema_found = True
        if isinstance(data, dict):
            keys = list(data.keys())
            s.append(f"\n**Sample:** `{sample['path']}` — top-level object with {len(keys)} keys.\n")
            s.append(md_table(["Key", "Type", "Example value"],
                              [[k, type(data[k]).__name__,
                                (json.dumps(data[k])[:90] if not isinstance(data[k], str) else data[k][:90])]
                               for k in keys[:40]]))
        elif isinstance(data, list):
            s.append(f"\n**Sample:** `{sample['path']}` — top-level array with {len(data)} entries.\n")
            if data and isinstance(data[0], dict):
                s.append(md_table(["Key", "Type", "Example value"],
                                  [[k, type(data[0][k]).__name__,
                                    (json.dumps(data[0][k])[:90] if not isinstance(data[0][k], str)
                                     else data[0][k][:90])] for k in list(data[0].keys())[:40]]))
            s.append(f"\nFirst entry, verbatim (truncated):\n\n```json\n{json.dumps(data[0])[:1500]}\n```\n")
    if not schema_found:
        s.append("_No readable JSON level schema. If levels are compiled into the engine, treat the "
                 "schema in `blueprint/original/03_LEVEL_SCHEMA_AND_BALANCE.md` as your own design "
                 "starting point instead of a copy._\n")

    s.append(h2("2.5", "Scoring and star thresholds", "स्कोर और स्टार थ्रेशोल्ड"))
    score_kw = re.compile(r"(star|score|threshold|target|three_star|stars)", re.I)
    score_hits = [k for k, _ in b.strings() if score_kw.search(k)]
    score_strings = sorted(x for x in b.dex_strings() | b.so_strings()
                           if score_kw.search(x) and len(x) < 60)[:40]
    s.append(md_table(["Source", "Evidence"],
                      [["res/values/strings.xml", ", ".join(f"`{k}`" for k in score_hits[:20]) or "none"]]
                      + [["binary string", f"`{x}`"] for x in score_strings[:30]]))
    s.append("\nStar thresholds are almost always per-level data. If 2.3 found no level files, they are "
             "server-side or compiled in — define your own curve (see the original blueprint) rather than "
             "guessing at theirs.\n")

    s.append(h2("2.6", "Grid geometry you must derive yourself",
                "ग्रिड ज्यामिति — खुद निकालनी होगी"))
    s.append("A staggered bubble grid has three numbers that decide the whole feel: bubble diameter `d`, "
             "row pitch `d·√3/2 ≈ 0.866d`, and the half-diameter offset on every odd row. Measure `d` from "
             "a bubble sprite in document 04 and you can reconstruct the board geometry exactly:\n\n"
             "```\nx(q, r) = margin + q·d + (r % 2)·(d/2)\ny(r)   = top + r·(d·√3/2)\n```\n\n"
             "The full matching, snapping and falling-bubble algorithm is written out in "
             "`blueprint/original/02_HEXGRID_PHYSICS_AND_MATCHING.md`.\n")
    return "\n".join(s)


def doc_03(b: Build) -> str:
    m = b.manifest
    s = ["# 03 · Store, IAP, Economy and Ad Mediation / स्टोर, IAP, अर्थव्यवस्था और विज्ञापन\n",
         "> **हिंदी सार:** इस बिल्ड में मौजूद बिलिंग लाइब्रेरी, विज्ञापन SDK, संभावित SKU नाम और "
         "रिमोट-कॉन्फ़िग कीवर्ड। 'Candidate' वाली सूचियाँ बाइनरी स्ट्रिंग्स से निकली हैं — "
         "उन्हें अपने बिल्ड में जाँच लें, वे अंदाज़ा नहीं बल्कि साक्ष्य हैं।\n",
         "> **English:** Billing libraries, ad SDKs, SKU-shaped identifiers and remote-config-shaped "
         "keys present in this build. Candidate lists are scraped from binary string tables and are "
         "labelled as candidates, not asserted as fact.\n",
         "---\n"]

    s.append(h2("3.1", "SDKs detected", "पाए गए SDK"))
    rows = [[label, "; ".join(ev)] for label, ev in sorted(b.sdk_hits.items())]
    s.append(md_table(["SDK", "Evidence"], rows) if rows
             else "_No known ad/analytics SDK patterns matched._\n")

    s.append(h2("3.2", "Ad and billing permissions", "विज्ञापन और बिलिंग परमिशन"))
    perm_kw = re.compile(r"(billing|BILLING|AD_ID|INTERNET|ACCESS_NETWORK|com.google.android.finsky|"
                         r"INSTALL_REFERRER|AD_SERVICES|POST_NOTIFICATIONS)", re.I)
    perms = [p for p in m.get("permissions", []) if perm_kw.search(p)]
    s.append(md_table(["Permission"], [[f"`{p}`"] for p in perms]) if perms
             else "_None matched._\n")
    meta = [f"`{k}` = `{v}`" for k, v in m.get("meta_data", [])
            if re.search(r"(ads|admob|applovin|billing|firebase|com.google)", k, re.I)]
    if meta:
        s.append("\n**Relevant manifest meta-data**\n\n" + "\n".join(f"- {x}" for x in meta) + "\n")

    s.append(h2("3.3", "Store SKU candidates", "स्टोर SKU के संभावित नाम"))
    skus = b.sku_candidates()
    s.append(f"{len(skus)} string(s) shaped like a product id (`a.b.c`, 8-70 chars, money-related keyword). "
             "Cross-check each one against Play Console or a live purchase flow before relying on it.\n")
    s.append(md_table(["Candidate identifier"], [[f"`{x}`"] for x in skus], cap=250)
             if skus else "_No SKU-shaped strings found._\n")

    s.append(h2("3.4", "Remote-config / ad-tuning candidates",
                "रिमोट कॉन्फ़िग और विज्ञापन सेटिंग के संभावित की"))
    cfgs = b.config_candidates()
    s.append(md_table(["Candidate key"], [[f"`{x}`"] for x in cfgs], cap=200) if cfgs
             else "_No config-shaped keys found._\n")
    s.append("\nThese are key-shaped strings only. Actual values arrive from the network at runtime.\n")

    s.append(h2("3.5", "Rewarded and interstitial evidence", "रिवॉर्डेड और इंटरस्टीशियल के सुराग"))
    ev = sorted(x for x in b.dex_strings() | b.so_strings()
                if re.search(r"(rewarded|interstitial|banner|native_ad|app_open|"
                             r"offerwall|frequency|cooldown|impression)", x, re.I)
                and len(x) < 70)[:80]
    s.append(md_table(["Binary string"], [[f"`{x}`"] for x in ev]) if ev
             else "_None found._\n")

    s.append(h2("3.6", "What you must design yourself", "जो आपको खुद तय करना है"))
    s.append("Prices, coin amounts, regen timers and ad caps are never fully readable from an APK — "
             "they are either server-driven or compiled into balance tables you cannot attribute. "
             "The economy and ad-trigger design in `blueprint/original/04_ECONOMY_AND_AD_MEDIATION.md` "
             "gives you a complete, self-consistent set of your own numbers instead.\n\n"
             "**Compliance note:** rewarded and interstitial placement is regulated. For India, the "
             "Digital Personal Data Protection Act 2023 applies to any data you collect; Google Play's "
             "Families policy applies if your audience skews young, and ads in a child-directed app "
             "must come from a certified SDK with no personalised targeting. Use test ad unit IDs in "
             "development, never production IDs belonging to someone else.\n")
    return "\n".join(s)


def doc_04(b: Build) -> str:
    s = ["# 04 · Complete Assets Catalog / पूरा एसेट कैटलॉग\n",
         "> **हिंदी सार:** `assets/` और `res/` का हर फ़ाइल-दर-फ़ाइल रिकॉर्ड — साइज़, इमेज के "
         "आयाम और फ़ोल्डर-वार जानकारी। पूरी सूची `assets_inventory.csv` में है; यहाँ हर फ़ोल्डर का "
         "सारांश है।\n",
         "> **English:** A file-by-file record of `assets/` and `res/` with sizes and image dimensions. "
         "The full dump is `assets_inventory.csv` next to this file; the tables here are per-folder "
         "summaries.\n",
         "---\n"]

    all_items = b.assets + b.res
    by_ext: Counter = Counter()
    size_by_ext: Counter = Counter()
    for a in all_items:
        by_ext[a["ext"] or "(none)"] += 1
        size_by_ext[a["ext"] or "(none)"] += a["size"]
    s.append(h2("4.1", "Totals by file type", "फ़ाइल टाइप के अनुसार कुल"))
    s.append(md_table(["Extension", "Files", "Total size"],
                      [[e, by_ext[e], human(size_by_ext[e])]
                       for e in sorted(by_ext, key=lambda x: -size_by_ext[x])], cap=40))
    s.append(f"\n**Grand total:** {len(all_items)} files, {human(sum(size_by_ext.values()))}.\n")

    s.append(h2("4.2", "Folder map", "फ़ोल्डर मैप"))
    folders: Counter = Counter()
    fsize: Counter = Counter()
    for a in all_items:
        top = str(Path(a["path"]).parent)
        folders[top] += 1
        fsize[top] += a["size"]
    s.append(md_table(["Folder", "Files", "Size"],
                      [[f"`{d}`", folders[d], human(fsize[d])]
                       for d in sorted(folders, key=lambda x: -fsize[x])], cap=120))

    s.append(h2("4.3", "Images with dimensions", "इमेज और उनके आयाम"))
    imgs = [a for a in all_items if a["ext"] in IMG_EXT]
    imgs.sort(key=lambda a: -a["size"])
    s.append(f"{len(imgs)} image files. Dimensions are read from the file headers. Large files are "
             "usually atlases (many sprites in one sheet); small ones are single icons.\n")
    s.append(md_table(["Path", "Size", "W×H"],
                      [[f"`{a['path']}`", human(a["size"]), f"{a['w']}×{a['h']}" if a["w"] else "unread"]
                       for a in imgs], cap=200))

    s.append(h2("4.4", "Audio", "ऑडियो"))
    audio = [a for a in all_items if a["ext"] in AUDIO_EXT]
    s.append(f"{len(audio)} audio file(s), {human(sum(a['size'] for a in audio))} total.\n")
    s.append(md_table(["Path", "Size"], [[f"`{a['path']}`", human(a["size"])] for a in audio], cap=150)
             if audio else "_No audio files found._\n")

    s.append(h2("4.5", "Fonts", "फ़ॉन्ट"))
    fonts = [a for a in all_items if a["ext"] in FONT_EXT]
    s.append(md_table(["Path", "Size"], [[f"`{a['path']}`", human(a["size"])] for a in fonts], cap=60)
             if fonts else "_No font files found._\n")
    s.append("\nA `.fnt` file is a BMFont descriptor and needs its matching page PNG; `.ttf`/`.otf` are "
             "vector fonts you must license separately if you ship them.\n")

    s.append(h2("4.6", "Sprite sheets and data", "स्प्राइटशीट और डेटा"))
    sheets = [a for a in all_items if a["ext"] in SHEET_EXT]
    s.append(md_table(["Path", "Size"],
                      [[f"`{a['path']}`", human(a["size"])] for a in sheets], cap=150) if sheets
             else "_None found._\n")

    s.append(h2("4.7", "Sprite atlas frame rectangles", "स्प्राइट एटलस के फ़्रेम और उनके आयाम"))
    atlases = b.atlas_summary()
    if atlases:
        s.append(f"{len(atlases)} atlas descriptor(s) parsed. Each row below is one `.plist`; the sample "
                 "column shows the actual frame rectangles, which is how you learn the sprite grid "
                 "(frame size, spacing, pivot) you need to match in your own atlas.\n")
        s.append(md_table(
            ["Atlas", "Frames", "Sample frame -> rectangle"],
            [[f"`{p}`", n, "; ".join(f"{k}: {v}" for k, v in sample) or "-"]
             for p, n, sample in atlases], cap=60))
    else:
        s.append("_No XML `.plist` atlases with frame data found. JSON atlases are reported in 4.6._\n")

    s.append(h2("4.8", "Audio durations", "ऑडियो फ़ाइलों की असली अवधि"))
    audio_rows = b.audio_table()
    if audio_rows:
        total = sum(r[1] for r in audio_rows)
        s.append(f"{len(audio_rows)} audio file(s), {human(total)} total. Durations are read from the "
                 "file headers (WAV exact, OGG from the granule position, MP3/M4A estimated).\n")
        s.append(md_table(["Path", "Size", "Duration"],
                          [[f"`{p}`", human(sz), f"{d:.2f} s" if d else "unknown"]
                           for p, sz, d in audio_rows], cap=200))
    else:
        s.append("_No audio files found in `assets/`._\n")

    s.append(h2("4.9", "How to use this catalog", "इस कैटलॉग का उपयोग कैसे करें"))
    s.append("Treat this as an **inventory of what exists**, not as a library you may ship. The art, "
             "audio and fonts belong to the original publisher. What transfers legitimately is the "
             "*knowledge*: target dimensions, density buckets, atlas granularity, audio format choice, "
             "naming conventions. Rebuild the files yourself at the sizes listed here — "
             "`blueprint/original/01_ARCHITECTURE_AND_STACK.md` has the asset-pipeline spec that does "
             "exactly that.\n")
    return "\n".join(s)


def doc_05(b: Build) -> str:
    m = b.manifest
    grouped = b.level_files()
    total_levels = sum(len(v) for v in grouped.values())
    cols = len(b.colors())
    sdk_list = sorted(b.sdk_hits)
    s = ["# 05 · Master AI Game Builder Prompt / मास्टर AI गेम-बिल्डर प्रॉम्प्ट\n",
         "> **हिंदी सार:** यह एक ही फ़ाइल में पूरा स्पेक है जो आप किसी भी AI को दे सकते हैं। "
         "नीचे दिए गए मान इस बिल्ड से निकाले गए हैं; जहाँ डेटा नहीं था वहाँ साफ़ लिखा है।\n",
         "> **English:** A single self-contained brief you can hand to any AI coding agent. The values "
         "in section 05.2 are extracted from your build; gaps are marked so the agent does not "
         "hallucinate around them.\n",
         "---\n",
         "```text\nYou are building an original bubble-shooter game. Build it from scratch; do not copy\n"
         "any third-party art, audio, fonts, level data or code. Everything below is either a hard\n"
         "requirement or a design default you may tune.\n```\n"]

    s.append(h2("5.1", "Target platform and stack", "प्लैटफ़ॉर्म और स्टैक"))
    s.append(f"Reference build analysed: `{m.get('package') or 'unknown'}` "
             f"v{m.get('versionName') or '?'} (versionCode {m.get('versionCode') or '?'}), "
             f"minSdk {m.get('minSdk') or '?'}, targetSdk {m.get('targetSdk') or '?'}.\n\n"
             "Recommended stack for an original build: **Cocos Creator 3.x (TypeScript)** or "
             "**Unity 6 (C#)** for the client — both handle 2D sprite batching, tween animation and "
             "Play Billing plugins well. A **Node/TypeScript + Phaser 3** web build is faster to iterate "
             "and can be wrapped with Capacitor for Android. Pick one and stay with it.\n")

    s.append(h2("5.2", "Hard facts extracted from the reference build",
                "रेफ़रेंस बिल्ड से निकले ठोस तथ्य"))
    s.append(md_table(["Fact", "Value", "Confidence"], [
        ["Level files present in build", f"{total_levels}", "read from package" if total_levels else "none found"],
        ["Declared colour tokens", f"{cols}", "read from res/values/colors.xml" if cols else "none found"],
        ["Total asset files", f"{len(b.assets)} in assets/, {len(b.res)} in res/", "read from package"],
        ["Native libraries", f"{len(b.libs)}", "read from package"],
        ["Ad/analytics SDKs", ", ".join(sdk_list) if sdk_list else "none matched", "pattern match"],
        ["Bubble diameter reference", "measure from the largest bubble sprite in doc 04", "needs a visual pass"],
        ["Grid columns / rows", "not present in a readable table", "must be measured or chosen"],
    ]))

    s.append(h2("5.3", "Non-negotiable mechanics", "अनिवार्य मैकेनिक्स"))
    s.append("1. Staggered (hex-style) grid: row pitch `d·√3/2`, odd rows offset by `d/2`.\n"
             "2. Cannon at bottom-centre; aim with drag; trajectory preview with up to 3 wall bounces.\n"
             "3. Projectile snaps to the nearest free cell adjacent to the first bubble it touches.\n"
             "4. Match-3-or-more of the same colour pops; disconnected clusters then fall.\n"
             "5. Win when the objective is met; lose when the shot counter hits zero.\n"
             "6. Next-bubble preview plus a swap slot.\n"
             "7. Deterministic level replay: same seed, same colour sequence.\n")

    s.append(h2("5.4", "What to generate, in order", "किस क्रम में बनाना है"))
    s.append("1. Project skeleton + scene graph + save system.\n"
             "2. Grid model, snapping, match BFS, floating BFS, projectile physics (doc 02 of the "
             "original blueprint has the exact algorithms).\n"
             "3. Level schema, loader and 30 hand-tuned levels.\n"
             "4. UI flow: boot → splash → loading → map → level → result (doc 01).\n"
             "5. Economy, store, Play Billing, receipt validation (doc 04).\n"
             "6. Ads: one mediation SDK, rewarded + interstitial with caps and consent.\n"
             "7. Analytics events, crash reporting, remote config.\n"
             "8. Polish pass: audio, haptics, juice, accessibility.\n")

    s.append(h2("5.5", "Explicit exclusions", "जो नहीं करना है"))
    s.append("- Do not ship or embed any file from the reference APK.\n"
             "- Do not reuse the original package name, app icon, store listing text or screenshots.\n"
             "- Do not reproduce the original publisher's trademark or level names.\n"
             "- Do not use production ad unit IDs or billing product IDs you do not own.\n")
    return "\n".join(s)


# --------------------------------------------------------------------------- #
def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--raw", default="work/raw_apk")
    ap.add_argument("--decoded", default="work/decoded_apk")
    ap.add_argument("--out", default="blueprint/reference")
    args = ap.parse_args()

    raw = Path(args.raw)
    decoded = Path(args.decoded)
    if not raw.is_dir():
        print(f"::error::raw tree not found: {raw}")
        return 1
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    print("Analysing build ...")
    b = Build(raw, decoded if decoded.is_dir() else None)
    print(f"  assets={len(b.assets)} res={len(b.res)} libs={len(b.libs)} dex={len(b.dex)} "
          f"sdks={len(b.sdk_hits)}")

    builders = [
        ("01_LOADING_SCREEN_UI_AND_ANIMATIONS.md", doc_01),
        ("02_BUBBLES_BOOSTERS_AND_LEVELS_SYSTEM.md", doc_02),
        ("03_STORE_IAP_AND_MONETIZATION_ADS.md", doc_03),
        ("04_COMPLETE_ASSETS_CATALOG.md", doc_04),
        ("05_MASTER_AI_GAME_BUILDER_PROMPT.md", doc_05),
    ]
    written = []
    for name, fn in builders:
        try:
            body = fn(b)
        except Exception as exc:  # noqa: BLE001
            print(f"  WARN {name} builder failed: {exc}")
            body = f"# {name}\n\n_Generation failed: {exc}_\n"
        if len(body) < 400:
            print(f"::error::{name} came out empty - refusing to publish a hollow blueprint")
            return 1
        (out / name).write_text(body, encoding="utf-8")
        written.append({"file": name, "bytes": len(body)})
        print(f"  wrote {name} ({len(body)} chars)")

    with open(out / "assets_inventory.csv", "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(["tree", "path", "extension", "bytes", "width", "height"])
        for a in b.assets:
            w.writerow(["assets", a["path"], a["ext"], a["size"], a["w"], a["h"]])
        for a in b.res:
            w.writerow(["res", a["path"], a["ext"], a["size"], a["w"], a["h"]])

    report = {
        "package": b.manifest.get("package"),
        "version": b.manifest.get("versionName"),
        "counts": {"assets": len(b.assets), "res": len(b.res),
                   "native_libs": len(b.libs), "dex": len(b.dex),
                   "colours": len(b.colors()), "strings": len(b.strings()),
                   "level_files": sum(len(v) for v in b.level_files().values())},
        "sdks": {k: v for k, v in b.sdk_hits.items()},
        "documents": written,
    }
    (out / "_extraction_report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report["counts"], indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
