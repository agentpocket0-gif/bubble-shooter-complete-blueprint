# QA gates — no more screenshot-only approval

## Automated gates

1. **Project/import:** Godot headless import; no parse, UID or resource errors.
2. **Gameplay unit tests:** grid parity, bounds, snapping, collision, wall reflection, matching BFS, floating BFS, scoring, seeded queue and save migration.
3. **Golden board tests:** at least 20 saved board states with exact expected popped/falling cells.
4. **Physics tests:** 100+ deterministic shots at 30/60/120 FPS and edge angles; no tunnelling; preview landing equals actual landing.
5. **Objectives/boosters:** each objective and each booster has positive, negative and persistence tests.
6. **Content:** exactly 600 levels across the approved mode structure; schema validation plus trajectory-aware simulation; fail if any level is unsolved or a duplicate layout appears beyond an allowed design pattern.
7. **Flows:** F01-F10 in `01_RECON.md`; test happy path, back button, offline, app interruption, empty/corrupt save, out-of-lives, purchase pending/failure and retry.
8. **Visual:** capture every key screen in its actual state at 720x1280, 1080x1920 and one narrow/large Android viewport. Compare layout hierarchy and controls against approved reference captures; do not pursue pixel identity.
9. **Audio:** every required SFX event has a valid file and correct bus/toggle; confirm mute settings persist.
10. **Android package:** inspect package ID, min/target SDK, orientation, permissions, signing, asset size and installability.

## Physical-device gate

A CI screenshot is not a device test. Install the APK on at least one low/mid Android phone and verify:
- cold start and first-run sequence;
- touch aim/fire and boosters;
- scrolling map and opening/closing overlays;
- audio and haptics;
- suspend/resume, back button and airplane mode;
- save/restart and level progress;
- crashes, ANRs, memory, frame times and battery behaviour.

Record device model, Android version, build hash, test date, steps and captured video/logcat.

## Release decision

A build is **not releasable** if any must-have feature is missing, any level is unsolved, any core flow is broken, a required asset lacks provenance, there is an open critical/high bug, or physical-device validation is absent.

A GitHub Action green check is a build-pipeline result only. Never rename it "game verified" without the evidence listed above.
