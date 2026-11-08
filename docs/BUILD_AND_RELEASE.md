# Build and release

## CI: `.github/workflows/build_game.yml`

The workflow uses **Godot 4.7.2-stable**, Android SDK 36 and runs these gates before a release build:

1. **Validate**: root and bundled monetisation configs match, all 120 level JSON files pass the Python validator, and the asset SHA-256 manifest matches the files in the project.
2. **Headless tests**: Godot imports the project and runs `tests/TestRunner.tscn`. The latest recorded run on the previous Godot 4.4.1 branch had 27 checks and 0 failures. This must be repeated on 4.7.2.
3. **Visual QA**: Godot drives the real scenes under Xvfb, captures nine 1080x1920 screenshots, and rejects missing or blank screens. The previous 4.4.1 run recorded 26 checks and 0 failures. This must be repeated on 4.7.2.
4. **Android**: JDK 17, Android SDK 36, the matching Godot 4.7.2 export templates, then a debug APK and release AAB.
5. **Release**: publishing is conditional on a tag or an explicitly enabled manual workflow input.

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

- Verify the 4.7.2 headless and visual gates after this migration.
- Import and verify the separate remastered Drive assets pack; the current project art/audio is a procedural fallback pack, not a verified copy of that Drive pack.
- Integrate and test a production ad SDK/native bridge. Ads remain disabled in the bundled config.
- Integrate and test native Google Play Billing. SKU labels and store screens alone do not complete billing.
- Set up a permanent upload key, create the Play Console products, provide privacy/data-safety disclosures, and perform physical-device tests.
- Verify app icon, screenshots, store listing, age/content rating, crash handling and restore-purchase behavior.

A successful GitHub build proves the code compiled and passed its configured automated tests. It does not, by itself, prove production signing, store compliance, monetisation readiness, or compatibility on every Android device.
