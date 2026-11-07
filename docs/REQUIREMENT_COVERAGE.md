# Requirement Coverage — A to Z

This file maps every item from the original brief to where it is covered. If a line says **not included**,
that is deliberate and the reason is in `docs/LEGAL_AND_SCOPE.md`.

---

## 1. The five requested documents

| Requested | Where it lives | Status |
|---|---|---|
| `01_LOADING_SCREEN_UI_AND_ANIMATIONS.md` — launch flow, splash/loading hex colours, logo, progress bar, screen-by-screen UI, full animation catalog with file names | generated: `blueprint/reference/01_…` · designed: `blueprint/original/01_ARCHITECTURE_AND_STACK.md` (§2-§4) | both halves done |
| `02_BUBBLES_BOOSTERS_AND_LEVELS_SYSTEM.md` — normal bubbles, boosters, blockers with hit points, level count, level file schema, grid rows, shot limits, colour distribution, 1/2/3-star thresholds | generated: `blueprint/reference/02_…` · designed: `original/02_HEXGRID_PHYSICS_AND_MATCHING.md` + `original/03_LEVEL_SCHEMA_AND_BALANCE.md` | both halves done |
| `03_STORE_IAP_AND_MONETIZATION_ADS.md` — coin packs, bundles, VIP, piggy bank, +5 moves, booster prices, SKU IDs, ad SDKs, rewarded/interstitial triggers, remote config | generated: `blueprint/reference/03_…` · designed: `original/04_ECONOMY_AND_AD_MEDIATION.md` | both halves done |
| `04_COMPLETE_ASSETS_CATALOG.md` — folder-by-folder inventory, file sizes, image dimensions, purpose | generated: `blueprint/reference/04_…` + `assets_inventory.csv` · designed: `original/07_ASSET_PRODUCTION_SPEC.md` | both halves done |
| `05_MASTER_AI_GAME_BUILDER_PROMPT.md` — one self-contained spec | generated: `blueprint/reference/05_…` · designed: `original/05_MASTER_BUILD_SPEC.md` | both halves done |

---

## 2. Assets, sound effects and "everything used"

| Item | Coverage |
|---|---|
| Every asset file with size and pixel dimensions | `blueprint/reference/04_COMPLETE_ASSETS_CATALOG.md` + `assets_inventory.csv` (generated from your own package) |
| Every sprite the game needs, with counts and sizes | `original/07_ASSET_PRODUCTION_SPEC.md` §2-§9 |
| Sound effects — full catalogue, 43 entries, lengths, triggers, pitch rules | `original/06_AUDIO_AND_SOUND_DESIGN.md` §3 |
| Music, stems, loop points, crossfades | `original/06_AUDIO_AND_SOUND_DESIGN.md` §4 |
| Haptics | `original/06_AUDIO_AND_SOUND_DESIGN.md` §5 |
| Fonts, including Devanagari coverage | `original/06` §6, `original/07` §8 |
| Atlas layout, compression, export settings | `original/07_ASSET_PRODUCTION_SPEC.md` §9-§10 |
| Where to legally source art and audio | `original/06` §6, `original/07` §12 |
| Asset credits template | `original/07` §12 |

The original publisher's art, audio and font files are **not included** and are not extracted for
redistribution. The workflow produces an inventory of what is in your own package (paths, sizes,
dimensions) — measurements, not files. Reason: `docs/LEGAL_AND_SCOPE.md`.

---

## 3. Pipeline items from the brief

| Requested | Status |
|---|---|
| Public repo named `bubble-shooter-complete-blueprint` | repo exists; set **private** by design |
| `permissions: contents: write`, `workflow_dispatch` | done, `.github/workflows/rea_extract.yml` |
| Automated APK download from APKPure / Uptodown / APKCombo (3 tiers: apkeep, Playwright, cloudscraper) | **not included** — automating downloads from unauthorised mirrors is redistribution of someone else's app; you supply the package instead (`scripts/fetch_package.py` accepts a release asset, `reference/` file, or a URL you control) |
| Single APK vs split XAPK handling, merge all parts into one tree | done, `scripts/prepare_package.py` |
| `apktool d` on the base APK | done |
| Manifest, `res/values/*.xml`, `res/layout/` analysis | done, `scripts/analyze_apk.py` |
| `assets/` walk with JSON/XML/plist/spritesheet/audio/font parsing | done |
| Native `.so` symbols via `strings` / `nm -D` | done |
| `classes*.dex` string analysis | done (via `strings`, not jadx — jadx needs a JVM heap the runner may not have; add it back if you want source-level output) |
| Release publishing of the APK + all original assets (`v1.0-assets`) | **not included** — republishing a commercial app's package and assets is infringement; the workflow publishes analysis artifacts instead |
| Commit `blueprint/` back to `main` | done, with rebase-and-retry |
| Self-healing loop on workflow failure | partially: the workflow is idempotent, re-runnable, logs failures with `::error::`, and the scripts fail with explicit messages. Automatic re-trigger from a monitoring agent is not wired up — that needs an Actions token this session does not have |
| Direct links to repo, all 5 files, release downloads | repo link provided; the 5 reference files appear after you run the workflow once with your package |

---

## 4. Added beyond the brief

| Document | Why it was added |
|---|---|
| `original/06_AUDIO_AND_SOUND_DESIGN.md` | you asked for sound effects; the brief had no audio spec at all |
| `original/07_ASSET_PRODUCTION_SPEC.md` | you asked for every asset; this is the production list with sizes and counts |
| `original/08_QA_DEVICE_MATRIX_AND_RELEASE.md` | 44 test cases, device tiers, Play Console checklist — the gap between "spec" and "shipped" |
| `original/09_LIVEOPS_ASO_AND_LAUNCH.md` | ASO, soft-launch KPI gates, live ops calendar, rollback |
| `docs/LEGAL_AND_SCOPE.md` | what is and is not lawful here, in plain language |
| `docs/REQUIREMENT_COVERAGE.md` | this file |

---

## 5. What still needs you

1. Make the repository private (Settings → General → Danger Zone).
2. Upload your package: `gh release upload v1.0-apk /path/to/file.apk --clobber`.
3. Run the workflow from the Actions tab (the App token in this session cannot dispatch it).
4. Then `blueprint/reference/` fills with real extracted data from your own copy.
