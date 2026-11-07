# Bubble Shooter — Complete Blueprint

Two independent halves, both in this repository:

| Folder | What it is | Depends on you having the APK? |
|---|---|---|
| `blueprint/original/` | A complete, self-contained build specification for **your own** bubble-shooter game — architecture, grid physics, level schema, economy, ads, master build spec | No |
| `blueprint/reference/` | Five documents **auto-generated** by the workflow from a package **you supply** — what is actually inside that specific build | Yes |

Read `blueprint/original/` to build. Read `blueprint/reference/` to compare.

---

## Why the reference half needs your own package

The workflow does not download APKs from mirror sites, and it does not publish the package or its original
art, audio, fonts or level data anywhere. Two reasons, both practical:

1. **Ownership.** The art, audio, fonts, code and level data in a commercial game belong to its publisher.
   Republishing them — including inside a public repo or a release — is copyright infringement in India
   (Copyright Act 1957, s.14 and s.51) and everywhere else, and it is not a "grey area".
2. **It would not survive.** Public repos carrying decompiled commercial assets get DMCA'd. You would lose
   the repo, the workflow history and any stars on it.

So the workflow analyses a copy **you** lawfully obtained, in a **private** repo, and produces documentation.
The documentation is yours. The assets stay theirs.

Read `docs/LEGAL_AND_SCOPE.md` before you start.

---

## Setup (5 minutes)

1. **Make this repository private.** Settings → General → Danger Zone → Change visibility → Private.
   The workflow refuses to run while the repo is public — that guard is deliberate.

2. **Add your package.** Two options:

   - **Release asset (recommended, no repo size limit):**
     ```bash
     gh release upload v1.0-apk /path/to/bubbleshooter.orig.apk --clobber
     ```
     The release may stay a draft; the workflow reads draft assets with its own token.

   - **Committed file:** drop it in `reference/` and push. Only do this if the file is under GitHub's
     100 MB limit and you accept that it enters git history.

3. **Run the workflow.** Actions → *REA extract and blueprint* → Run workflow.
   Or from the CLI:
   ```bash
   gh workflow run rea_extract.yml
   gh run watch
   ```

4. **Read the output.** `blueprint/reference/` gets committed back automatically, and the same files plus
   `assets_inventory.csv` and `_extraction_report.json` are attached to the run as the `rea-blueprint`
   artifact.

---

## What the workflow does

```
fetch_package.py    → finds the package (release asset / reference/ / URL you pass in)
prepare_package.py  → single APK or split XAPK/APKS bundle → merged raw tree + apktool decode
analyze_apk.py      → static analysis → five documents + inventory CSV + JSON report
```

`study_sheet.py` then writes `blueprint/reference/STUDY_SHEET.md` plus `sprite_measurements.csv` and
`audio_measurements.csv` — sizes, alpha coverage, dominant palettes, transparent padding, audio length and
loudness. Measurements only: no image or audio data is copied into the output, so the sheet is yours to keep
and share while you draw the replacement art yourself.

`analyze_apk.py` reads the decoded manifest, `res/values/*.xml`, every file under `assets/` (with image
dimensions read from headers), level-shaped data files with their JSON schema, native library symbols and
string tables, and the ad/billing SDKs it can identify. Anything it cannot prove is written as
*not derivable* — it never fills a gap with a guess.

---

## The five documents

`blueprint/reference/` (generated from your package):

1. `01_LOADING_SCREEN_UI_AND_ANIMATIONS.md` — launch chain, components, colour palette, dimens, styles, UI
   strings, layouts, animation assets, engine markers
2. `02_BUBBLES_BOOSTERS_AND_LEVELS_SYSTEM.md` — booster/blocker art, colour tokens, real level file count and
   schema, scoring evidence
3. `03_STORE_IAP_AND_MONETIZATION_ADS.md` — SDKs detected, billing permissions, SKU-shaped candidates,
   remote-config candidates, rewarded/interstitial strings
4. `04_COMPLETE_ASSETS_CATALOG.md` — folder map, totals by type, images with dimensions, audio, fonts, atlases
5. `05_MASTER_AI_GAME_BUILDER_PROMPT.md` — the extracted facts as a build brief

`blueprint/original/` (written by hand, yours to ship):

1. `01_ARCHITECTURE_AND_STACK.md` — engine choice, state machine, screens, HUD geometry, animation catalog,
   asset pipeline, save format
2. `02_HEXGRID_PHYSICS_AND_MATCHING.md` — coordinates, snapping, collision, matching BFS, floating BFS,
   scoring, edge cases, determinism
3. `03_LEVEL_SCHEMA_AND_BALANCE.md` — level JSON, validator, difficulty curve, star thresholds, generator
4. `04_ECONOMY_AND_AD_MEDIATION.md` — currencies, boosters, SKUs, billing checklist, ad placements, consent
5. `05_MASTER_BUILD_SPEC.md` — the whole thing as one contract with milestones and acceptance tests
6. `06_AUDIO_AND_SOUND_DESIGN.md` — 43-entry SFX catalogue, pop pitch ladder, music stems, haptics, legal sourcing
7. `07_ASSET_PRODUCTION_SPEC.md` — every sprite with counts and pixel sizes, atlas budgets, export settings, store assets
8. `08_QA_DEVICE_MATRIX_AND_RELEASE.md` — device tiers, 44 test cases, automated tests, profiling, Play Console checklist
9. `09_LIVEOPS_ASO_AND_LAUNCH.md` — ASO, soft-launch KPI gates, live ops calendar, remote config, rollback
10. `10_APP_FLOW_A_TO_Z.md` — the whole app flow: every screen, every tap, first launch second by second,
    the life of one shot, popup priority, edge cases and flow acceptance tests

## Generated asset pack (no APK needed)

`scripts/generate_original_assets.py` draws and synthesises a complete original asset pack —
142 sprites and 46 audio files — from the specs in `blueprint/original/`. Nothing is read from any APK.

```bash
python scripts/generate_original_assets.py --out generated_assets --ogg
```

Run it locally, or trigger **Generate original asset pack** in Actions, which packages
`Original_Polished_Game_Assets.zip`, uploads it as an artifact and attaches it to the
`v1.0-generated-assets` release. Preview: `generated_assets/_contact_sheet.png`.

`docs/REQUIREMENT_COVERAGE.md` maps every item of the original brief to the file that covers it — including
the items deliberately left out and why.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `This repository is PUBLIC` error | the guard | make the repo private |
| `No package found` notice | no asset on `v1.0-apk`, nothing in `reference/` | upload the package, re-run |
| `apktool did not produce a decodable manifest` | the base APK inside an XAPK was misdetected, or the build is protected | check `work/package_meta.json`, pass the base APK directly |
| Empty documents | analysis ran on a nearly empty tree | check the artifact's `package_meta.json` for `merged_entries` |
| `nothing usable was extracted` | corrupt or truncated download | re-upload the package |

Runs are capped at 90 minutes. A 200 MB XAPK decode takes 5-15 minutes on `ubuntu-latest`.
