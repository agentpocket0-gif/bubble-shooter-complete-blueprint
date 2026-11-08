# Bubble Shooter: Classic Blast

A 120-level hex-grid bubble-shooter build candidate for Android, migrated to Godot 4.7.2 from
`blueprint/original/01..10.md`. Portrait 1080x1920, 60 fps, offline-first, ads
shipped **off** behind a one-line remote switch.

```
godot_project/
  project.godot            portrait 1080x1920, canvas_items/expand, mobile renderer
  autoload/
    GameManager.gd         state machine, save/load, lives, progression
    AudioManager.gd        music, SFX, combo pitch ladder, mute toggles
    RemoteConfigAndAds.gd  remote config + the deferred ad system
    StoreAndEconomy.gd     coins, boosters, daily spin, piggy bank, IAP
  scripts/
    HexBoard.gd            staggered grid, clusters, floating detection
    ShotSimulator.gd       the one integrator (aim preview == real shot)
    Rng32.gd               xorshift32 colour queue, matches the Python generator
    LevelLibrary.gd        level index + lazy loading
    SaveSystem.gd          atomic JSON + HMAC tamper evidence
    UI.gd / Overlays.gd    widget factory, modals
  scenes/                  Boot, Splash, SagaMap, Gameplay, Result
  levels/                  120 solver-balanced level files + index.json
  config/                  bundled monetisation config
  tests/                   headless test suite + visual QA harness
tools/
  levelgen.py              generator + greedy solver + star thresholds
  validate_levels.py       CI gate
  verify_apk.py            artifact smoke test
```

## Run it

```bash
# editor
godot --path godot_project

# headless test suite (33 checks, exits non-zero on failure)
godot --headless --audio-driver Dummy --path godot_project res://tests/TestRunner.tscn

# runtime proof + screenshots (needs a display; CI uses xvfb)
xvfb-run -a -s "-screen 0 1080x1920x24" \
  godot --path godot_project --rendering-driver opengl3 --rendering-method gl_compatibility \
  --audio-driver Dummy res://tests/VisualQA.tscn
python3 tools/visual_qa.py godot_project/qa_proof

# regenerate every level from scratch (the validator requires all six missions)
python3 tools/levelgen.py --out godot_project/levels --count 120
python3 tools/validate_levels.py godot_project/levels
```

## The ads switch

`config/live_monetization_config.json` exists twice on purpose:

| Path | Who reads it |
|---|---|
| `godot_project/config/live_monetization_config.json` | bundled fallback inside the APK |
| `config/live_monetization_config.json` (repo root) | fetched at launch over HTTPS and cached for 6 h |

To turn ads on in 15 days, edit the **root** file only:

```json
{ "ads_enabled": true, "android_ad_ids": { "rewarded_id": "ca-app-pub-.../...", ... } }
```

No store update, no rebuild. The build is gated three ways before an ad can ever
show: `ads_enabled` is true, the unit id is not a `REPLACE_...` placeholder, and
consent has been answered. The client also enforces the policy rules that get
apps rejected: no interstitial in the first session, none in the first three
minutes, 120 s cooldown, 8 per day, minimum level 6, rewarded always opt-in.

`test_ads_simulation: true` lets you walk the rewarded flows with no SDK at all -
the reward is still granted through the callback, never by the button.

## Verification

Nothing ships unverified. Two gates run on every push:

1. `tests/TestRunner.tscn` — 33 headless checks: grid geometry, wall bounces,
   cluster and floating detection, save tamper rejection, all 120 level schemas,
   every `res://assets/...` path in the code resolving, and a real shot through
   the gameplay scene.
2. `tests/VisualQA.tscn` under Xvfb — drives the real scenes, presses the real
   buttons and captures nine 1080x1920 frames. It asserts the splash logo
   texture is non-null, the map builds 120 level buttons, the piggy popup opens
   and its Close button closes it, tapping Level 1 starts the level, the board
   renders 43 textured sprites rather than drawn circles, and a shot resolves
   with the HUD updating. `tools/visual_qa.py` then rejects blank or flat frames
   and proves that the screens that must differ do.

The Android build depends on both jobs, so a broken button cannot reach a
release. `qa_proof/` holds the frames and the report from the last run.

## Verified implementation and remaining production work

Implemented and CI-tested in this repository:

- grid geometry, substepped collision, wall reflection, snapping, matching,
  floating-cluster removal, ice/stone/chained blockers, five boosters
- 120 deterministic, solver-checked levels across all six primary mission types:
  clear-all, clear-colour, pop-count, rescue, score and survive. There are 20
  levels per primary mission; rescue levels also include a secondary pop-count
  goal. Each level is retained only after the greedy solver clears its mission;
  the shot budget and star thresholds are derived from that run.
- save integrity, lives regen, economy, daily spin, piggy bank, store UI
- 33 headless checks, including six-mission coverage, chained-bubble rescue, survive timing, and a real gameplay-scene shot pipeline

Needs your accounts or hardware:

- **Google Play / App Store**: signing keystore, listing assets, content rating
- **Ad units**: real AdMob/MAX ids in the config (15-day switch)
- **IAP**: `bs.*` products still need to be created in Play Console. Paid purchases now fail closed unless a native billing bridge and server-side receipt validation are present and tested.
- **Native ad SDK**: no production ad adapter is bundled. Ads remain disabled until a supported native bridge, valid ad units and the required consent flow are integrated and tested.
- **iOS**: `export_presets.cfg` ships an `iOS` preset that exports an Xcode project
  (`application/export_project_only=true`). Building it needs a macOS runner, Xcode
  and your Apple team id in `application/app_store_team_id`.

## Assets

All art and audio is procedurally generated by `scripts/generate_original_assets.py`
and owned by you outright - see `ASSET_CREDITS.md`. The 104 MB
`Bubble_Shooter_Classic_Blast_Ready_Assets.zip` on Google Drive is flagged by
Google as "potential malware or spam" and cannot be downloaded through the API;
download it manually in a browser if you want to swap it in.
