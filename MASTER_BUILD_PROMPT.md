# 🚀 MASTER BUILD PROMPT — Bubble Shooter: Classic Blast (Godot 4.x Autonomous Studio)

You are the Lead Autonomous Game Studio Agent building **Bubble Shooter: Classic Blast** (`com.classicblast.bubbleshooter`) inside this repository (`agentpocket0-gif/bubble-shooter-complete-blueprint`).

---

## 📂 1. COMPLETE REPOSITORY DATA MAP (ZERO EXTERNAL LINKS NEEDED)
Everything required to build the game from 0 to 100% is already committed inside this repository:

1. **Dataset A — Complete Game Research & 10-Part Blueprint (`blueprint/`):**
   - `blueprint/original/01_ARCHITECTURE_AND_STACK.md` through `10_APP_FLOW_A_TO_Z.md`
   - `blueprint/original/STUDY_SHEET.md` (Exact dimensions, 9-slice margins, color palette, audio timings)
   - `blueprint/reference/INDEX.md`, `MANIFEST.csv`, `LEVEL_SAMPLES.json`, `STRINGS_AND_KEYS.md`
2. **Dataset B — Original Game Code, Level Configs & Coordinate Logic (`reference/original_game_code/`):**
   - `decompiled_scripts/`: Original game scripts and mechanism logic
   - `level_configs/`: Extracted level JSON configurations (`LEVEL_CONFIGS_MASTER.json` & `level_001_ref.json` .. `level_005_ref.json`)
   - `layout_and_plist_coords/`: Sprite atlas `.plist` coordinate mappings and UI layouts
   - `manifests_and_xml/`: Configuration XMLs
3. **Dataset C — Verified Copyright-Free Production Assets (`godot_project/assets/real_pack/`):**
   - Indexed in `godot_project/assets/real_pack/REAL_PACK_MANIFEST.json`
   - `branding/`: Custom `App_Icon_512x512.png` and `Game_Title_Logo_Banner.png`
   - `bubbles/`, `ui/`, `maps_bg/`, `animations/`, `sliced_sprites/`, `audio/`, `levels_fonts/`

---

## 🛠️ 2. AUTONOMOUS STUDIO EXECUTION PIPELINE (MILESTONES 1 TO 5)
Execute the build step-by-step combining **Godogen (Runtime Proof)** + **Claude Code Game Studios (Multi-Department Visual QA)** + **JSON-Driven Level/Scene Architecture**:

### Milestone 1: AssetRegistry & 100% Real Texture/Audio Binding
- Map all files from `godot_project/assets/real_pack/` (and `sliced_sprites/`) into `godot_project/autoload/AssetRegistry.gd`.
- **STRICT RULE:** Never use `draw_circle()` for bubbles/UI or synthetic sine-wave beeps (`AudioStreamGenerator`). Every visual and sound must come from `res://assets/real_pack/`.

### Milestone 2: Boot, Splash & Scrollable Saga World Map
- `Splash.tscn`: Show `Game_Title_Logo_Banner.png` and loading bar over real background texture.
- `SagaMap.tscn`: 120 level nodes (Locked, Unlocked, 1-3 Stars, Current pulsing node), Top HUD (Coins, 5 Lives + 30-min regen timer, Settings), and Side Rail (Daily Spin, Piggy Bank, Store).
- Ensure all decorative containers use `mouse_filter = Control.MOUSE_FILTER_IGNORE` so level buttons and popup `Close` buttons never freeze.

### Milestone 3: Staggered HexGrid Physics, Match-3 BFS & Gravity Drop
- Implement `HexGrid.gd` (`rowPitch = d * sqrt(3)/2`, odd-row right offset `d/2`, 6-neighbour adjacency).
- Drag-to-aim dotted/laser trajectory line with up to 3 wall bounces.
- Rotating cannon barrel displaying Current + Next bubble with tap-to-swap squash animation.
- Substep projectile flight, cell snapping, BFS 3+ same-color pop (`AnimatedSprite2D` 8-frame pop VFX + ascending combo pitch `1.0 + step * 0.08`), and **BFS flood-fill from row 0** so unanchored hanging bubbles detach, fall with gravity, and bounce at bottom score slots.
- Full support for Boosters (`Bomb`, `Fireball`, `Rainbow`, `+5 Moves`) and Blockers (`Ice`, `Stone`, `Chain`).

### Milestone 4: 120 Balanced Levels, Popups & 1-Click Deferred Monetization
- Generate & validate 120 JSON levels (`godot_project/levels/level_001.json` .. `level_120.json`) across all 6 mission types using `reference/original_game_code/level_configs/` and `03_LEVEL_SCHEMA_AND_BALANCE.md`.
- Keep `"ads_enabled": false` by default in `config/live_monetization_config.json` (zero broken ad buttons for Google Play & Apple App Store review; instant 1-click remote activation in 15 days).
- Include `"Restore Purchases"`, Privacy Policy, Terms, Local Data Reset in Settings, and Safe Area notch margins.

### Milestone 5: 27 Headless Checks + 9-Frame Xvfb Visual QA + Android SDK 35 Release
- Run headless validation checks + Xvfb visual QA capturing `qa_proof/01_splash_screen.png` through `09_level_win_result_popup.png`.
- Verify via OpenCV that no frame is black/blank and UI state transitions register high visual diffs.
- Export signed `BubbleShooterClassicBlast-debug.apk` and `BubbleShooterClassicBlast.aab` (`targetSdkVersion = 35`) and publish to GitHub Releases.
