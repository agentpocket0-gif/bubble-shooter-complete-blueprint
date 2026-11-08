# 04 · Economy, Store, Billing and Ad Mediation

**Scope:** your own numbers and your own product IDs. Prices, coin amounts and ad caps are design decisions;
the reference build's values are not readable statically and are not reproduced here.

---

## 1. Currencies and their job

| Currency | Source | Sink | Why it exists |
|---|---|---|---|
| **Coins** (soft) | level rewards, daily spin, ads | boosters, extra moves, continues | the everyday loop; must never feel scarce in week 1 |
| **Gems** (hard, optional) | IAP only | skip level, premium boosters | convert impatience into revenue |
| **Lives** | regen over time, ads, IAP | starting a level | creates session boundaries |

One rule: **two currencies maximum.** Three is a spreadsheet, not a game. If you add gems later you must
re-tune every price, which is a v2 problem.

---

## 2. Lives

```
maxLives        = 5
refillMinutes   = 30
refillOnStart   = true      // start the timer when a life is spent, not when it hits zero
```

Refill *per life* (one life every 30 minutes, queue keeps filling while you play) rather than *all lives at
once*. It is more generous in feel and produces more return sessions.

Always show the countdown on the HUD. A hidden timer is a lost return visit.

---

## 3. Booster design and pricing

| Booster | Effect | Coin cost | Notes |
|---|---|---|---|
| Extra moves +5 | +5 shots | 150 | the workhorse; buy from the fail popup |
| Bomb | destroys a 3×3 area around impact | 300 | strongest; cap at 1 per level |
| Rainbow | becomes the colour of the next bubble it touches, then pops all of it | 350 | most skill-expressive |
| Aim laser | shows the exact landing cell for one shot | 80 | cheap, high perceived value |
| Swap | swaps current and next bubble | 60 | fixes the "wrong colour" rage |
| Continue | keeps the board, +3 shots, after a loss | 250 | only offered on a loss, once per level |

**Starting inventory:** give 3 extra-moves and 1 bomb free in the tutorial. A player who has never used a
booster never buys one.

**Price ladder:** keep every booster under 400 coins and make a level reward ~40-60 coins. That is roughly
7-10 levels per booster — enough friction to consider a purchase, not enough to feel blocked.

---

## 4. Store SKUs

Naming convention: `<app>.<category>.<tier>`. Product IDs are permanent — a typo is a support ticket forever.

| SKU | Type | Contents | Suggested price (INR) |
|---|---|---|---|
| `bs.coins.small` | consumable | 500 coins | ₹29 |
| `bs.coins.medium` | consumable | 1,500 coins (+10 %) | ₹79 |
| `bs.coins.large` | consumable | 4,000 coins (+25 %) | ₹199 |
| `bs.coins.mega` | consumable | 10,000 coins (+40 %) | ₹499 |
| `bs.starter.pack` | one-time | 2,000 coins + 5 bombs + 5 rainbows | ₹99 |
| `bs.noads` | non-consumable | removes forced interstitials (rewarded stays opt-in) | ₹149 |
| `bs.vip.monthly` | subscription | 30 coins/day, +2 max lives, no interstitials | ₹199 / month |
| `bs.gems.small` | consumable | 20 gems | ₹79 |

Localise price tiers per market in Play Console rather than hard-coding conversions; ₹29 / ₹79 / ₹199 / ₹499
maps cleanly onto the standard tier grid.

### Implementation checklist

1. Google Play Billing Library 7.x, `BillingClient` with `enablePendingPurchases()`.
2. Query products on store open; **never** hard-code prices — read them from the product details.
3. On purchase: verify the `purchaseToken` **server-side** against the Play Developer API before granting.
   Client-only granting is the most exploited hole in mobile games.
4. Acknowledge every consumable within 3 days or it is auto-refunded. Consume + acknowledge in one call.
5. Handle `PENDING` purchases (cash payments) — grant on `onPurchasesUpdated` later, not immediately.
6. Restore non-consumables and subscriptions on every fresh install.
7. Subscriptions: handle `SUBSCRIPTION_EXPIRED`, `ON_HOLD`, `GRACE_PERIOD`. Grace period = keep benefits.
8. Test with licence-test accounts and the Play internal testing track, not with real money.

---

## 5. Ads

### One mediation SDK, not five

Pick **AppLovin MAX** or **ironSource/LevelPlay** as the single mediation layer and let it fill through
adapters. Integrating two mediators yourself doubles your init cost and splits your eCPM data.

Waterfall of networks to enable at launch (in order of typical fill for casual games): the mediator's own
network, Google AdMob, Meta Audience Network, Unity Ads, Mintegral, Vungle/Liftoff, InMobi, Pangle.

### Placements

| Placement | Format | Trigger | Cap |
|---|---|---|---|
| Extra moves | rewarded | fail popup, player taps "watch for +5 moves" | unlimited (opt-in) |
| Double level reward | rewarded | result screen, after first clear | 1 / level |
| Free booster | rewarded | store, once per booster per day | 3 / day |
| Extra life | rewarded | lives empty | 5 / day |
| Spin again | rewarded | daily spin, after the free spin | 2 / day |
| Interstitial | interstitial | after level fail, and after level win every 3rd level | max 1 / 90 s, max 8 / day |
| App open | app open | cold start, not first session, not within 4 h of an interstitial | 1 / session |

Rules that protect retention:

- **No interstitial in the first session.** The first session must be pure game.
- **Never interrupt a win streak.** Interstitials after a win feel like punishment; after a fail they feel
  like a fair trade.
- **Never show an interstitial within 30 s of a rewarded ad** — the player just paid attention, do not
  charge them again.
- Always offer the rewarded alternative before the interstitial on a fail screen.

### Consent and privacy (this is not optional)

- **EEA/UK:** Google UMP (User Messaging Platform) SDK, obtain consent before any ad request, respect
  `canRequestAds`. Serve non-personalised ads without consent.
- **India:** the DPDP Act 2023 applies to personal data you collect. Keep a plain-language privacy policy,
  collect the minimum, and provide a deletion route. Do not ship device identifiers to ad networks without
  disclosure.
- **Children:** if the app targets or appeals to under-13s, Play's Families policy requires a certified ad
  SDK, no personalised ads, and no interest-based targeting. Design for it or age-gate explicitly.
- **iOS (if you ship it):** ATT prompt before IDFA access; ads must work with ATT denied.
- Use **test ad unit IDs** during development. Never copy a production unit ID from anywhere.

### Ad economics sanity check

```
ARPDAU ≈ (DAU with ads / DAU) × impressions per DAU × eCPM / 1000
```

At 2.2 impressions per DAU and a blended eCPM of ₹180, ads contribute about ₹0.40 per DAU per day. If your
CPI is ₹8 and D7 retention is 20 %, ads alone will not pay for acquisition — IAP has to carry it, or the
creative has to be organic. Do this arithmetic before you buy traffic.

---

## 6. Retention loops (cheap, high value)

| Loop | Cadence | Design |
|---|---|---|
| Daily spin | 24 h | wheel with weighted prizes, free spin, rewarded re-spins, 7-day streak bonus |
| Daily quests | daily | 3 quests: pop N bubbles, clear N levels, use a booster — each pays coins |
| Piggy bank | passive | every level fills it by 10 coins; unlock at a fixed price; caps at the price value |
| Login streak | 7 days | day 7 = a booster bundle, not just coins |
| Limited event | 2 weeks | reskinned level set with a themed reward track |

Every one of these must be skippable. A player who feels managed by timers leaves.

---

## 7. Analytics events (minimum set)

```
app_open, session_start, session_end, level_start, level_win, level_fail,
shot_fired, bubble_popped, booster_used, booster_purchase_clicked,
store_open, product_view, purchase_start, purchase_success, purchase_fail,
ad_request, ad_impression, ad_click, ad_reward, interstitial_shown,
lives_empty, spin_used, tutorial_step, settings_changed
```

Every event carries `level_id`, `world`, `coins_balance`, `session_index`. Without `session_index` you cannot
answer "does session 3 differ from session 1", which is the only retention question that matters.

---

## 8. Definition of done

- Purchase → grant → acknowledge verified end-to-end with a licence-test account.
- No ad shown before the player's first level is complete.
- Consent flow blocks ad requests in EEA until answered.
- Kill the app mid-purchase and the item is still granted on next launch.
- Every SKU and ad placement is listed in one config file, not scattered in code.
