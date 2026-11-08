# 01 · Architecture, UI Flow and Animation System

**Scope:** this document is the design for *your own* game. It is not a copy of the reference build.
Where the reference build's values are readable they live in `blueprint/reference/`; everything here is a
design decision you are free to change.

---

## 1. Engine choice

| Option | Why pick it | Cost |
|---|---|---|
| **Cocos Creator 3.x (TypeScript)** | Best-in-class 2D sprite batching, tween system, `.plist` atlas import, small APK, mature Play Billing plugin | smaller hiring pool than Unity |
| **Unity 6 (C#)** | Biggest ecosystem, Addressables for asset delivery, robust IAP + mediation plugins | larger binary (~40-60 MB base), longer build times |
| **Phaser 3 + Capacitor** | Fastest iteration loop, runs in a browser for QA, one codebase for web + Android | weaker native perf on low-end devices; you own more plumbing |

Recommendation for a first release: **Cocos Creator** if the team is small and the art is 2D-only;
**Unity** if you plan mediation-heavy monetisation (AppLovin MAX and ironSource adapters are best supported there).

Regardless of engine, the architecture below holds.

---

## 2. Application state machine

```
Boot ──► Splash ──► Preload ──► Map ──► Level ──► Result ──► Map
                      │                 │                     │
                      └──► FirstRun ────┘                     └──► Store / Popups (overlay)
```

Rules that prevent most bugs:

1. **One owner per state.** Only the state machine starts and stops scenes. No scene calls another scene directly.
2. **Overlays are not states.** Store, settings, popups and the piggy bank are overlay layers pushed on a
   stack above the current state. Back button pops the stack before it changes state.
3. **Result is a state, not a popup.** The win/lose screen owns the "level complete" side effects
   (coin award, star save, progress write) so a killed app cannot double-award.
4. **Persist on transition, not on timer.** Save to disk when leaving a state; never on `onPause` alone.

### Boot (0 – 300 ms)

- Read save file, run migrations, set locale and audio flags.
- Never do network work here. A cold start that waits on DNS loses ~20 % of first sessions.

### Splash (300 – 1500 ms)

- Logo fade-in 200 ms → hold 800 ms → cross-fade out 250 ms.
- Total *minimum* 1.2 s, *maximum* 1.5 s. If preload is not finished at 1.5 s, show the loading screen
  with a real progress bar instead of holding the logo.

### Preload

- Load in priority order: UI atlas → font → map atlas → first level atlas → audio.
- Progress = `loadedBytes / totalBytes` for the *current* tier, rescaled so each tier owns a slice of the bar
  (e.g. UI 0-40 %, map 40-70 %, level 70-100 %). A bar that jumps from 12 % to 90 % reads as broken.
- Show a tip line rotating every 2.5 s. Tips are cheap content that hides latency.

---

## 3. Screen inventory

| Screen | Purpose | Must have |
|---|---|---|
| Splash | brand, engine warm-up | logo, version string, 1.2 s floor |
| Loading | preload with real progress | progress bar, tip line |
| World map | level progression, the game's home | level nodes, path, current-level pulse, HUD |
| Level | gameplay | grid, cannon, HUD, boosters, pause |
| Result | win/lose, stars, rewards | star burst, coin tally, next/retry |
| Store | coin packs, bundles, VIP | product cards, price, best-value badge |
| Daily spin | retention loop | wheel, 1 free spin / 24 h |
| Piggy bank | soft upsell | progress fill, unlock price |
| Events | limited-time content | timer, progress track |
| Settings | audio, haptics, language, privacy | toggles, restore purchases, privacy link |

### HUD layout (reference resolution 1080 × 1920, scale to fit)

```
safe-area top
├─ 140 px bar
│   ├─ coins pill      x = 24,  w = 240, h = 84
│   ├─ level badge     centred, w = 200, h = 84
│   └─ lives pill      x = 816, w = 240, h = 84   (heart + count + regen timer)
├─ side rail (right edge, vertical)
│   ├─ daily spin      96 × 96, y = 420
│   ├─ events          96 × 96, y = 540
│   ├─ piggy bank      96 × 96, y = 660
│   └─ shop            96 × 96, y = 780
└─ play area
```

Two rules: every touch target ≥ 88 × 88 px at 1080 width (roughly 9 mm on a mid-range phone), and every
HUD element stays inside the safe area — `env(safe-area-inset-*)` equivalent, since notches and gesture
bars eat 40-90 px.

---

## 4. Animation catalog

Durations assume 60 fps. Use `easeOutQuad` unless stated.

| Animation | Trigger | Spec |
|---|---|---|
| Logo fade | app start | alpha 0→1, 200 ms, hold 800 ms, out 250 ms |
| Progress fill | preload tick | width lerp with `1 - exp(-6t)` smoothing so it never stutters backwards |
| Node pulse | current level on map | scale 1→1.08→1, 1400 ms, loop, `sineInOut` |
| Path reveal | map entry | dash offset 0→full, 600 ms, staggered 60 ms per segment |
| Cannon rotate | drag | angle lerp at 18 rad/s toward touch vector, clamped to ±75° from vertical |
| Bubble swap | tap swap button | two arcs, 160 ms, `easeInOutQuad`, ends with a 40 ms squash |
| Aim line | drag hold | dashed, 12 px dash, alpha 0.55, segments recomputed each frame |
| Wall bounce flash | reflection point | 120 px ring, 200 ms, alpha 1→0 |
| Snap | projectile lands | position tween 60 ms + 1.15 scale punch, 90 ms |
| Pop | cluster ≥ 3 | scale 1→1.25 (70 ms) → 0 (110 ms), 6-10 particles per bubble, 350 ms total |
| Fall | disconnected cluster | gravity 2600 px/s², angular velocity ±90-240 °/s, cull below screen |
| Star award | result | star scale 0→1.3→1, 300 ms each, 180 ms stagger, particle burst per star |
| Coin tally | result | count-up 500 ms, tick sound every 10 coins, coin icon bounce per 50 |
| Popup in/out | any modal | scale 0.85→1, 220 ms `easeOutBack`; out 140 ms `easeInQuad` |
| Screen transition | map ↔ level | 250 ms cross-fade + 12 px upward slide |

**Juice checklist** (cheap, high impact): screen shake 4 px / 120 ms on a 5+ cluster, haptic 12 ms on pop,
haptic 30 ms on star, slight camera zoom 1.0→1.02 on level start, audio pitch +2 % per consecutive pop in
one shot.

---

## 5. Asset pipeline

| Concern | Decision |
|---|---|
| Atlas granularity | one atlas per screen (ui, map, game, fx) + one per level theme |
| Atlas tool | TexturePacker, `cocos2d-x plist` or `json (hash)` output |
| Max atlas size | 2048 × 2048 (safe on every GL ES 3.0 device); 4096 only if you gate it |
| Density | author at 2× (2160 × 3840 baseline) and export 1×/2×; or ship single 2× and scale down |
| Image format | PNG-8 with alpha for UI and sprites; WebP only where the engine supports it losslessly |
| Audio | `.ogg` Vorbis for Android, `.m4a` AAC for iOS; music 96-128 kbps, SFX 64 kbps mono |
| Fonts | one bitmap font (`.fnt` + page PNG) for HUD numbers, one licensed `.ttf` for body text |
| Naming | `category_subject_state`, e.g. `bubble_red_idle`, `ui_btn_play_pressed`, `fx_pop_03` |
| Budget | ≤ 60 MB base APK; ship extra themes as Play Asset Delivery / Addressables |

Every asset must be either (a) drawn by you, (b) bought with a licence that permits commercial
redistribution, or (c) CC0 with the source recorded in `ASSET_CREDITS.md`. That file is your defence if a
store reviewer or a rights-holder asks.

---

## 6. Save data

Single JSON blob, versioned, written atomically (write temp → rename):

```json
{
  "version": 3,
  "progress": { "maxLevel": 42, "stars": { "1": 3, "2": 2 } },
  "wallet": { "coins": 1250, "gems": 4 },
  "lives": { "count": 5, "lastRefillTs": 1762400000 },
  "boosters": { "bomb": 2, "rainbow": 1, "extra_moves": 3 },
  "flags": { "tutorialDone": true, "firstPurchaseDone": false, "adsRemoved": false },
  "stats": { "levelsPlayed": 87, "bubblesPopped": 14320, "adImpressionsToday": 2, "lastAdTs": 1762399000 }
}
```

Migrate forward only, never backward. If `version` is unknown, keep a backup copy and reset — a corrupt save
that crashes on boot is a one-star review.

---

## 7. Definition of done for this layer

- Cold start to interactive map ≤ 3 s on a 4 GB RAM mid-range Android device.
- No frame over 20 ms during a 10-bubble pop with particles on screen.
- Every screen reachable with the back button behaving as described in §2.
- Full playthrough possible in airplane mode (no network dependency for gameplay).
- All text in a localisation table; zero hard-coded strings.
