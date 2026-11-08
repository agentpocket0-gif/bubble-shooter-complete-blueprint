# 🎯 AI AGENT START HERE — COMPLETE PROJECT MAP
**(Everything is ALREADY inside this repository — DO NOT look for external Google Drive links!)**

All three required datasets have been verified, cleaned, and committed directly into this repository:

## 1. 📚 Complete Game Research & 10-Part Architecture Blueprint
- **Path:** `blueprint/original/01_ARCHITECTURE_AND_STACK.md` through `10_APP_FLOW_A_TO_Z.md`
- **Path:** `blueprint/extra_research/` & `blueprint/reference/`
- **What it contains:** Full game flow (Boot -> Splash -> Saga World Map -> Level Play -> Win/Lose), staggered HexGrid math, BFS match-3 & floating cluster gravity drop rules, 120-level schema, and 1-Click Deferred Monetization specs.

## 2. 💻 Original Game Code, Level JSONs & Coordinate Logic (Code Reference Only)
- **Path:** `reference/original_game_code/`
  - `decompiled_scripts/`: Original game scripts and mechanism logic (14 files)
  - `level_configs/`: Original JSON level layouts, mission definitions, and balance tables (0 files)
  - `layout_and_plist_coords/`: Sprite atlas `.plist` coordinate mappings and UI layouts (44 files)
  - `manifests_and_xml/`: UI and configuration XMLs (953 files)
- **How to use:** Study and port these exact mechanics, level structures, and UI coordinates into Godot 4 (`godot_project/`).

## 3. 🎨 Verified Remastered & Metadata-Cleaned Production Assets
- **Path:** `godot_project/assets/real_pack/` (Indexed in `godot_project/assets/real_pack/REAL_PACK_MANIFEST.json`)
  - `branding/`: Custom `App_Icon_512x512.png`, `Game_Title_Logo_Banner.png`, and logos
  - `bubbles/`: All glossy normal bubbles, boosters (Bomb, Fireball, Rainbow, Laser), and blockers (Ice, Stone, Chain)
  - `ui/`: All 9-slice popup frames, buttons, Top HUD bars, Piggy Bank, Spin Wheel, and Shop icons
  - `maps_bg/`: World map backgrounds and gameplay stage backgrounds
  - `animations/` & `sliced_sprites/`: Full spritesheets PLUS 994 pre-sliced individual `.png` frames ready for `Sprite2D` and `AnimatedSprite2D`!
  - `audio/`: All remastered `.ogg` and `.wav` sound effects and music tracks
  - `levels_fonts/`: Original fonts (`.ttf`/`.fnt`) and level data

## 🚀 MANDATORY BUILD RULES FOR ANY AI AGENT
1. Bind 100% of `godot_project/assets/real_pack/` into `AssetRegistry.gd` and scenes. NEVER use `draw_circle` or synthetic beep audio.
2. Port the exact mechanics and level progression from `reference/original_game_code/` and `blueprint/original/01..10.md`.
3. Keep `"ads_enabled": false` in `config/live_monetization_config.json` for 1-click deferred activation later.
4. Run headless tests + 9-frame Xvfb Visual QA (`qa_proof/01..09.png`) and export signed Android `.apk` and `.aab` to GitHub Releases!
