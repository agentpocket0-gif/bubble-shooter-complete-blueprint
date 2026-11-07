# 05 · Master Build Specification

**Scope:** one file you can hand to an AI coding agent (or a contractor) to build the whole game.
It is the condensed contract; the other four documents are the detail behind it.

---

## 0. The brief

> Build an original 2D bubble-shooter for Android (and optionally iOS/web) from scratch.
> Do not copy, extract or embed any art, audio, font, level data, code or trademark from any existing
> commercial game. Everything must be produced for this project or licensed for it.

---

## 1. Technical contract

| Item | Requirement |
|---|---|
| Engine | Cocos Creator 3.x (TypeScript) or Unity 6 (C#) — pick one, do not mix |
| Target | Android 8.0 (API 26) minimum, API 34 target |
| Orientation | portrait only, locked |
| Reference resolution | 1080 × 1920, scale-to-fit with safe-area insets |
| Frame budget | 16.6 ms; no frame over 20 ms during a 10-bubble pop |
| Cold start | ≤ 3 s to interactive map on a 4 GB RAM device |
| Base binary | ≤ 60 MB |
| Offline | full gameplay works with no network |
| Save | versioned JSON, atomic write, forward migrations only |
| Localisation | every string in a table; ship `en`, `hi` at minimum |

---

## 2. Core loop

```
Map ──► Level ──► Result ──► Map
         │                    │
         └─ fail ──► rewarded ad offer ──► retry
```

A level: aim with drag → release to shoot → the bubble snaps into the grid → matching clusters pop →
disconnected clusters fall → win or lose on objective or shot count.

---

## 3. Mechanics (hard requirements)

1. Staggered grid: row pitch `d · √3/2`, odd rows offset by `d/2`, six neighbours per cell.
2. Projectile integrated in substeps of at most `d/2` of travel; snaps to the free cell adjacent to the
   first bubble hit whose centre is nearest the projectile.
3. Wall reflection, not clamping; up to 3 bounces in the aim preview, and the preview must use the same
   integrator as the real shot.
4. Match-3-or-more of one colour pops; then a flood-fill from row 0 removes disconnected clusters as falling
   bodies with individual gravity and spin.
5. Win on objective; lose when shots reach zero or the board fills.
6. Current + next bubble preview, and a swap action.
7. Colour queue seeded by `(levelId, attemptIndex)` so retries are reproducible and cannot be re-rolled.
8. Never hand the player a colour that is not present on the board.

Full algorithms: `02_HEXGRID_PHYSICS_AND_MATCHING.md`.

---

## 4. Content

- Level format and validator: `03_LEVEL_SCHEMA_AND_BALANCE.md`.
- 30 hand-authored tutorial-to-early levels, then generated levels to 100 at launch.
- Objective types at launch: `clear_all`, `clear_color`, `pop_count`, `score`.
- Blockers at launch: ice (2 hp), stone (indestructible). Nothing else until players are fluent.
- 3 worlds with distinct palettes and backgrounds; new themes ship as downloadable packs.

---

## 5. UI

Screens: splash, loading, map, level, result, store, daily spin, piggy bank, settings, privacy.

Non-negotiables:
- Every touch target ≥ 88 × 88 px at 1080 width.
- HUD shows coins, lives with countdown, level number, and a pause button at all times in a level.
- Back button pops an overlay before it changes state.
- No interstitial in the first session; no ad inside the first 3 minutes.
- Result screen always offers: next level, retry, and a rewarded "double reward".

Animation and layout detail: `01_ARCHITECTURE_AND_STACK.md`.

---

## 6. Economy

| Thing | Value |
|---|---|
| Coins per level (first clear) | 40, +100 first-clear bonus |
| Booster prices | swap 60, laser 80, extra moves 150, continue 250, bomb 300, rainbow 350 |
| Max lives / refill | 5 lives, 1 per 30 minutes |
| Free starter boosters | 3 extra-moves, 1 bomb |

Store SKUs: `bs.coins.small|medium|large|mega`, `bs.starter.pack`, `bs.noads`, `bs.vip.monthly`.
Server-side receipt validation is mandatory. Detail: `04_ECONOMY_AND_AD_MEDIATION.md`.

---

## 7. Ads

One mediation SDK (AppLovin MAX or LevelPlay). Placements: rewarded extra-moves on fail, rewarded double
reward on result, rewarded free booster, rewarded extra life, interstitial capped at 1 per 90 s and 8 per day,
app-open ad once per session after the first session. Consent via Google UMP before any ad request in EEA/UK;
Play Families rules if the audience skews young. Test ad unit IDs only in development.

---

## 8. Milestones and acceptance tests

| # | Milestone | Acceptance test |
|---|---|---|
| 1 | Skeleton: engine project, scene manager, save system | app launches to an empty map and persists a flag across restarts |
| 2 | Grid + shooting + snapping | 100 scripted shots land in the expected cell, zero tunnelling at 30 fps |
| 3 | Matching + floating | a 3-cluster pops; a detached 5-cluster falls; a test suite covers 20 boards |
| 4 | Level loader + 30 levels | all levels validate in CI; greedy solver clears each with ≥ 1 shot spare |
| 5 | UI flow end-to-end | full loop map → level → result → map with no dead ends |
| 6 | Economy + store + billing | purchase grants, acknowledges, and survives a mid-purchase kill |
| 7 | Ads + consent | no ad before first level completion; consent blocks requests until answered |
| 8 | Analytics + crash reporting | every event in the spec fires with the required properties |
| 9 | Polish | audio, haptics, particles, accessibility labels, 60 fps on a low-end device |
| 10 | Release | internal → closed → production track, store listing, privacy policy live |

---

## 9. Repository layout

```
/app            engine project (scenes, scripts, prefabs)
/content
  /levels       one JSON per world + index.json
  /art          source files (PSD/Aseprite) — not shipped
  /atlas        exported atlases (plist/json + png)
  /audio        ogg/m4a
  /fonts        ttf + bmfont
/tools
  validate_levels.ts
  balance_report.ts
  atlas_build.sh
/docs           this blueprint
ASSET_CREDITS.md
PRIVACY.md
```

---

## 10. Definition of done

- All 10 milestones pass their acceptance test in CI where testable.
- No asset in the shipped build lacks a line in `ASSET_CREDITS.md`.
- The game is playable to level 100 offline.
- A new designer can add a level and see it in-game with no code change.
- Nothing in the build is traceable to another company's product.
