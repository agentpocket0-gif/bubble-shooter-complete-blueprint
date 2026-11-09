# Repository status and remaining gaps

Updated 9 November 2026. The earlier “0 gaps remain” text was incorrect and has been replaced.

## Implemented in the autonomous studio branch update

- Godot 4 project created from scratch under godot_project/.
- Original SVG artwork generator and AssetRegistry using only assets/own/.
- 120-level deterministic JSON generator and structural validator.
- Core hex-grid math, BFS cluster detection, floating-bubble flood fill, basic projectile/aim flow, booster stubs, save data, splash/map/gameplay/result scenes.
- Six-department scripts and GitHub Actions workflow for headless testing, Xvfb screenshots, OpenCV QA and Android export.

## Still not fully verified or production-complete

1. The game must pass the first GitHub Actions run. GDScript/runtime behaviour and Android export have not been independently verified on a physical Android device in this repository update.
2. The level validator checks schema, dimensions, initial match groups and star ordering; it does not prove complete trajectory-aware solvability or balance for every level.
3. Blocker behaviour, falling animation/landing bounce slots, the full eight-frame pop VFX, current/next swap animation, audio, accessibility and localization need further implementation and testing.
4. Ads and IAP are disabled. No monetization SDK, billing flow, privacy policy or consent flow is included.
5. Real-device profiling, crash/ANR testing, store listing assets, Play Console Data Safety forms, and Play review remain release gates.
6. API-based self-healing requires working provider secrets. A signed Play AAB additionally requires a persistent upload keystore.

## Asset rights

The manifest at godot_project/assets/real_pack/REAL_PACK_MANIFEST.json says publishable=false and notes that the content was extracted from another publisher's application. That directory is excluded from the new game. Removing metadata or altering pixels does not create a redistribution license.

All current game artwork is generated as original SVG vectors by tools/generate_original_assets.py and credited in ASSET_CREDITS.md. No extracted audio is used.

## Android API target

The initial request named API 35. Google Play's current requirement for new mobile apps changed to API 36 on 31 August 2026, so the AAB export preset is set to API 36. This target should be rechecked before future submissions.
