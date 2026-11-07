# 09 · Live Ops, ASO and Launch Plan

**Scope:** how the game gets found, gets installed, and keeps its players. Numbers below are realistic
starting points for a casual puzzle game, not promises.

---

## 1. Store listing (ASO)

| Element | Rule | Example |
|---|---|---|
| Title | ≤ 30 chars, keyword first, brand last | `Bubble Pop Blast: Puzzle Game` |
| Short description | ≤ 80 chars, one benefit + one keyword | `Match 3 bubbles, clear the board. 300 free levels, no wifi needed.` |
| Full description | first 3 lines carry the search weight | gameplay verbs first, feature bullets after |
| Icon | one shape, high contrast, readable at 48 px | a single glossy bubble, not a collage |
| Screenshots | first one shows the core action, not a menu | mid-combo with particles |

Keyword approach: pick 5-8 phrases people actually type (`bubble shooter`, `bubble pop`, `match 3 puzzle`,
`offline games`, `free bubble game`), put the strongest in the title and the rest in the short description.
Keyword stuffing in the full description has almost no effect and risks a policy flag.

Localise the listing for Hindi (`hi-IN`) if you launch in India — it changes install rate materially in
tier-2 and tier-3 cities. Titles and short descriptions only; full description translation is lower value.

---

## 2. Soft launch gates

Launch in one small English-speaking market first (New Zealand, Philippines, or a single Indian state's
ad-targeted campaign), then decide with data.

| KPI | Minimum to scale | Good | Action if below minimum |
|---|---|---|---|
| D1 retention | 38 % | 45 %+ | fix the first session: tutorial, first 3 levels, no ads |
| D7 retention | 16 % | 22 %+ | fix the mid-game: level curve, boosters, daily loop |
| D30 retention | 6 % | 9 %+ | add live ops: events, streaks, new content cadence |
| Session length | 6 min | 9 min+ | check load times and ad density |
| Sessions/day | 2.4 | 3.2+ | lives timer tuning, daily quests |
| ARPDAU | ₹0.8 | ₹1.5+ | ad placement and IAP ladder |
| Crash-free sessions | 99.5 % | 99.9 % | stop everything and fix |
| CPI (paid) | ≤ ₹12 | ≤ ₹8 | creative, targeting, or do not buy traffic |

Do not scale spend until D1 and D7 are above the minimum. Buying traffic for a game with 25 % D1 retention is
how studios die quietly.

---

## 3. Content cadence

| Cadence | Deliverable |
|---|---|
| Weekly | 10 new levels, one balance fix, one bug fix |
| Bi-weekly | limited-time event (reskinned 15-level set, themed reward track) |
| Monthly | new world theme (downloadable asset pack), one new mechanic |
| Quarterly | seasonal event, store refresh, new booster if the data supports it |

A level editor and a content pipeline that can ship 10 levels a week without an engineer is worth more than
any single feature. Build it in month one.

---

## 4. Remote config

Ship the ability to change these without an update:

```
interstitial_min_gap_seconds     90
interstitial_daily_cap           8
interstitial_after_levels        3
rewarded_enabled                 true
offer_extra_moves_price          150
lives_max                        5
lives_refill_minutes             30
event_active                     false
event_id                         ""
force_update_version             ""
maintenance_mode                 false
```

Rules: every remote value needs a safe default compiled into the build, because config fetch fails in
airplane mode and on first launch. A remote config that can empty the store is a self-inflicted outage.

---

## 5. Live ops calendar (first quarter)

| Week | Event | Mechanic | Reward |
|---|---|---|---|
| 2 | Daily quests on | 3 quests/day | coins |
| 4 | First weekend event | double coins on weekends | coins |
| 6 | Spin wheel streak | 7-day login streak | booster bundle |
| 8 | Themed event 1 | 15 levels, autumn palette | exclusive bubble skin |
| 10 | Piggy bank live | passive fill | discounted unlock |
| 12 | Themed event 2 | 15 levels, festival palette | exclusive cannon skin |
| 13 | Season pass pilot | free + paid track | cosmetics only |

Cosmetics, not power, in anything time-limited. Selling power in a time-limited event is the fastest way to
make a returning player feel punished for having a life.

---

## 6. Update and rollback

- Staged rollout 10 % → 50 % → 100 %, minimum 48 h per step.
- Watch crash rate and D1 retention per stage; roll back by halting the rollout (Play Console → Release →
  Halt), which is instant and does not require a new build.
- Keep a `kill_switch` remote flag for every new mechanic. Ship the switch with the feature, always.

---

## 7. Community and support

- One support email, answered within 48 h. Most tickets are "I lost my progress" — which is why account
  linking (Play Games Services or a simple email magic link) is a launch feature, not a v2 feature.
- A public changelog in the store description's last paragraph. Players who read it are your best retention.
- Never argue publicly with a one-star review. Fix the bug, reply once, move on.

---

## 8. Definition of done

- Listing assets in all launch locales, keyword-checked.
- Soft launch running with all eight KPIs dashboarded.
- Remote config live with compiled-in defaults.
- Rollback rehearsed once (halt a staged rollout on purpose, in a closed track).
- Content pipeline can ship 10 levels without a code change.
