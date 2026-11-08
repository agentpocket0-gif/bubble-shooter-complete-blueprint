# 06 · Audio, Sound Effects and Haptics

**Scope:** every sound the game needs, with names, durations, loudness targets and implementation rules.
This is a production spec, not a wish list — a sound designer can work straight from the tables.

---

## 1. Audio architecture

Four buses, mixed independently, each with its own user-facing slider or a shared one:

| Bus | Contents | Default | User control |
|---|---|---|---|
| `Music` | map, gameplay, tension layers | 0.65 | yes |
| `SFX` | gameplay sounds | 0.85 | yes |
| `UI` | clicks, popups, purchases | 0.7 | follows SFX |
| `Voice` | optional tutorial VO | 1.0 | follows SFX |

Rules:

- **Ducking:** when a rewarded ad starts, fade everything to 0 over 300 ms; restore over 600 ms. Never cut.
- **Pause:** on `onPause`, pause music and stop SFX loops (cannon charge, wheel spin). Resume restores position.
- **Focus loss** (a phone call, another app taking audio focus): duck to 0.2, do not stop, unless the interruption is a call — then pause fully.
- **Max concurrent voices: 8.** Beyond that, drop the oldest, quietest sound. On low-end devices use 5.
- **Never play a sound with `looping = true` for anything shorter than 1 s.** Loops that are too short click.

---

## 2. Loudness targets

| Bus | Target | Peak ceiling |
|---|---|---|
| Music | −16 LUFS integrated | −1.0 dBTP |
| SFX | −14 LUFS short-term | −1.0 dBTP |
| UI | −18 LUFS | −1.0 dBTP |
| Full mix | −14 LUFS integrated | −1.0 dBTP |

Deliver 48 kHz source; ship Ogg Vorbis q5 (~112 kbps) for Android and AAC-LC 128 kbps for iOS. Mono for
every SFX except music and ambience — mono halves the memory and nobody hears stereo on a phone speaker.

---

## 3. Complete SFX catalogue

Durations are the actual file lengths, not how long the sound feels.

| # | Name | Trigger | Length | Loop | Voices | Notes |
|---|---|---|---|---|---|---|
| 1 | `sfx_cannon_rotate` | dragging the aim | 0.4 s | yes | 1 | soft mechanical tick, pitch follows drag speed ±10 % |
| 2 | `sfx_aim_lock` | aim within 3° of vertical | 0.08 s | no | 1 | subtle click, gives a "magnetic" feel |
| 3 | `sfx_shot` | release to fire | 0.25 s | no | 1 | short whoosh + soft thump; must not mask the pop |
| 4 | `sfx_wall_bounce` | projectile hits a side wall | 0.12 s | no | 2 | pitch +2 semitones per bounce in the same shot |
| 5 | `sfx_snap` | bubble locks into the grid | 0.09 s | no | 1 | dry click; the most-heard sound in the game, keep it quiet |
| 6 | `sfx_pop_01` | 1st bubble of a cluster | 0.18 s | no | 4 | bright, short |
| 7 | `sfx_pop_02` | 2nd | 0.18 s | no | 4 | +2 semitones |
| 8 | `sfx_pop_03` | 3rd | 0.18 s | no | 4 | +4 semitones |
| 9 | `sfx_pop_04` | 4th | 0.18 s | no | 4 | +6 semitones |
| 10 | `sfx_pop_05` | 5th and beyond | 0.18 s | no | 4 | +8 semitones, cap here |
| 11 | `sfx_cluster_big` | cluster ≥ 6 | 0.5 s | no | 2 | layered shimmer on top of the pop ladder |
| 12 | `sfx_drop_start` | floating cluster detaches | 0.3 s | no | 1 | airy "release" |
| 13 | `sfx_drop_land` | falling bubbles pass the bottom edge | 0.15 s | no | 3 | soft, distant |
| 14 | `sfx_ceiling_drop` | the board drops a row | 0.6 s | no | 1 | low rumble + creak; this is a threat cue, make it land |
| 15 | `sfx_booster_bomb` | bomb booster used | 0.7 s | no | 1 | explosion with a tail, no distortion |
| 16 | `sfx_booster_rainbow` | rainbow booster used | 0.8 s | no | 1 | rising arpeggio + sparkle |
| 17 | `sfx_booster_laser` | aim laser used | 0.3 s | no | 1 | thin zap |
| 18 | `sfx_booster_swap` | swap current/next | 0.2 s | no | 1 | two-tone flip |
| 19 | `sfx_booster_extra_moves` | +5 moves | 0.4 s | no | 1 | coins falling into a cup |
| 20 | `sfx_ui_click` | any button | 0.06 s | no | 3 | quiet, dry; users hear this hundreds of times |
| 21 | `sfx_ui_back` | back / close | 0.08 s | no | 2 | descending |
| 22 | `sfx_popup_open` | modal appears | 0.25 s | no | 2 | whoosh + soft bell |
| 23 | `sfx_popup_close` | modal dismissed | 0.18 s | no | 2 | reverse whoosh |
| 24 | `sfx_coin_tick` | coin counter increment | 0.04 s | no | 1 | played every 10 coins, not every coin |
| 25 | `sfx_star_01` | 1st star | 0.5 s | no | 1 | single chime, mid |
| 26 | `sfx_star_02` | 2nd star | 0.5 s | no | 1 | chime +3 semitones |
| 27 | `sfx_star_03` | 3rd star | 0.9 s | no | 1 | chime +7 + shimmer tail |
| 28 | `sfx_level_win` | result screen, win | 1.8 s | no | 1 | short fanfare, resolves |
| 29 | `sfx_level_fail` | result screen, loss | 1.4 s | no | 1 | descending, not harsh — the player already feels bad |
| 30 | `sfx_lives_empty` | last life spent | 1.0 s | no | 1 | soft "empty" thud |
| 31 | `sfx_life_refill` | a life returns | 0.5 s | no | 1 | warm chime |
| 32 | `sfx_spin_tick` | wheel passing a peg | 0.05 s | no | 1 | one per peg, ~30 total |
| 33 | `sfx_spin_win` | wheel stops on a prize | 1.2 s | no | 1 | fanfare, reuse `sfx_level_win` shortened |
| 34 | `sfx_piggy_fill` | piggy bank gains coins | 0.15 s | no | 1 | coin drop, pitch rises with fill level |
| 35 | `sfx_purchase_success` | IAP completed | 1.0 s | no | 1 | bright, reassuring |
| 36 | `sfx_purchase_fail` | IAP failed | 0.6 s | no | 1 | neutral, not an error buzzer |
| 37 | `sfx_ad_reward` | rewarded ad completed | 0.8 s | no | 1 | distinct from purchase so players learn it |
| 38 | `sfx_countdown` | 3-2-1 on a timed objective | 0.1 s | no | 1 | last second is +4 semitones |
| 39 | `sfx_blocker_crack` | ice takes a hit | 0.2 s | no | 2 | brittle |
| 40 | `sfx_blocker_break` | ice destroyed | 0.35 s | no | 2 | glass shatter, filtered |
| 41 | `sfx_chain_break` | chained bubble freed | 0.4 s | no | 2 | metal snap |
| 42 | `sfx_tutorial_point` | tutorial highlight | 0.1 s | no | 1 | soft ping |
| 43 | `sfx_tension_layer` | last 3 shots | 2.0 s | yes | 1 | music layer, not an SFX bus item |

That is 43 assets, roughly 15 MB of Ogg at these lengths. If you must cut, cut 32, 34, 38 — never cut 5, 6-10
or 20, because those carry the feel.

### The pop pitch ladder (the single most important audio decision)

Consecutive pops inside one shot climb a scale. Implemented as pitch, not as separate files:

```
pitch(n) = min(2^(2n/12), 1.587)     // 2 semitones per pop, capped at +8
```

Reset `n` on every new shot. This one line is what makes a long chain feel like a combo instead of noise.

### Combo / streak audio

| Streak | Behaviour |
|---|---|
| 2 clusters in one shot | pop ladder continues, add a light shimmer layer |
| 3 clusters in one shot | add a rising sweep, haptic 20 ms |
| 5 clusters in one shot | full `sfx_cluster_big` + 40 ms haptic, screen shake |

---

## 4. Music

Three tracks, each with stems so you can add tension without a new file:

| Track | Length | Tempo | Stems | Use |
|---|---|---|---|---|
| `bgm_map` | 2:00 loop | 96 BPM | full, no-drums | world map |
| `bgm_game` | 2:00 loop | 108 BPM | drums, bass, melody | gameplay |
| `bgm_tension` | 1:30 loop | 108 BPM | pulse, strings | last 3 shots, board nearly full |

Crossfade: 800 ms between map and gameplay; 400 ms into tension (faster feels like an alarm).
Loop points must be sample-accurate and the file must contain a small tail so the loop does not click.

If music licensing is a constraint at launch: ship one gameplay track and one map track, and buy more later.
Silence is worse than one good loop, but two tracks and a tension layer is enough to ship.

---

## 5. Haptics

Use the platform haptic API, not vibration with a duration.

| Event | Pattern | Intensity |
|---|---|---|
| Bubble snap | light tick | 0.3 |
| Pop (per cluster) | light | 0.25 |
| Cluster ≥ 6 | medium, 40 ms | 0.6 |
| Booster used | medium | 0.7 |
| Star awarded | heavy, one per star | 0.9 |
| Level fail | heavy double pulse | 0.8 |
| Button press | selection tick | 0.2 |

Always respect the system setting and offer an in-game toggle. Haptics on every tap is the fastest way to
get a one-star review from someone on a train.

---

## 6. Sourcing audio legally

| Source | Licence | Watch out for |
|---|---|---|
| Freesound (CC0 filter only) | CC0 | CC-BY needs attribution in-app; check per file |
| Kenney.nl audio packs | CC0 | genuinely free, good for UI |
| OpenGameArt | mixed | many are CC-BY-SA, which can infect your build |
| Commissioned composer / sound designer | your contract | get an assignment of rights, not a licence |
| Epidemic Sound / Artlist | subscription | **not** cleared for game redistribution unless the tier says so — read it |
| AI-generated audio | varies by tool | check the tool's commercial terms; keep a record |

Record every file in `ASSET_CREDITS.md`: filename, source URL, licence, author, date pulled. Store the licence
text alongside. That file is what you show a store reviewer or a rights claim.

---

## 7. Implementation notes

```
AudioManager
  preload(bus, names[])          // at level load, not at play time
  play(name, {pitch, volume, bus}) -> handle
  playLadder(step)               // pops
  stopLoop(handle)               // cannon, wheel, tension
  setBusVolume(bus, v)           // persisted in save
  duck(bus, target, ms)
```

- Pool `AudioSource` objects (8). Creating one per play is a frame hitch on low-end devices.
- Preload the next level's SFX during the result screen — never during the first shot.
- Never `Resources.Load` an AudioClip in the middle of gameplay.
- Test on the phone speaker, at 30 % volume, with the case on. Most players never use headphones.

---

## 8. Accessibility

- **Subtitles/visual cues:** every audio cue that carries information (ceiling drop, life refill, star) also
  needs a visual or haptic equivalent. A player with sound off must not lose information.
- **Mono downmix** option.
- **Separate music/SFX sliders** — not one master volume.
- Never gate gameplay on audio timing.

---

## 9. Definition of done

- 43 SFX + 3 music tracks delivered, normalised to the targets in §2.
- Pop ladder implemented as pitch, verified by ear across a 10-pop chain.
- Ducking, pause, focus-loss and interruption all tested on a real device.
- `ASSET_CREDITS.md` lists every audio file with a licence.
- Total audio footprint ≤ 18 MB.
