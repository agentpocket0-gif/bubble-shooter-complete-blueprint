# Source audit — 9 November 2026

## Executive finding

The v5 APK is a small playable prototype/foundation. It is not a faithful completion of the requested product. The previous release label and success badges overstated what the tests proved.

## Material reviewed

| Source | What it contains | What it proves |
|---|---|---|
| `blueprint/original/01_ARCHITECTURE_AND_STACK.md` | Screen inventory, state model, HUD layout, animations, save model | Product behaviour to implement |
| `blueprint/original/02_HEXGRID_PHYSICS_AND_MATCHING.md` | Hex-grid geometry, projectile, snapping, match and floating BFS | Core rules specification |
| `blueprint/original/03_LEVEL_SCHEMA_AND_BALANCE.md` | Level schema, objectives, difficulty, generator and playability guidance | Content contract, but it specifies 100 levels |
| `blueprint/original/04_ECONOMY_AND_AD_MEDIATION.md` | Lives, boosters, shop SKUs, ad placements, consent | Monetization and retention specification |
| `blueprint/original/05_MASTER_BUILD_SPEC.md` | Ten milestones and acceptance criteria | Overall project baseline |
| `blueprint/original/06_AUDIO_AND_SOUND_DESIGN.md` | Audio buses, SFX catalogue, music and haptics | Audio production contract |
| `blueprint/original/07_ASSET_PRODUCTION_SPEC.md` | Bubble, blocker, cannon, booster, UI, particle, font and atlas needs | Visual asset inventory |
| `blueprint/original/08_QA_DEVICE_MATRIX_AND_RELEASE.md` | 44 functional/device checks and performance targets | QA contract |
| `blueprint/original/09_LIVEOPS_ASO_AND_LAUNCH.md` | Live events, ASO, KPI and rollout | Post-launch plan |
| `blueprint/original/10_APP_FLOW_A_TO_Z.md` | Boot-to-exit state machine, first-run sequence, tutorial, screens, taps and popup priority | Main UX contract |
| `godot_project/scripts/saga_map.gd` | A 5-column level-button grid, title, coin text, settings and booster buttons | The current map is a basic placeholder, not the specified world map |
| `godot_project/scripts/gameplay.gd` | Single gameplay script with board drawing, HUD labels and four basic booster buttons | Some core gameplay exists; full systems are not proven |
| `tools/generate_levels.py` | Deterministic generator that writes level IDs 1–120 | Current content count is 120, not 600 |
| `tools/rea_analyzer.py` | Counts blueprint docs and reference sample files, reads asset manifest | This is a local audit helper, not the official REA agent |
| `tools/replica_vision_qa.py` | OpenCV image integrity checks across nine screenshots and optional one-image vision call | This is not a complete Replica recon/build/test/parity process |
| `GAPS.md`, `docs/BUILD_STATUS.md` | Existing explicit gap lists | The prior project itself acknowledges unfinished systems |

## Critical findings

1. `blueprint/reference/` does not contain the five REA-generated reports. Its README says they are generated only after the user-supplied APK is provided and the extraction workflow runs.
2. The `v1.0-apk` GitHub Release has no assets. The official REA workflow therefore has no reference APK to analyze.
3. The uploaded library file named `Boltwood-Puzzle-debug.apk` contains Godot runtime/PCK assets and is a debug APK. It has not been established as the original target game's APK, so it must not be passed off as the source reference.
4. The current game project has only three scenes: Splash, SagaMap and Gameplay. Loading, Intro, Result, Store, Spin, Piggy Bank, Events, Pause and other flows are not complete standalone implementations.
5. The current generator writes 120 mechanically repetitive levels. The master level reference JSON reports `extracted_sample_count: 0`; five sample JSON files are thin metadata, not an extracted 600-level campaign.
6. The 1,595 files in `godot_project/assets/real_pack/` are explicitly marked `publishable: false`, provenance "third-party APK resources". They are not used in the current game. Keep them out of all public game builds.
7. The current game has generated SVG placeholders under `assets/own/`; the repo states no audio is bundled. This does not meet the requested polished art, complete animations and audio catalogue.
8. Ads and IAP are disabled and no live provider SDK/billing workflow is included.
9. Previous QA was headless/Xvfb screenshot smoke testing. It was not a physical Android installation, a complete 600-level solver pass, or full flow-by-flow parity testing.
10. The project APK is about 212 MB, well above the authored asset spec's 60 MB base budget.

## REA and Replica: honest execution status

- **Replica Skill:** the recon, architect, design, build, test and diff skill instructions were inspected. A proper evidence-led project workstream is now recorded in this branch. The skills were not previously executed as a complete end-to-end workflow.
- **REA:** the official `morluto/rea` project documentation was inspected. It requires a real target package/device evidence. No confirmed original target APK is attached to `v1.0-apk`; therefore no complete official REA report can truthfully be claimed.
- The existing names "REA" and "Replica QA" in the prior workflow must not be treated as proof that the official tools ran.

## Release-blocking repository safety issue

The GitHub repository is currently public while containing a directory explicitly described as extracted third-party APK resources and decompiled study material. The analysis workflow itself refuses to run unless the repository is private. The owner should change repository visibility to private before continuing private APK analysis. This branch does not change repository visibility automatically.

## Decisions for the rebuild

- Campaign target: 600 levels, based on the user's later product requirement. Do not generate or report 600 levels as complete until every level passes schema, deterministic-seed and trajectory-aware playability checks.
- Modes: three modes are required; their exact names/rules must be pulled from the source material or original-app observations. Do not invent the missing mode definitions.
- UI: implement all states and overlays in the A-to-Z flow, not just a map and one gameplay scene.
- Visuals: original, license-cleared glossy / dimensional art and animation. The extracted pack can only inform private measurements where permitted; it is not a shipping asset pack.
- No new APK release until the build contract and QA gates in this folder pass.
