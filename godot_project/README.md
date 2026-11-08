# Bubble Shooter: Classic Blast

An endless, seed-driven hex-grid bubble shooter for Android, built with Godot 4.7.2 from
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
    LevelLibrary.gd        on-demand procedural levels
    SaveSystem.gd          atomic JSON + HMAC tamper evidence
    UI.gd / Overlays.gd    widget factory, modals
  scenes/                  Boot, Splash, SagaMap, Gameplay, Result
  levels/                  120 legacy reference layouts (not used for live progression)
  config/                  bundled monetisation config
  tests/                   headless test suite + visual QA harness
tools/
  ProceduralLevelGenerator.gd seed-based runtime generation + difficulty curve
  levelgen.py              offline reference generator + greedy solver
  validate_levels.py       CI gate
  verify_apk.py            artifact smoke test
```

## Run it

```bash
# editor
godot --path godot_project

# headless test suite (seed, difficulty, endless progression and gameplay checks)
godot --headless --audio-driver Dummy --path godot_project res://tests/TestRunner.tscn

# runtime proof + screenshots (needs a display; CI uses xvfb)
xvfb-run -a -s "-screen 0 1080x1920x24" \
  godot --path godot_project --rendering-driver opengl3 --rendering-method gl_compatibility \
  --audio-driver Dummy res://tests/VisualQA.tscn
python3 tools/visual_qa.py godot_project/qa_proof

# preview the on-device procedural generator in the game; no level pack download is needed
```

## Endless seeded campaign

Live gameplay levels are generated on the device when the player reaches them.
The bundled 120 JSON layouts are kept as reference material; `LevelLibrary`
does not use them to decide which level comes next.

- A new save creates and stores a private campaign seed. The seed and level
  number deterministically decide the board, colours, shape, blockers and mission.
- Replaying the same level keeps its layout. A retry can change the bubble queue
  through the separate attempt seed without changing the board itself.
- Every six-level cycle rotates through clear-all, clear-colour, pop-count,
  rescue, score and survive missions. Rescue levels also have a pop-count goal.
- Difficulty is calculated from the level number. The board grows, the palette
  expands from three to six colours, blocker density rises, and the shot margin
  tightens. Later endless stages add more pressure without requiring more JSON.
- The saga map previews 120 levels at the start, then expands to 20 levels beyond
  the player's highest unlocked level. There is no final level cap.

Level generation is local and offline. It does not wait for a server or a
download. The generated layout is checked for valid dimensions, palette,
objectives and move budget before Gameplay loads it.

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

Nothing ships unverified. The automated gates run on every push:

1. `tests/TestRunner.tscn` — 33 headless checks: grid geometry, wall bounces,
   cluster and floating detection, save tamper rejection, procedural seed reproduction, all six mission types, increasing difficulty, level 2400 generation,
   every `res://assets/...` path in the code resolving, and a real shot through
   the gameplay scene.
2. `tests/VisualQA.tscn` under Xvfb — drives the real scenes, presses the real
   buttons and captures nine 1080x1920 frames. It asserts the splash logo
   texture is non-null, the map builds its current preview of 120 level buttons, the piggy popup opens
   and its Close button closes it, tapping Level 1 starts the level, the board
   renders 43 textured sprites rather than drawn circles, and a shot resolves
   with the HUD updating. `tools/visual_qa.py` then rejects blank or flat frames
   and proves that the screens that must differ do.

The Android build depends on both jobs, so a broken button cannot reach a
release. `qa_proof/` holds the frames and the report from the last run.

## Campaign mission reference

The endless campaign rotates through six primary mission types in repeating six-level cycles:

| Mission | How the player wins |
|---|---|
| Clear all | Clear the board down to the final single-bubble allowance. |
| Clear colour | Remove every bubble of the named colour. |
| Pop count | Pop at least the required number of bubbles. |
| Rescue | Free the required chained bubbles. Rescue levels also include a secondary pop-count goal. |
| Score | Reach the level's score target. |
| Survive | Complete the required number of safe shots without the board reaching the danger row. |

Each mission type has a live win condition in the gameplay scene and an on-screen progress label.

## Verified implementation and remaining production work

Implemented and CI-tested in this repository:

- grid geometry, substepped collision, wall reflection, snapping, matching,
  floating-cluster removal, ice/stone/chained blockers, five boosters
- deterministic on-device levels from the saved campaign seed, across all six mission types:
  clear-all, clear-colour, pop-count, rescue, score and survive. The pattern
  repeats every six levels; rescue levels include a secondary pop-count goal.
- save integrity, lives regen, economy, daily spin, piggy bank, store UI
- headless checks for same-seed reproducibility, different-seed variation, the difficulty curve, all six missions, level 2400, save migration and a real gameplay-scene shot

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
