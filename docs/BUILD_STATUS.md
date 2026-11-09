# Bubble Shooter: Classic Blast - build status

Last repository implementation update: 9 November 2026.

## What is included

- A new Godot 4 project under godot_project/, with portrait layout and package ID com.classicblast.bubbleshooter.
- Original SVG artwork generated from tools/generate_original_assets.py. Runtime scripts refer only to res://assets/own/.
- Staggered odd-row hex-grid coordinate math, six-neighbour adjacency, cluster BFS, top-row anchored flood fill, projectile movement, bank-shot preview, boosters, save data, map screens and basic result UI.
- A deterministic generator for 120 level JSON files and a structural level validator. The JSON validator does not prove every shot sequence can be solved.
- A six-department coordinator, restricted LLM patching, model discovery/rate limiting, headless tests, Xvfb screenshot capture, and OpenCV comparison.
- Android APK and AAB export presets. Ads and IAP remain off by default.

## Important exclusions and release gates

- The extracted asset pack is not publishable according to its own manifest. It is excluded from the game.
- The current game implementation is an initial playable foundation, not a verified production release. Real-device testing, complete booster/blocker balancing, full accessibility/localization, audio, billing, ads, privacy disclosures, and Play Console review remain separate tasks.
- Automated QA screenshots are smoke evidence. They do not replace device testing or prove every level is fun or solvable.
- Release signing requires a persistent upload keystore belonging to the publisher. Never rotate or lose it after publishing.
- For new Android mobile apps, Google Play requires API 36 as of 31 August 2026. The export preset therefore targets API 36 rather than the earlier API 35 value in the initial brief.

## GitHub Actions secrets

Provider keys:
- GEMINI_API_KEY
- NVIDIA_API_KEY

Android signing keys:
- ANDROID_KEYSTORE_BASE64
- ANDROID_KEYSTORE_PASSWORD
- ANDROID_KEY_ALIAS
- ANDROID_KEY_PASSWORD

The workflow reads secrets from the GitHub Actions environment only. It never writes API keys or the keystore into tracked source files.
