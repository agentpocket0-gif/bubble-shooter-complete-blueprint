# Prompt for your terminal agent

Copy everything inside the box below and paste it into your terminal agent app (Termux + any AI agent).
It is written so the agent needs no other explanation.

---

```text
You are running inside Termux on an Android phone. Your job is to extract an APK
file into a normal folder on the phone's storage, and also produce a zip of the
result. Work step by step, show me each command, and stop and ask if something
is ambiguous.

STEP 0 — storage access (run once per Termux install)
  termux-setup-storage
  (accept the Android permission dialog)

STEP 1 — find the APK
  ls -lh /sdcard/Download/*.apk /sdcard/Download/*.xapk /sdcard/Download/*.part* 2>/dev/null
  If nothing is listed, ask me for the exact path before continuing.

STEP 2 — if the file is split into parts, join them first
  cd /sdcard/Download
  cat <name>.apk.part* > full_game.apk
  (replace <name> with the actual prefix; verify the result with `unzip -t full_game.apk`)

STEP 3 — install the tools
  pkg update -y && pkg install -y unzip zip

STEP 4 — test the archive before extracting
  unzip -t "<apk path>" | tail -5
  If this reports errors, stop and tell me exactly which entries failed.

STEP 5 — extract into a real folder
  mkdir -p "/sdcard/Download/Extracted/<apk name without extension>"
  unzip -o "<apk path>" -d "/sdcard/Download/Extracted/<apk name without extension>"

STEP 6 — verify
  find "/sdcard/Download/Extracted/<apk name without extension>" -type f | wc -l
  du -sh "/sdcard/Download/Extracted/<apk name without extension>"
  ls "/sdcard/Download/Extracted/<apk name without extension>"

STEP 7 — also produce a zip of the extracted folder
  cd /sdcard/Download/Extracted
  zip -r "<apk name without extension>.zip" "<apk name without extension>"
  ls -lh "/sdcard/Download/Extracted/<apk name without extension>.zip"

STEP 8 — report back
  Tell me:
   - the folder path
   - the zip path
   - how many files were extracted
   - the total size
   - any entries that failed, if any

RULES
  - Never modify, move or delete the original APK.
  - Never upload anything to any server.
  - If a command fails, show me the exact error and try the alternative I give you
    instead of guessing repeatedly.
  - If unzip reports "unsupported compression method" on some entries, list those
    entries and continue with the rest.
```

---

## If you would rather not use an agent at all

These are the only commands you actually need. Type them one at a time in Termux:

```bash
termux-setup-storage
pkg install -y unzip
mkdir -p /sdcard/Download/Extracted/game
unzip -o /sdcard/Download/game.apk -d /sdcard/Download/Extracted/game
```

Then open the Files app → Downloads → Extracted → game. Everything is there, as real
folders. No zip, no extract step, no browser, no size limit.

To also get a zip:

```bash
cd /sdcard/Download/Extracted
zip -r game.zip game
```

## Notes

- `unzip` on a 300 MB APK takes a few seconds and uses very little memory, because it
  streams entry by entry. That is why it does not hang the way a browser does.
- If the archive is an `.xapk` or `.apks` bundle, unzip it first, then unzip the inner
  `.apk` files into the same folder — that is what the app needed several passes to do.
- `termux-setup-storage` is required once; without it Termux cannot see `/sdcard`.
- Keep Termux awake while it works: pull down the notification and tap "Acquire wakelock".
