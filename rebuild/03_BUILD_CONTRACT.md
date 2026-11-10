# Build contract — corrective rebuild

## Product baseline

- Platform: Android first; portrait.
- Engine: Godot 4.7.2 in the existing project.
- Campaign: 600 levels.
- Modes: three, with definitions sourced from original evidence rather than invented names/rules.
- Visual direction: polished glossy, dimensional bubbles and UI, coherent world map, premium motion; all art used in release must be owned or licensed.
- Language: English and Hindi at minimum.
- Offline: all core gameplay and local progression work offline.

## Screen/state contract

Implement the A-to-Z flow in `01_RECON.md`: Boot, Splash, first-run Intro, Loading, Map, Level and Result as real states; Pause, Settings, Store, Daily Spin, Piggy Bank, Events and required reward/privacy/error dialogs as managed overlays or dedicated scenes. One overlay at a time; back pops the overlay stack first.

## Gameplay contract

- Follow the exact staggered-grid neighbour parity and geometry rules in `02_HEXGRID_PHYSICS_AND_MATCHING.md`.
- Real projectile physics uses substeps and reflective walls. The aim-preview must share the same prediction code as the actual shot.
- Snap against the best empty neighbour of the first collision, not the nearest arbitrary cell.
- Match groups of at least three; then flood-fill anchored cells from the top row and animate detached groups falling.
- Queue colours deterministically by level and attempt. Do not offer colours absent from the board.
- Implement and test every objective and blocker. A button that does not change the board is not an implemented booster.

## Content contract

- Do not change the campaign count back to 100 or 120.
- 600 unique data records, grouped into worlds/episodes based on evidence. No copy-paste rows with a different level ID.
- The first tutorial levels are hand-authored and reviewed. Later levels may be generated only through an algorithm that tracks board seeds, objectives, moves, target difficulty and solver results.
- A level is not "validated" merely because JSON parses or contains a match-3. It must pass trajectory-aware simulation and a human visual review.
- The three modes each require a mode-specific rule sheet and tests before content generation.

## Asset contract

- No extracted third-party images/audio/fonts/level layouts or code are shipped.
- Build original glossy bubbles, blockers, cannon, boosters, UI panels, map objects and effects from approved assets or original generated artwork.
- Source files, atlas exports, resolution variants, naming and credits must be recorded.
- Audio work must include original or licensed SFX and music and must respect the authored four-bus design.

## Implementation milestones

| Stage | Deliverable | Gate |
|---|---|---|
| R0 | Evidence audit, source manifest, app flow and feature matrix | This audit is present; unresolved evidence is labelled |
| R1 | Real first-session vertical slice: Boot → Splash → Intro → Loading → Map → Level 1 tutorial → Win Result → Map | Automated route test, stable save, real screenshots |
| R2 | Full gameplay engine, objectives, blockers, boosters and loss path | Golden board tests and 100+ seeded shot tests |
| R3 | Three mode rules and their distinct flows | Each mode independently playable and tested |
| R4 | 600 level content pipeline | All 600 data records, trajectory-aware solver report, no duplicates/unsolved level |
| R5 | World map, store, spin, piggy bank, events, settings and full economy | Every F01-F10 flow and edge state passes |
| R6 | Original glossy art, animation, sound, Hindi/English and accessibility | Art/audio inventory complete; UI tested on 3 screen sizes |
| R7 | Android device QA, optimization, APK/AAB | Device capture/log evidence; app size and crash/perf gates |
| R8 | Release candidate | No open blocker; signed release artifact; QA report linked |

## Rule on release labels

- Do not create a public "final", "verified", "gold master" or "production" release while any required milestone is open.
- CI success only means that CI's exact checks passed. It never substitutes for gameplay completeness or a device test.
