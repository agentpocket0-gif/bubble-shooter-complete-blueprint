# 10 · Complete App Flow, A to Z

**What this document is:** every screen, every overlay, every transition and every tap, in order, from the
moment the icon is pressed to the moment the player closes the app. Written so a developer or an AI agent can
implement the whole flow without asking a single question.

**How to read it:** §4 is the state machine (the skeleton). §5-§6 are the first ninety seconds, second by
second. §7 is every screen in detail, each with a tap table. §8 is the life of one shot. §9 is the win/lose
tree. §10 is popup priority — the part almost everyone gets wrong.

All timings assume 60 fps. All coordinates assume a 1080 × 1920 reference canvas, origin top-left.

---

## 1. Vocabulary

| Term | Meaning |
|---|---|
| **State** | A full-screen mode. Only one is active. Owns the whole screen. |
| **Overlay** | A layer above a state: popup, store, pause. Pushed on a stack, does not change state. |
| **Phase** | A sub-step inside a state (e.g. gameplay: aiming → flying → resolving → ready). |
| **Idle gate** | A condition checked before a popup may appear. Prevents popup spam. |
| **First-run** | Everything that happens only on the very first launch of the install. |

---

## 2. Global rules

1. **One state, many overlays.** The back button pops the overlay stack first; only when the stack is empty
   does it act on the state (map → confirm exit, level → pause).
2. **Every transition is cancellable except purchase.** If the player taps during a 250 ms screen fade, the
   input is buffered and applied after the fade, not dropped.
3. **Nothing blocks on the network.** Every network call has a 10 s timeout and a local fallback. The game is
   fully playable in airplane mode.
4. **Save on exit of every state**, not on a timer.
5. **The first session never shows an interstitial.** No exceptions.
6. **One popup at a time**, chosen by the priority system in §10.

---

## 3. Navigation map

```
                      ┌──────────────┐
   icon tap ─────────►│ 1. Boot      │
                      └──────┬───────┘
                             ▼
                      ┌──────────────┐   first run only
                      │ 2. Splash    │──────────────┐
                      └──────┬───────┘              ▼
                             ▼                 ┌───────────┐
                      ┌──────────────┐         │ 3. Intro  │
                      │ 4. Loading   │◄────────┤  (tutorial│
                      └──────┬───────┘         │  intro)   │
                             ▼                 └───────────┘
                      ┌──────────────┐
            ┌────────►│ 5. Map       │◄───────────────────────┐
            │         └───┬──────┬───┘                        │
            │             │      │                            │
   back     │      node tap     side icons                    │
            │             ▼      ▼                            │
            │      ┌──────────┐ ┌────────────┐                │
            │      │ 6. Level │ │ Overlays:  │                │
            │      └────┬─────┘ │ Store      │                │
            │           │       │ Spin       │                │
            │           ▼       │ Piggy      │                │
            │      ┌──────────┐ │ Events     │                │
            └──────┤ 7. Result│ │ Settings   │                │
                   └────┬─────┘ └────────────┘                │
                        │  next / retry                        │
                        └──────────────────────────────────────┘
```

---

## 4. State machine

### 4.1 States

| # | State | Entered from | Exits to |
|---|---|---|---|
| 1 | `Boot` | process start | `Splash` |
| 2 | `Splash` | `Boot` | `Intro` (first run) or `Loading` |
| 3 | `Intro` | `Splash`, first run only | `Loading` |
| 4 | `Loading` | `Splash`, `Intro`, `Map` (level load) | `Map` or `Level` |
| 5 | `Map` | `Loading`, `Result` | `Level`, overlays |
| 6 | `Level` | `Map` (node tap) | `Result`, `Map` (abandon) |
| 7 | `Result` | `Level` (win or lose) | `Map`, `Level` (retry/next) |

### 4.2 Transition table

| From | Trigger | To | Transition | Duration |
|---|---|---|---|---|
| `Boot` | save loaded or created | `Splash` | none (same frame) | 0 |
| `Splash` | 1.2 s elapsed **and** preload ≥ 60 % | `Intro`/`Loading` | cross-fade | 250 ms |
| `Splash` | 1.5 s elapsed, preload < 60 % | `Loading` | cross-fade | 250 ms |
| `Intro` | last tutorial slide dismissed | `Loading` | cross-fade | 200 ms |
| `Loading` | assets ready | `Map`/`Level` | fade + 12 px rise | 250 ms |
| `Map` | level node tapped and unlocked | `Loading` | fade | 200 ms |
| `Map` | level node tapped, locked | — (shake + toast) | node shake | 300 ms |
| `Level` | objective met | `Result` (win) | slow-mo 400 ms, then fade | 600 ms |
| `Level` | shots = 0 or board full | `Result` (lose) | fade to desaturate | 400 ms |
| `Level` | pause → quit | `Map` | fade | 250 ms |
| `Result` | Next | `Loading` → `Level` | fade | 250 ms |
| `Result` | Retry | `Loading` → `Level` | fade | 250 ms |
| `Result` | Map | `Map` | fade | 250 ms |

### 4.3 Overlay stack

```
Level or Map
  ├── Pause            (level only)
  ├── Settings
  ├── Store
  ├── Daily spin
  ├── Piggy bank
  ├── Events
  └── Popups: OutOfLives, Reward, RateUs, ForceUpdate, Maintenance, PurchaseConfirm
```

Push adds a scrim (60 % black) and scales the popup 0.85 → 1.0 over 220 ms. Pop reverses in 140 ms.
Back button = pop. Tapping the scrim = pop, **except** for `ForceUpdate` and `PurchaseConfirm`, which must be
answered with a button.

---

## 5. First launch, second by second

| Time | State | What happens | Player sees |
|---|---|---|---|
| 0.00 s | `Boot` | Process starts. Save file read. Locale detected. Audio flags loaded. **No network call.** | black or the system splash |
| 0.15 s | `Boot` | Engine initialises, first scene loads. | logo appears (engine splash suppressed in release builds) |
| 0.30 s | `Splash` | Studio logo fades in over 200 ms. | logo at 40 % screen height |
| 0.50 s | `Splash` | Logo holds. Preload begins in the background (UI atlas first). | logo, version string bottom-right at 30 % alpha |
| 1.30 s | `Splash` | Logo fades out 250 ms. | fade to background colour |
| 1.55 s | `Intro` | First-run only: a 3-slide intro. Slide 1: "Match 3 bubbles". Slide 2: "Bounce off walls". Slide 3: "Clear the board before you run out of shots". Each slide has a Skip in the top-right. | 3 illustrated cards, dots at the bottom |
| — | `Intro` | If the player taps Skip at any point, jump straight to `Loading`. | |
| 3.50 s | `Loading` | Real progress bar: UI atlas 0-40 %, map atlas 40-70 %, level 1 atlas 70-100 %. Tip text rotates every 2.5 s. | bar + tip |
| 5.00 s | `Loading` | Preload complete. | bar full, 200 ms hold |
| 5.20 s | `Map` | Map fades in with a 12 px rise. Level 1 node pulses. A finger hint points at it after 800 ms. | world map, HUD top, side icons |
| 6.00 s | `Map` | Player taps the pulsing level 1 node. | node scale-punch, whoosh |
| 6.20 s | `Level` | Board builds in with bubbles dropping from the ceiling over 400 ms, staggered 20 ms per row. HUD slides in from the top over 250 ms. Cannon slides up from the bottom over 300 ms. | the level, ready to play |

**Total: about 6.5 seconds from icon tap to first shot available.** Every extra second here costs roughly
2-3 % of installs; treat 7 s as the hard ceiling.

---

## 6. First-run tutorial script (level 1 only)

Level 1 is a tutorial dressed as a level. It uses 3 colours, 12 shots, and a 5-row board. Each step below is
one tutorial gate; the next gate does not arm until the previous one is satisfied.

| Step | Gate | Screen behaviour | Copy |
|---|---|---|---|
| T1 | Level starts | Everything dimmed except the cannon. Drag anywhere enabled. | "Drag to aim, release to shoot" |
| T2 | Player drags > 40 px | Dim clears, dashed trajectory appears. | — |
| T3 | Player releases | Shot fires. | — |
| T4 | First bubble snaps | Highlight the 2 same-colour neighbours of the landing spot. | "Match 3 of the same colour" |
| T5 | Cluster of 3 pops | Slow-mo 0.5× for 300 ms around the pop, particles boosted 1.5×. | "Nice!" |
| T6 | Board has a floating group | Highlight it before it falls. | "Cut a group loose and it falls" |
| T7 | Board cleared | Win. Result screen appears with 3 stars, +40 coins, and a "Continue" button. | "Level 1 complete" |
| T8 | Player taps Continue | Return to `Map`. Level 2 node unlocks with a burst. | "Level 2 unlocked" |

The tutorial never blocks input. If the player does something else, the gate simply waits. Never show a modal
in the tutorial — dimming plus one line of copy is the whole language.

---

## 7. Screen specifications

### 7.1 Splash

| Element | Position | Notes |
|---|---|---|
| Logo | centred, 60 % width | PNG with alpha |
| Version string | bottom-right, 24 px, 30 % alpha | `v1.0.0 (build 12)` |
| Background | full-bleed colour | from `colors.xml` equivalent, your own palette |

Exit: 1.2 s minimum, 1.5 s maximum. Never wait for the network here.

### 7.2 Loading

| Element | Position | Behaviour |
|---|---|---|
| Progress bar | centred, 60 % width, 16 px tall | real bytes loaded, smoothed with `1 - exp(-6t)` |
| Percentage text | right of the bar | integer, never goes backwards |
| Tip text | below the bar | rotates every 2.5 s, 12 tips |
| Spinner | optional, only if a stage stalls > 2 s | |

### 7.3 Map (home)

| Element | Position | Tap action |
|---|---|---|
| Coins pill | x 24, y 84, 240 × 84 | opens `Store` → coin tab |
| Level badge | centred, 200 × 84 | shows current level; tap does nothing |
| Lives pill | x 816, y 84, 240 × 84 | if lives < max: opens `OutOfLives` popup; if full: toast "Lives full" |
| Settings | top-right, 88 × 88 | opens `Settings` |
| Daily spin | right rail, y 420, 96 × 96 | opens `Daily spin` (badge dot if unused today) |
| Events | right rail, y 540 | opens `Events` (hidden when no event is active) |
| Piggy bank | right rail, y 660 | opens `Piggy bank` |
| Shop | right rail, y 780 | opens `Store` |
| Level nodes | along the path, 128 × 128 | current → starts level; done → starts level (replay); locked → shake + toast "Finish level N first" |
| Scroll | vertical | map scrolls to the current node on entry, 400 ms ease |

Node states: `locked` (grey, padlock), `current` (pulsing, 1400 ms loop), `done` (colour, star count below),
`done-3star` (gold rim). The map always auto-scrolls to `current` on entry — a player who lands on a
scrolled-away map is lost.

### 7.4 Level (gameplay)

Phases inside the state:

```
READY ──touch down──► AIMING ──release──► FLYING ──hit──► RESOLVING ──► READY
  ▲                                                          │
  └──────────────────────────────────────────────────────────┘
                     (or WIN / LOSE)
```

| Element | Position | Behaviour |
|---|---|---|
| Board | top, 11 columns × 96 px | bubbles snap to the grid |
| HUD: coins | top-left, 240 × 84 | updates live when coins are earned |
| HUD: shots left | top-centre, 200 × 84 | big number; turns amber at 5, red at 3, pulses at 1 |
| HUD: objective | below the shot counter | "Clear all bubbles" / "Pop 60" |
| HUD: pause | top-right, 88 × 88 | opens `Pause` overlay |
| Booster bar | bottom, above the cannon, 3 slots × 132 px | tap a slot to arm that booster |
| Cannon | bottom-centre | rotates ±75° from vertical |
| Current bubble | in the cannon | |
| Next bubble | right of the cannon, 96 px, with a swap arrow | tap the arrow to swap (free, once per shot) |
| Ghost preview | on the landing cell | 40 % alpha |

Tap/gesture table for the level:

| Gesture | Phase | Result |
|---|---|---|
| Touch down anywhere on the lower 40 % | READY | `AIMING`, cannon starts rotating toward the touch |
| Drag | `AIMING` | cannon follows at 18 rad/s, trajectory redraws every frame |
| Lift | `AIMING` | shot fires, `FLYING` |
| Tap the swap arrow | READY | current ⇄ next, 160 ms arc, `sfx_booster_swap` |
| Tap a booster slot | READY | booster armed, next shot uses it |
| Tap the same booster again | READY | booster disarmed, no cost |
| Tap the armed booster's target (bomb) | READY | enters a targeting sub-mode with a reticle; tap the board to place |
| Tap pause | any | `Pause` overlay |
| Back button | any | `Pause` overlay (never exits directly) |

### 7.5 Pause

| Element | Action |
|---|---|
| Resume | pops the overlay, un-pauses audio |
| Restart | confirm popup → reload level, shots reset, boosters refunded |
| Sound / music toggles | immediate, persisted |
| Quit | confirm popup → `Map`; the level is not counted as played, no shots are consumed |
| Settings | pushes `Settings` on top |

### 7.6 Result — win

| Element | Behaviour |
|---|---|
| Background | level board blurred, 3 stars animate in at 180 ms stagger |
| Star 1/2/3 | filled or empty per the score thresholds; `sfx_star_01/02/03` |
| Score | counts up over 500 ms |
| Coins earned | "+40" flies to the coins pill, pill increments |
| Buttons | **Next** (primary), **Replay**, **Map** |
| Rewarded offer | "Double your coins" button, only if a rewarded ad is available; disappears after use |
| First-clear bonus | "+100 first clear" chip if this was the first completion |

### 7.7 Result — lose

| Element | Behaviour |
|---|---|
| Background | board desaturated, shot counter shows 0 |
| Message | "Out of shots" or "No space left" |
| Buttons | **Retry** (primary), **Map** |
| Rewarded offer | "Watch to get +5 moves and continue" — arms a continue with 3 extra shots |
| Booster offer | "+5 moves for 150 coins" if the player can afford it |
| Interstitial | only here, only after the player declines the rewarded offer, and only if caps allow |

That order matters: rewarded first, paid second, interstitial last. Reversing it costs revenue and trust.

### 7.8 Store

| Element | Behaviour |
|---|---|
| Tabs | Coins · Boosters · Specials |
| Product card | icon, name, contents, price read from Play Billing (never hard-coded), "best value" badge |
| Tap card | purchase flow; on success, grant + acknowledge, then a success popup with the items |
| VIP card | subscription, shows renewal terms |
| No-ads card | hidden if already owned |
| Restore purchases | in Settings, not here |

### 7.9 Daily spin

| Element | Behaviour |
|---|---|
| Wheel | 8 segments: 50, 100, 200, 500 coins, 1 booster, 2 boosters, 20 gems, jackpot |
| Free spin | once per 24 h; button disabled with a countdown after use |
| Rewarded re-spin | up to 2 per day, opt-in |
| Animation | 3.5 s deceleration with a tick per peg, lands on a pre-determined prize |

### 7.10 Piggy bank

| Element | Behaviour |
|---|---|
| Fill | +10 coins per level completed, capped at the unlock price |
| Unlock | one IAP; grants the full contents |
| UI | a jar that visually fills; a "full!" state that nudges |

### 7.11 Settings

Rows: Sound, Music, Haptics, Notifications, Language, Restore purchases, Privacy policy, Terms, Support,
Version, and a hidden long-press debug panel in debug builds only.

---

## 8. The life of one shot

The most-implemented-wrong sequence in the genre. Exact order:

| # | Event | Phase | What must happen |
|---|---|---|---|
| 1 | Touch down | `READY` → `AIMING` | record touch, start cannon rotation, play `sfx_cannon_rotate` loop |
| 2 | Drag | `AIMING` | rotate cannon, draw trajectory (simulated, up to 3 bounces), show ghost cell |
| 3 | Lift | `AIMING` → `FLYING` | spawn projectile at the cannon mouth, stop the rotate loop, `sfx_shot` |
| 4 | Integrate | `FLYING` | substep ≤ `d/2`, check bubble collision + ceiling + walls |
| 5 | Wall hit | `FLYING` | reflect, `sfx_wall_bounce` with rising pitch |
| 6 | First contact | `FLYING` → `RESOLVING` | snap to the best free neighbour, `sfx_snap`, 1.15 scale punch |
| 7 | Decrement shots | `RESOLVING` | HUD updates immediately, not after the pop |
| 8 | Match BFS | `RESOLVING` | find same-colour cluster |
| 9 | Cluster ≥ 3 | `RESOLVING` | pop animation (70 ms + 110 ms), pop pitch ladder, score, particles |
| 10 | Remove from board | `RESOLVING` | **after** the animation starts, so the sprite can animate out |
| 11 | Floating BFS | `RESOLVING` | find disconnected cells, spawn falling bodies |
| 12 | Falling | `RESOLVING` | individual gravity 2600 px/s², spin, cull off-screen, `sfx_drop_*` |
| 13 | Booster charge | `RESOLVING` | if cluster ≥ 10, charge the bomb booster (one charge per level) |
| 14 | Win check | `RESOLVING` | objective met → `WIN` |
| 15 | Lose check | `RESOLVING` | shots = 0 or no free cell → `LOSE` |
| 16 | Refill | `RESOLVING` → `READY` | current = next, next = queue.pop(), re-roll if colour absent from board |
| 17 | Re-enable input | `READY` | input unlocked **only after** the resolve animation ends (or 600 ms max) |

Rule: input stays locked during `RESOLVING` for at most 600 ms. Beyond that the game feels unresponsive even
if the animation is pretty.

---

## 9. Win and lose decision tree

```
after every resolve:
  ├─ objective satisfied?
  │    ├─ yes → WIN
  │    │        ├─ award coins (40 + first-clear 100)
  │    │        ├─ save stars if better than before
  │    │        ├─ unlock next level
  │    │        ├─ increment piggy bank
  │    │        └─ → Result(win)
  │    └─ no ↓
  ├─ shots == 0?
  │    ├─ yes → LOSE → Result(lose)
  │    └─ no ↓
  ├─ board full / no free neighbour?
  │    ├─ yes → LOSE (reason "no space") → Result(lose)
  │    └─ no ↓
  └─ ceiling drop due this shot?
       ├─ yes → shift all rows down, check board full again, sfx_ceiling_drop
       └─ no → continue
```

---

## 10. Popup priority

Only one popup may be visible. When several are eligible, the highest priority wins; the others are retried
on the next idle gate.

| Priority | Popup | Condition | Frequency |
|---|---|---|---|
| 100 | Force update | remote `min_version` > installed | once per launch until updated |
| 90 | Maintenance | remote flag on | every 60 s while on |
| 80 | Purchase confirm | a purchase is pending | per purchase |
| 70 | Out of lives | lives = 0 and the player tried to start a level | per attempt |
| 60 | Reward granted | after a rewarded ad | per reward |
| 50 | Level-up reward | every 10 levels | per milestone |
| 40 | Piggy bank full | fill ≥ 100 % | once per day |
| 30 | Event started | a new event went live | once per event |
| 20 | Rate us | after 5 wins **and** 3+ days installed, never after a loss | once, ever |
| 10 | Cross-promo / more games | idle on the map | once per session |

Idle gates: no popup within 3 s of a level ending, none while an ad is loading, none in the first session
except Out of Lives.

---

## 11. Entry points other than the icon

| Entry | What happens |
|---|---|
| Push notification "Your lives are full" | opens the app directly to `Map`, lives pill pulses |
| Push notification "New levels available" | opens `Map` at the newest unlocked node |
| Deep link `app://level/42` | if 42 is unlocked → `Loading` → `Level`; else → `Map` with a toast |
| Deep link `app://store/coins` | `Map` + `Store` overlay, coins tab |
| Play Store "Open" | normal cold start |

---

## 12. Return visit (session 2 onwards)

| Time | What happens |
|---|---|
| 0.0 s | `Boot` → save read → `Splash` (no Intro on later launches) |
| 1.2 s | `Loading` — only the atlases not already cached |
| 2.0 s | `Map`, auto-scrolled to the current node |
| 2.2 s | **Idle gate check:** daily reward available? → reward popup. Lives full after being empty? → refill popup. |
| 2.5 s | Player taps the current node, plays |

A returning player must reach gameplay in under 3 seconds. That is the single most valuable performance
target in the whole product.

---

## 13. Edge cases

| Situation | Required behaviour |
|---|---|
| App killed during a level | level is abandoned, no shots consumed, boosters refunded, returns to `Map` |
| App killed on the result screen | rewards already saved before the screen appeared; no double-award |
| Purchase interrupted | grant on next launch after server verification |
| Network lost mid-session | everything continues; ads fail silently; store shows cached prices |
| Clock moved forward 2 days | lives are full; daily spin available; no more than one spin per real day |
| Clock moved backward | timers clamp to 0, never negative |
| Player has 0 coins and 0 boosters and fails | retry is still free; never a dead end |
| Board is full but the objective is met in the same shot | win takes precedence |
| Player taps during the resolve animation | input buffered, applied on `READY`, never dropped |
| Locale is RTL | layout mirrors; cannon stays centred; trajectory unaffected |
| Font scale 200 % | HUD grows, board area shrinks, no clipping |

---

## 14. Flow acceptance tests

1. From a fresh install, a first shot is possible within 7 seconds on a mid-tier device.
2. A returning player reaches gameplay within 3 seconds.
3. No interstitial appears in the first session, verified by instrumenting every ad call.
4. Back button from any screen never exits the app without a confirm.
5. Every screen in §7 is reachable, and every element in every table does what the table says.
6. Killing the app at each of the 7 states and relaunching never loses data and never double-awards.
7. Popup priority is respected when all ten are eligible at once (test with a debug switch).
8. A full playthrough of levels 1-3 can be completed with the network disabled.
9. Every tutorial gate in §6 can be skipped by simply not doing it, with no soft lock.
10. Nothing in the flow requires reading text to progress — an icon-only pass is possible.

---

## 15. Where this connects

- Screens' visual detail: `01_ARCHITECTURE_AND_STACK.md` §3-§4
- Shot physics and matching: `02_HEXGRID_PHYSICS_AND_MATCHING.md`
- Level data: `03_LEVEL_SCHEMA_AND_BALANCE.md`
- Store, prices, ads: `04_ECONOMY_AND_AD_MEDIATION.md`
- Sounds per event: `06_AUDIO_AND_SOUND_DESIGN.md` §3
- Sprites per element: `07_ASSET_PRODUCTION_SPEC.md`
- Tests per screen: `08_QA_DEVICE_MATRIX_AND_RELEASE.md` §2
