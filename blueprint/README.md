# Blueprint index

Two halves. They do different jobs — do not mix them up.

## `original/` — build from this

Written by hand, yours to ship, no APK needed.

| File | Covers |
|---|---|
| `01_ARCHITECTURE_AND_STACK.md` | engine choice, app state machine, screen inventory, HUD geometry, animation catalog, asset pipeline, save format |
| `02_HEXGRID_PHYSICS_AND_MATCHING.md` | staggered-grid coordinates, neighbour rules, projectile physics, snapping, match BFS, floating BFS, scoring, determinism |
| `03_LEVEL_SCHEMA_AND_BALANCE.md` | level JSON format, validator, difficulty curve, star thresholds, generator, content budget |
| `04_ECONOMY_AND_AD_MEDIATION.md` | currencies, lives, boosters, SKU table, billing checklist, ad placements, consent, analytics events |
| `05_MASTER_BUILD_SPEC.md` | the whole thing as one contract, with 10 milestones and acceptance tests |
| `06_AUDIO_AND_SOUND_DESIGN.md` | 43-entry sound effect catalogue, pop pitch ladder, music stems, mixing buses, haptics, legal audio sourcing |
| `07_ASSET_PRODUCTION_SPEC.md` | every sprite with counts and pixel sizes, atlas budgets, export settings, store listing assets, credits template |
| `08_QA_DEVICE_MATRIX_AND_RELEASE.md` | device tiers, 44 functional test cases, automated test layers, profiling targets, Play Console checklist |
| `09_LIVEOPS_ASO_AND_LAUNCH.md` | ASO rules, soft-launch KPI gates, live ops calendar, remote config, rollback |
| `10_APP_FLOW_A_TO_Z.md` | every screen, overlay and tap in order: state machine, first launch second-by-second, tutorial script, the life of one shot, popup priority, edge cases, flow acceptance tests |

Read them in order. `05` is the summary; `01`-`04` are the systems, `06`-`09` are production, testing and
launch, and `10` is the complete screen-by-screen flow.

## `reference/` — generated from your own package

Produced by `.github/workflows/rea_extract.yml`. Populated only after you add a package and run the
workflow; until then this folder holds nothing but a note.

| File | Covers |
|---|---|
| `01_LOADING_SCREEN_UI_AND_ANIMATIONS.md` | launch chain, components, real colour hex values, dimens, styles, UI strings, layouts, animation files, engine markers |
| `02_BUBBLES_BOOSTERS_AND_LEVELS_SYSTEM.md` | booster/blocker art present, colour tokens, actual level file count and decoded schema, scoring evidence |
| `03_STORE_IAP_AND_MONETIZATION_ADS.md` | SDKs identified, billing permissions, SKU-shaped candidates, config-key candidates, ad strings |
| `04_COMPLETE_ASSETS_CATALOG.md` | folder map, totals by type, images with dimensions, audio, fonts, atlases + full `assets_inventory.csv` |
| `05_MASTER_AI_GAME_BUILDER_PROMPT.md` | the extracted facts assembled into a build brief |
| `_extraction_report.json` | machine-readable counts for CI and diffing between runs |

## How to use both together

1. Read `reference/04` to learn the **measurements**: resolution targets, atlas sizes, audio formats, how many
   level files exist, how big they are.
2. Read `reference/02` and `reference/03` to learn the **shape** of the systems: what blocker types exist,
   which SDKs they integrate, how SKUs are named.
3. Throw away every actual file, value and name that belongs to them.
4. Build from `original/`, using the measurements as your targets.

That is the whole method. Measurements are free; assets are not.
