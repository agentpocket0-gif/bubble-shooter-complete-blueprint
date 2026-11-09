# Product recon — screen and flow inventory

Evidence labels:
- **SPEC**: described by `blueprint/original/10_APP_FLOW_A_TO_Z.md` or another authored blueprint.
- **CURRENT**: confirmed present in the current Godot project or source.
- **MISSING**: not implemented or not evidenced by the current project.
- **UNKNOWN**: requires inspection of the actual original app/reference APK.

## Screen inventory

| ID | Screen/state | Purpose and required contents | Current status | Evidence |
|---|---|---|---|---|
| S01 | Boot | Load versioned save, locale and audio settings; no network dependency | Partial | SPEC; GameState exists |
| S02 | Splash | Brand mark, timed fade, version string | Partial | SPEC; Splash scene exists |
| S03 | Intro/tutorial slides | Three first-run teaching cards with Skip | Missing | SPEC |
| S04 | Loading | Real staged progress, rotating tips, asset preloading | Missing | SPEC |
| S05 | World map | Scrollable themed path, world progression, current level highlight, stars and HUD | Partial | SPEC; current map is a simple numbered grid |
| S06 | Level pre-start | Level objective, moves, boosters and start action | Unknown | Requires reference evidence |
| S07 | Gameplay | Board, cannon, current/next bubbles, aim preview, shots, objective, score, pause and boosters | Partial | SPEC; current gameplay script exists |
| S08 | Win result | Stars, score/reward tally, next/retry/map, optional rewarded double reward | Partial | SPEC; current result is not a complete dedicated screen |
| S09 | Lose result | Retry/map/continue/rewarded extra-moves decision | Partial | SPEC |
| S10 | Pause overlay | Resume, restart, settings, quit to map | Missing / incomplete | SPEC |
| S11 | Settings overlay | Music, sound, haptics, language, privacy, restore purchase | Partial | SPEC; basic popup only |
| S12 | Store | Coin packs, booster offers, starter pack, no-ads/VIP states and purchase feedback | Partial | SPEC; no billing |
| S13 | Daily spin | Free-spin cooldown, weighted prize, result and optional rewarded reroll | Missing / incomplete | SPEC |
| S14 | Piggy bank | Fill meter, capacity, unlock offer and closed/open states | Missing | SPEC |
| S15 | Events | Event timer, progress track, rewards, entry and unavailable state | Missing | SPEC |
| S16 | Out-of-lives popup | Refill countdown, wait/rewarded option and store path | Missing | SPEC |
| S17 | Reward popup | Level and daily reward presentation | Partial | SPEC |
| S18 | Privacy / consent | Policy link, consent before ad requests where required, deletion route | Missing | SPEC |
| S19 | Maintenance / force update | Safe blocking state and retry/exit path | Missing | SPEC |
| S20 | Purchase confirmation/error | Pending, success, failure, restore and cancellation | Missing | SPEC |

## Main flows

### F01 — First install
Boot → Splash → Intro (first run only) → Loading → World Map → Level 1.
The tutorial then gates the first aim, shot, match, fall and completion steps. The authored spec targets roughly 6.5 seconds to first shot.

### F02 — Returning player
Boot → Splash → Loading → saved map position/current unlocked level. Save migration and corrupted-save recovery must not block the player.

### F03 — Play a level
Map node tap → Level load → aim → preview trajectory → shoot → snap → match-3 → pop → floating-group fall → update objective/score/moves → win or lose result.

### F04 — Win
Win animation → result screen → star award → coin tally → save stars/progress/reward exactly once → Next / Retry / Map. Double reward must be opt-in and never block offline play.

### F05 — Lose
Lose screen → Retry / Map / Continue or extra moves. Continue must be limited and must preserve the current board exactly.

### F06 — Overlay navigation
From Map or Level: open Settings, Store, Daily Spin, Piggy Bank or Events. One overlay at a time. Back and scrim dismiss normal overlays; purchase/force-update states require explicit action.

### F07 — Store / purchase
Open store → query live product metadata → pending/success/failure → verify receipt server-side → grant exactly once → persist → restore non-consumables on reinstall. Until the billing integration is implemented, only a clearly labelled test catalogue may be shown.

### F08 — Daily retention
Daily spin available → one free spin → prize reveal → cooldown; optional rewarded reroll only when the ad system is active and consent is resolved.

### F09 — Offline session
Launch with no network → map and gameplay still work → progress/reward saves locally → online features show safe fallback. No startup network dependency.

### F10 — App exit / interruption
Back closes overlay first; on Level it opens Pause; on Map it requests exit. Phone interruption pauses music/loops and saves state at a safe boundary.

## Mode and campaign scope

The user's later requirement is **three modes and 600 levels**. The documents currently in `blueprint/original/` describe a 100-level campaign and do not provide verified labels/rules for all three modes. Until source evidence is mapped, mode IDs are reserved as M1, M2 and M3; names, progression rules and mode-specific level data remain UNKNOWN. No guesswork should be converted into a shipped feature.

## Recon limits

The current project and available user files do not include a confirmed original-app recording covering all screens and three modes. Existing `visual-qa.zip` is a previous build's own nine-screen QA capture, not evidence of the original app. The repo's `real_pack` inventory shows extracted assets, but the actual APK required to run the official REA workflow is not attached to the `v1.0-apk` release.
