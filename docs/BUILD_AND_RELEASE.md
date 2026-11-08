# Build and release

## CI: `.github/workflows/build_game.yml`

Three jobs, in order:

1. **validate** — config copies must match, all 100 levels must pass
   `tools/validate_levels.py`, then the Godot headless suite runs
   (`tests/TestRunner.tscn`, 24 checks). Nothing is exported if this fails.
2. **android** — JDK 17, Android SDK 34, Godot 4.4.1 + export templates,
   keystore, Android build template, then a debug `.apk` and a release `.aab`.
3. **release** — publishes both files to a GitHub Release on a `v*` tag or when
   `publish_release` is set on a manual run.

### The signing key

The `.aab` is only acceptable to Play Console if it is signed with a key you
control. Generate it **once**, locally:

```bash
./tools/make_keystore.sh            # writes classic_blast_release.jks, prints its SHA-256
base64 -w0 classic_blast_release.jks > keystore.b64
```

Keep the `.jks` and the passwords offline. Losing this key means you cannot ship
an update under the same listing (unless Play App Signing lets you reset the
upload key).

Without the secrets below, CI still builds - but with a throwaway key generated
for that run, so the AAB will be rejected by Play. The keystore artifact is only
uploaded when the repository is private; on a public repo a downloadable signing
key would let anyone impersonate your app.

## Repository secrets

| Secret | Purpose |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 release.keystore` |
| `ANDROID_KEYSTORE_PASSWORD` | keystore password |
| `ANDROID_KEY_ALIAS` | key alias, e.g. `bubbleshooter` |
| `ANDROID_KEY_PASSWORD` | key password |

Without them the pipeline still builds, but signs with a throwaway key and prints
a warning: **that AAB cannot be uploaded to Play**. Create the real keystore once
and keep it forever — losing it means losing the ability to update the app:

```bash
keytool -genkeypair -v -keystore release.keystore -alias bubbleshooter \
  -keyalg RSA -keysize 2048 -validity 10000
base64 -w0 release.keystore > keystore.b64
```

### Version bumps

`version/code` and `version/name` live in `godot_project/export_presets.cfg`.
The manual workflow takes a `version_code` input that rewrites it for that run;
for a permanent bump, edit the file and commit.

## Local build

```bash
export ANDROID_HOME=$HOME/Android/Sdk
godot --headless --path godot_project --install-android-build-template
godot --headless --path godot_project --export-debug "Android APK" build/app.apk
godot --headless --path godot_project --export-release "Android AAB" build/app.aab
python3 tools/verify_apk.py build/app.apk --package com.classicblast.bubbleshooter
```

## Turning ads on

1. Create the ad units in AdMob (or your mediator) for `com.classicblast.bubbleshooter`.
2. Put the ids in `config/live_monetization_config.json` **at the repository root**.
3. Set `"ads_enabled": true`.
4. Commit to `main`. Every installed copy picks it up on the next launch, within
   the 6-hour cache window.

The APK does not need to be rebuilt or resubmitted.

## Store checklist before submitting

- [ ] real keystore secrets configured
- [ ] `bs.*` products created in Play Console with matching ids
- [ ] privacy policy URL set to the live copy of `PRIVACY.md`
- [ ] content rating questionnaire completed (contains ads: yes, once enabled)
- [ ] data safety form: declares the advertising identifier, no other data
- [ ] target API level meets the current Play requirement
- [ ] closed testing track run before production
