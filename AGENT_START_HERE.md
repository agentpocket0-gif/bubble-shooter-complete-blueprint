# AI AGENT - START HERE

Read this before touching anything. It reflects what is actually in the repository.

## 1. Design specification (the useful part)
`blueprint/original/01_ARCHITECTURE_AND_STACK.md` through `10_APP_FLOW_A_TO_Z.md`.

## 2. Reference data
`reference/original_game_code/layout_and_plist_coords/` - 44 atlas `.plist`, `.fnt` and DragonBones `.ExportJson` files.

## 3. What does not exist
- No game code. The old `decompiled_scripts/` held only advertising SDK JavaScript.
- No level JSONs. `level_configs/` is empty.
- No Godot project. `godot_project/` contains only assets.

## 4. Assets
`godot_project/assets/real_pack/` - 1595 files from another publisher's app. Not publishable. See `REAL_PACK_MANIFEST.json`.

## 5. Your job
Write an original game in Godot 4 / GDScript following the blueprint. See `MASTER_BUILD_PROMPT.md` and `GAPS.md`.
