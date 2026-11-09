# Six-department autonomous studio

This pipeline builds an original Godot game. Decompiled APK data and the extracted real_pack folder are study-only inputs and are not copied into the game export.

## Departments and entry points

1. **REA**: rea_analyzer.py summarizes blueprint coverage and reference sample counts. It does not copy protected source code or assets.
2. **GameStudio**: generate_original_assets.py writes original SVG game art; asset_audit.py checks the registry and blocks references to the non-publishable pack.
3. **YJack gameplay**: generate_levels.py, validate_levels.py, and the Godot scripts build the staggered hex-grid shooter and 120 JSON level files.
4. **OpenCode model router**: llm_router.py discovers model IDs at runtime, applies request token buckets, and reads provider keys only from environment variables. autonomous_studio_orchestrator.py applies four-stage scoped repair attempts to GDScript files only.
5. **Godogen validation**: run_validation.sh runs level checks, asset checks, a Godot import, and unit assertions. run_visual_qa.sh runs a virtual-display capture of nine game states.
6. **Replica visual QA**: replica_vision_qa.py checks screenshot integrity and frame-to-frame visual differences, then optionally requests a multimodal visual review.

## Run locally

    python3 tools/generate_original_assets.py
    python3 tools/generate_levels.py
    python3 tools/validate_levels.py
    python3 tools/asset_audit.py
    bash tools/run_validation.sh
    bash tools/run_visual_qa.sh

## GitHub Actions secrets

AI model routing uses NVIDIA_API_KEY and/or GEMINI_API_KEY.

The signed Android AAB needs a persistent upload key belonging to the publisher:
- ANDROID_KEYSTORE_BASE64
- ANDROID_KEYSTORE_PASSWORD
- ANDROID_KEY_ALIAS
- ANDROID_KEY_PASSWORD

Never commit an API key, keystore file, or signing password. Keep the same Android upload key safe for future updates.

## Quality boundary

The automated level checker validates IDs, JSON shape, dimensions, starting colour groups, blockers, objectives and score thresholds. It does not prove every trajectory can be solved or that the progression is balanced. Xvfb screenshots are smoke-test evidence, not a substitute for playing on real Android devices.