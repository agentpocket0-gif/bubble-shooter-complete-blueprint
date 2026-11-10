# Bubble Shooter: Play Store Product Brief v1

**Repository:** `agentpocket0-gif/bubble-shooter-complete-blueprint`  
**Working title:** Bubble Quest: Crystal Rescue  
**Target:** Android phones and tablets  
**Engine baseline:** Godot 4.7.2 stable  
**Branch:** `bubble-shooter-playstore-v1`  
**Status:** Product definition only. This document does not claim that the listed features are implemented or verified.

## 1. Product goal

Build an original, polished, offline-first bubble-shooter with the clarity and replay value expected from leading Play Store puzzle games. The project must be a complete game, not a demo or a menu-only prototype.

The game will use **2D gameplay with premium 2.5D / glossy visual presentation**. A full 3D renderer is not required for the bubble board; lightweight 2D rendering, shaders, lighting, particles and layered art should provide a rich look while preserving smooth performance on mid-range Android devices.

Do not copy competitor code, names, characters, logos, art, sound, level layouts or store listing text. Competitor games are references for publicly visible feature patterns only.

## 2. Competitive reference notes

These are public Google Play listings checked on 10 November 2026:

- [Bubble Shooter - Classic Pop](https://play.google.com/store/apps/details?id=bubbleshooter.orig): listing shows 500M+ installs and 4.6 stars. Publicly described features include offline play, classic match-and-pop gameplay, coins, boosters and daily rewards.
- [Bubble Witch 3 Saga](https://play.google.com/store/apps/details?id=com.king.bubblewitch3): listing shows 100M+ installs and 4.7 stars. Publicly described features include a themed campaign, rescue objectives, special abilities, a world/home progression layer and leaderboards.
- [Bubble Shooter - Pop Bubbles](https://play.google.com/store/apps/details?id=com.bubbleshooter.popbubbles.shootbubblesgame): listing shows 100M+ installs and 4.5 stars. Publicly described features include offline play, classic matching and additional activities.

Counts and ratings can change. Recheck the live listing before using them in marketing.

## 3. Product pillars

1. **Instantly understandable:** aim, shoot, match 3 or more, clear clusters and complete objectives.
2. **Skill matters:** visible aim guide, predictable wall-bounce trajectory, optional shot swap and satisfying chain drops.
3. **Meaningful progression:** a themed campaign map, stars, rewards and new mechanics introduced gradually.
4. **Fair offline play:** core campaign and progress must work without a network connection.
5. **Polished feedback:** readable bubbles, expressive pop/drop effects, layered environments, responsive touch controls and coherent sound design.
6. **Trust:** no deceptive UI, no forced account for offline play, transparent ads and purchases, and no collection of unnecessary personal data.

## 4. Campaign scope

Target initial content: **600 campaign levels**, organized as **12 original worlds × 50 levels**.

Each world must have:
- A distinct original visual theme and color palette.
- A progression curve and level-introduction plan.
- At least one new board or objective twist introduced with a safe tutorial.
- A world-completion reward and clear map presentation.

Each level must define:
- Board geometry and bubble placement.
- Available bubble colors and deterministic seed.
- Objective type and target count.
- Shot budget and star thresholds.
- Obstacles / special pieces, when used.
- Intended difficulty and estimated solve complexity.
- A machine-readable solution certificate or an equivalent solver-backed validation result.

Do not count recolored duplicates as meaningful new levels. Procedural generation may propose levels, but every candidate must be solver-checked, play-tested and reviewed for difficulty variety. A schema-only check is not proof that a level is solvable.

## 5. Core gameplay requirements

- Staggered hex-grid board with consistent neighbour rules.
- Aim by touch drag and release, with a clear trajectory preview.
- Accurate side-wall bounce preview and collision resolution.
- Match 3+ connected bubbles of the same color.
- Remove matched clusters and drop every bubble no longer connected to the ceiling.
- Current and next bubble display; optional swap should be clearly explained.
- Shot counter, objective tracker, pause, restart and level-complete/fail states.
- Three-star scoring based on objective completion and remaining shots.
- Deterministic gameplay resolution independent of animation frame rate.
- Touch targets and HUD sized for phones; support portrait orientation and a range of screen ratios.

## 6. Original objectives and special pieces

Campaign objective candidates:
- Clear all bubbles.
- Rescue crystal sprites by dropping their attached clusters.
- Collect a target color.
- Free sealed crystal bubbles.
- Clear a path to a marked target.
- Complete a limited-shot challenge.

Special board pieces should be introduced gradually and have unambiguous rules. Candidate pieces include stone (cannot be matched, but can fall), ice (requires an adjacent match or defined hit count), locked bubbles, and target crystals. Avoid introducing multiple new rules in the same tutorial level.

## 7. Boosters and economy

Candidate boosters:
- Rainbow bubble: matches any color.
- Bomb: clears a small defined area.
- Fireball: clears a line or path.
- Aim extender: temporarily lengthens the trajectory guide.
- Bubble swap: changes the current bubble.

Economy:
- Earn coins and boosters through level play, world rewards, achievements and daily rewards.
- Keep the normal campaign completable without payment.
- Clearly display the effect and cost before any booster use.
- Do not use artificial scarcity or misleading countdowns.
- Purchases, if added, must be optional and correctly validated.

## 8. Modes and retention

Required for initial release:
- Campaign.
- Daily challenge generated from a deterministic daily seed.
- Endless mode with a locally stored best score.
- Zen / practice mode without a shot limit.

Possible post-launch additions, only after core quality is verified:
- Seasonal events.
- Optional cloud sync.
- Leaderboards and social features.

The campaign and existing local progress must remain available offline. Online features must fail gracefully without blocking the core game.

## 9. Visual and audio direction

Create an original visual identity under the working title **Bubble Quest: Crystal Rescue**:
- Glossy, dimensional-looking bubbles with readable highlights and subtle depth.
- A cohesive original UI kit, icons, buttons, panels, map markers and reward chest.
- Distinct world backgrounds and lightweight parallax layers.
- Short, polished pop, cluster-drop, booster, reward and level-transition animations.
- Optional low-motion mode and reduced screen shake.
- Original or properly licensed sound effects and music.

Use generated or purchased assets only when their license permits the intended commercial distribution. Never include extracted assets from another publisher's APK or mark an asset publishable without evidence of its license.

## 10. Android performance and release requirements

- Android-first portrait experience.
- Mobile-friendly renderer and texture formats.
- Stable frame pacing on mid-range devices; profile CPU, GPU, memory and loading time.
- Graceful handling of pause/resume, process death and low-memory conditions.
- Local progress saves must be versioned and recoverable.
- The release pipeline must export a debug APK for device testing and a signed AAB for Play Console when the publisher's persistent upload keystore is configured.
- New Google Play mobile submissions must target API level 36 or higher as of 31 August 2026. Recheck policy before release.
- Keep all signing keys and provider credentials in GitHub Actions secrets, never in source control.

## 11. QA acceptance gates

A build is not production-ready merely because it compiles or opens.

Required gates:
1. Static project validation and import with the pinned Godot version.
2. Unit tests for grid geometry, collision, match detection, drop connectivity, scoring and saves.
3. Deterministic replay tests for every packaged level.
4. Solver-backed solvability checks for the complete campaign.
5. Gameplay bot runs and edge-case scenarios.
6. Automated screenshots for home, map, gameplay, pause, win, fail and settings.
7. Visual checks for clipping, unreadable labels, missing assets and broken layouts.
8. Android APK installation and real-device gameplay.
9. Performance and crash / ANR checks on target Android hardware.
10. Privacy, ads, billing, content rating, store listing and license review before production release.

QA must report evidence, not just a green summary. Every failed gate must identify the owning subsystem and produce a reproducible report.

## 12. Current repository baseline and known gaps

The repository's 9 November 2026 build-status notes describe an initial playable Godot foundation with original SVG artwork, basic gameplay systems and 120 generated level JSON files.

The same notes explicitly say this is **not a verified production release**. Outstanding work includes:
- First successful end-to-end GitHub Actions run and physical Android device testing.
- Trajectory-aware solvability and difficulty validation for every level.
- Full blocker behaviour and complete booster balancing.
- Polished VFX, swap / falling animations, audio.
- Accessibility and localization.
- Ads / IAP only if deliberately selected, plus billing, privacy and consent work.
- Store listing assets, Data Safety review and Play Console review.

Do not describe the existing project as a complete 600-level game or a Play Store-ready release until these gaps are closed with test evidence.

## 13. Delivery milestones

- **M0 — Repository audit:** inspect code, assets, scenes, workflows, licensing and latest build evidence.
- **M1 — Core game correctness:** complete and test gameplay rules, controls, collision, saves and game states.
- **M2 — Campaign production:** grow from current content to 600 distinct, solver-verified levels across 12 worlds.
- **M3 — Art and UX:** replace placeholder-quality presentation with a complete original visual identity, animation and responsive UI.
- **M4 — Audio and accessibility:** finish audio, haptics, language and accessibility options.
- **M5 — Optional monetization and privacy:** decide ad / purchase scope, integrate safely, verify and document it.
- **M6 — Release QA:** pass headless, visual, Android device, performance, security and store-policy gates.
- **M7 — Release candidate:** generate signed AAB with the persistent publisher key, debug APK, screenshots, test reports and source snapshot.

## 14. Definition of done

The project may be called **complete for release-candidate review** only when all applicable acceptance gates pass and the evidence bundle contains:
- Source project and exact commit.
- Debug APK and signed AAB.
- Verified level catalog and solver report.
- QA checklist, test logs and screenshots.
- Device and performance test report.
- Asset / license manifest.
- Privacy, data safety, ads / billing and store listing materials.

A release candidate is not the same as a Play Store approval. Store submission and approval remain separate steps.
