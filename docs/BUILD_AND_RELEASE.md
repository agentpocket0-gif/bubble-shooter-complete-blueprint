# Build and release

## CI: `.github/workflows/build_game.yml`

The migration branch uses **Godot 4.7.2-stable** and **Android SDK/API 36**.

The latest completed campaign-generation run created and committed 120 deterministic levels. Its validator reported all six mission types and zero schema problems:

- Campaign generation and validation: https://github.com/agentpocket0-gif/bubble-shooter-complete-blueprint/actions/runs/42453492591
- Generated content commit: `149ed7f241a1b86088347e82bbbf9e5411b1b08e`

Mission distribution (primary mission per level): 20 clear-all, 20 clear-colour, 20 pop-count, 20 rescue, 20 score and 20 survive. Rescue levels also carry a secondary pop-count objective, so the objective-record count for pop-count is 40.

The full build workflow on that generated-content commit is currently marked **action_required** by GitHub. It has not completed its final validation, visual QA or Android export for this exact six-mission campaign commit. The previous Godot 4.7.2/API36 build run did complete successfully, with 29 headless checks, 26 visual QA checks, an 82.3 MB debug APK and a 28.7 MB AAB; that earlier run predates the new six-mission campaign:
https://github.com/agentpocket0-gif/bubble-shooter-complete-blueprint/actions/runs/42452551642

## Automated gates

1. **Content validation**: all 120 level files, solver records, objective schemas and all six required mission types.
2. **Asset integrity**: SHA-256 manifest must match the committed procedural fallback asset tree.
3. **Headless tests**: Godot imports the project and runs `tests/TestRunner.tscn`. The suite now contains 33 checks, including six-mission coverage, chained-bubble rescue, survive timing and a gameplay-scene shot.
4. **Visual QA**: Godot drives the real scenes under Xvfb, captures nine 1080x1920 screenshots, and rejects missing or blank screens.
5. **Android**: JDK 17, SDK 36, matching Godot 4.7.2 export templates, then debug APK and release AAB.

The new 33-check suite and the visual QA gate still need a successful run on the exact generated-content commit before this campaign can be called fully verified.

## Android target API

New Google Play apps and app updates submitted from 31 August 2026 must target Android 16 / API 36 or higher. The export presets and CI SDK packages are set to API 36. This is a target-API configuration only; it does not replace device testing against Android 16.

## Signing key

The AAB is acceptable to Play Console only when signed with the upload key controlled by the app owner. The CI workflow supports these repository secrets:

| Secret | Purpose |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded release keystore |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_ALIAS` | Key alias |
| `ANDROID_KEY_PASSWORD` | Key password |

Without these secrets, CI creates a throwaway key so the build can still be tested. That AAB is **not** a Play Store submission file. Keep the permanent key and backup securely; do not publish it or upload it as a public artifact.

## Still required before a commercial store release

- Approve/run the pending GitHub Actions check for the generated-content PR commit, then fix any new Godot 4.7.2, headless, visual-QA or export errors.
- Import and verify the separate remastered Drive assets pack; the current project art/audio is a procedural fallback pack, not a verified copy of that Drive pack.
- Integrate and test a production ad SDK/native bridge. Ads remain disabled in the bundled config.
- Integrate and test native Google Play Billing. The current code fails closed without a real billing bridge and server-side receipt validation.
- Set up a permanent upload key, create the Play Console products, provide privacy/data-safety disclosures, and perform physical-device tests.
- Verify app icon, screenshots, store listing, age/content rating, crash handling and restore-purchase behavior.

A successful GitHub build proves the code compiled and passed its configured automated tests. It does not, by itself, prove production signing, store compliance, monetisation readiness, or compatibility on every Android device.
