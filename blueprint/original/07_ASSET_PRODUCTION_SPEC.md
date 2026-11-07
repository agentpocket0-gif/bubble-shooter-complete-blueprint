# 07 · Asset Production Specification

**Scope:** every sprite, font and effect file the game needs, with counts, pixel sizes, formats and export
settings. Hand this to an artist and they can work without asking you questions.

---

## 1. Art direction baseline

| Item | Decision |
|---|---|
| Style | flat vector-ish with soft inner shadow and one specular highlight |
| Palette | 6 bubble colours + 3 UI accents + 4 neutrals (define in one `palette.json`) |
| Outline | 2 px darker rim on bubbles only, none on UI |
| Light direction | top-left, consistent across every sprite |
| Colour space | sRGB, no colour profile embedded |
| Alpha | premultiplied off (straight alpha); export with alpha, no white matte |
| Reference canvas | 1080 × 1920 (design at 2× = 2160 × 3840, export at 1080) |

---

## 2. Bubble set

Six colours × four states. Bubble diameter at 1080 width: **d = 96 px** (board of 11 columns).

| Asset | Count | Size | Notes |
|---|---|---|---|
| `bubble_<colour>_idle` | 6 | 96 × 96 | base sphere, highlight top-left |
| `bubble_<colour>_pop` | 6 | 128 × 128 | 8-frame sequence in the atlas, 0.18 s |
| `bubble_<colour>_shine` | 6 | 96 × 96 | optional overlay for special bubbles |
| `bubble_ghost` | 1 | 96 × 96 | 40 % alpha preview of the landing cell |
| `bubble_aim_dot` | 1 | 16 × 16 | dashes for the trajectory line |

Colours: red `#E8453C`, blue `#2D9CDB`, green `#27AE60`, yellow `#F2C94C`, purple `#9B51E0`, orange `#F2994A`.
Six is the maximum you can tell apart at 96 px on a cheap screen with the brightness down. Test that before
you add a seventh.

---

## 3. Blockers

| Asset | Count | Size | Notes |
|---|---|---|---|
| `blocker_ice_01/02/03` | 3 | 96 × 96 | one per hit point remaining; crack lines grow |
| `blocker_stone` | 1 | 96 × 96 | matte, no highlight — must read as "not poppable" |
| `blocker_chain` | 1 | 112 × 112 | overlay on top of a bubble |
| `blocker_cage` | 1 | 112 × 112 | alternative to chain, pick one |
| `fx_ice_break` | 1 | 160 × 160 | 6-frame sequence |

A blocker must be readable at a glance in under 200 ms. If a player has to think about whether a bubble is
poppable, the sprite has failed.

---

## 4. Cannon and launcher

| Asset | Count | Size | Notes |
|---|---|---|---|
| `cannon_base` | 1 | 220 × 180 | static, sits at the bottom centre |
| `cannon_barrel` | 1 | 120 × 200 | pivot at the bottom centre, rotate this only |
| `cannon_ring` | 1 | 240 × 240 | optional glow ring |
| `bubble_slot_current` | 1 | 120 × 120 | frame around the loaded bubble |
| `bubble_slot_next` | 1 | 96 × 96 | smaller, beside it |
| `ui_btn_swap` | 2 | 88 × 88 | normal + pressed |

Pivot discipline: the barrel's rotation origin must be exactly at the barrel's base centre, or the cannon
"wobbles" as it rotates. Set the pivot in the atlas, not in code.

---

## 5. Boosters

| Asset | Count | Size | Notes |
|---|---|---|---|
| `booster_bomb` | 1 | 128 × 128 | + 2 frames for the throw |
| `booster_rainbow` | 1 | 128 × 128 | animated 4-frame shimmer |
| `booster_laser` | 1 | 128 × 128 | |
| `booster_swap` | 1 | 128 × 128 | |
| `booster_extra_moves` | 1 | 128 × 128 | clock/arrow motif |
| `booster_continue` | 1 | 128 × 128 | heart/refresh motif |
| `booster_slot_empty` | 1 | 132 × 132 | dashed frame |
| `booster_count_badge` | 1 | 56 × 56 | nine-slice-able pill |

Each booster also needs an in-world effect sprite: `fx_bomb_blast` (256 × 256, 8 frames),
`fx_rainbow_sweep` (512 × 256, 6 frames), `fx_laser_beam` (9-slice strip).

---

## 6. UI set

| Group | Assets | Size | Notes |
|---|---|---|---|
| Buttons | `btn_primary`, `btn_secondary`, `btn_icon`, `btn_close` | 9-slice, min 240 × 96 | 3 states each: normal, pressed, disabled |
| Pills | `pill_coins`, `pill_lives`, `pill_level` | 9-slice, h 84 | |
| Icons | `icon_coin`, `icon_heart`, `icon_gem`, `icon_star_on`, `icon_star_off`, `icon_pause`, `icon_settings`, `icon_sound_on/off`, `icon_music_on/off`, `icon_haptic_on/off`, `icon_spin`, `icon_piggy`, `icon_shop`, `icon_gift`, `icon_lock`, `icon_play` | 64 × 64 and 96 × 96 variants | |
| Popups | `popup_frame`, `popup_ribbon`, `popup_scrim` | 9-slice, 1080 × 1200 max | |
| Progress | `progress_bg`, `progress_fill`, `progress_knob` | 9-slice | |
| Map nodes | `map_node_locked`, `map_node_current`, `map_node_done`, `map_node_star` | 128 × 128 | |

Nine-slice everything that stretches. A stretched flat PNG with rounded corners looks cheap instantly.

---

## 7. Particles

One 512 × 512 particle atlas holding: soft dot, star, spark, ring, shard, bubble fragment, coin glint.
Particle systems reference frames from this single atlas — never separate textures per effect, or you will
break batching and lose 10 fps.

---

## 8. Fonts

| Use | Type | Notes |
|---|---|---|
| HUD numbers (coins, lives, score) | bitmap font `.fnt` + page PNG | crisp at every size, no SDF blur |
| Body / popup copy | one licensed `.ttf` | needs Devanagari coverage if you ship Hindi |
| Headings | same `.ttf`, bold weight | avoid a second family — weight is enough |

Devanagari coverage matters for an Indian launch: verify the `.ttf` actually contains the glyphs, and test
`क्ष`, `ज्ञ`, matras and conjuncts on device. Many free Latin-only fonts render Hindi as boxes.

---

## 9. Atlases and budget

| Atlas | Contents | Target size |
|---|---|---|
| `ui` | buttons, pills, icons, popups | 2048 × 2048 |
| `game` | bubbles, blockers, cannon, boosters | 2048 × 2048 |
| `fx` | pop sequences, blast, shatter, particles | 1024 × 1024 |
| `map` | nodes, path, world backgrounds (tiled) | 2048 × 1024 |
| `theme_<n>` | per-world decorations, downloaded on demand | 2048 × 2048 |

Math check: a 2048² atlas is 4.19 M pixels. At 96² per bubble you fit ~450 sprites; the game atlas above is
~90 sprites, so there is room for 4× more content before you need a second sheet.

Texture memory on a mid-range phone: keep total resident textures under **80 MB**. A 2048² RGBA8888 texture
is 16 MB uncompressed — five of those is already your budget, which is why you ship ASTC or ETC2.

---

## 10. Export settings

| Setting | Value |
|---|---|
| Texture compression | ASTC 6×6 (Android 5+), ETC2 fallback for old devices |
| Mipmaps | off for UI and sprites (they cause halos at the edges) |
| Filter | bilinear, no anisotropy |
| Max texture size | 2048 (gate 4096 behind a device check) |
| Atlas padding | 2 px, extrude 2 px (prevents bleeding between frames) |
| Format | PNG-8 with alpha for source, engine handles compression |
| Naming | `category_subject_state_variant`, lowercase, underscores only |

---

## 11. Store listing assets

| Asset | Size | Notes |
|---|---|---|
| App icon | 512 × 512 PNG | must read at 48 px; one bubble, not a scene |
| Adaptive icon | foreground 432 × 432 + background | keep content inside the 66 % safe circle |
| Feature graphic | 1024 × 500 | no text smaller than 40 px |
| Phone screenshots | 1080 × 1920, min 4, max 8 | first one carries 80 % of the decision |
| Tablet screenshots | 1600 × 2560 | required if you declare tablet support |
| Promo video | 1920 × 1080, ≤ 30 s | optional but lifts conversion |

Screenshot order that converts: gameplay in motion → a big combo → the map with progress → a reward moment →
store value. Never lead with a logo or a menu.

---

## 12. Asset credits template

```
| file | author | source | licence | date | notes |
|------|--------|--------|---------|------|-------|
| bubble_red_idle.png | in-house | - | owned | 2026-11-07 | |
| sfx_ui_click.ogg | Kenney | kenney.nl | CC0 | 2026-11-07 | |
```

Every file in the shipped build needs a row. No exceptions — this is the document that decides whether a
takedown or a rejection costs you a week or a business.

---

## 13. Definition of done

- Every asset in §2-§9 exists at the stated size, in the stated atlas, with the stated name.
- Total texture memory ≤ 80 MB resident, verified on a 3 GB RAM device.
- Every asset has a row in `ASSET_CREDITS.md`.
- Icon and screenshots pass the 48 px / 5-second readability test.
- Hindi text renders correctly on device if `hi` is a launch locale.
