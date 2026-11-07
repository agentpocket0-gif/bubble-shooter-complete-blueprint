# 03 · Level Schema, Generation and Balance

**Scope:** a complete level format you own, a validator, a generator and a difficulty curve.
Nothing here is copied from another game's data files.

---

## 1. Design goals for the format

1. **Human-readable.** A designer must be able to fix a level in a text editor at 2 a.m.
2. **Diff-friendly.** One line per row, so a git diff shows exactly what moved.
3. **Validated at build time.** A malformed level must fail CI, not a player's session.
4. **Extensible.** New objective types and blocker types without a schema migration.

---

## 2. Format

```json
{
  "id": 17,
  "world": 2,
  "name": "Ice Shelf",
  "grid": { "cols": 11, "rows": 14, "seed": 20261107 },
  "shots": 28,
  "palette": ["red", "blue", "green", "yellow", "purple"],
  "layout": [
    "..1122334..",
    ".112233445.",
    "11223344556",
    "..6..7..6.."
  ],
  "blockers": [
    { "row": 2, "col": 3, "type": "ice", "hp": 2 },
    { "row": 3, "col": 5, "type": "stone", "hp": 0 }
  ],
  "objectives": [
    { "type": "clear_all" }
  ],
  "stars": { "1": 4000, "2": 6500, "3": 9000 },
  "rewards": { "coins": 40, "firstClearBonus": 100 },
  "notes": "Introduces ice. Teach with 2 layers, never 3 on a first appearance."
}
```

### Field rules

| Field | Type | Rule |
|---|---|---|
| `id` | int | unique, stable forever — never renumber after release |
| `world` | int | groups levels into map regions |
| `grid.cols` | int | 9-13; above 13 the board is unreadable on a phone |
| `grid.rows` | int | the *maximum* board height, 10-20 |
| `grid.seed` | int | seeds the colour queue for reproducible runs |
| `shots` | int | hard move limit; 0 means unlimited (avoid, it kills tension) |
| `palette` | string[] | colours that may appear this level; 3-6 is the sweet spot |
| `layout` | string[] | one string per row; `.` = empty, `1`-`6` = palette index + 1, letters reserved for blockers |
| `blockers` | object[] | explicit per-cell blocker overrides with hit points |
| `objectives` | object[] | see §3 |
| `stars` | object | three ascending score thresholds |
| `rewards` | object | coins granted on completion |

### Layout characters

```
.   empty
1-6 palette index (1-based, so `1` = palette[0])
x   stone, indestructible (hp 0)
i   ice, hp from blockers[] entry (default 1)
c   chained bubble (colour from palette, needs an adjacent pop)
```

Keeping blockers in a separate array as well as inline characters is deliberate redundancy: inline is fast to
author, the array carries hit points and is what the validator trusts.

---

## 3. Objective types

| Type | Payload | Win condition |
|---|---|---|
| `clear_all` | — | no coloured bubbles left |
| `clear_color` | `{ "color": "red" }` | zero bubbles of that colour |
| `pop_count` | `{ "count": 120 }` | total bubbles popped ≥ count |
| `rescue` | `{ "count": 6 }` | free N chained/caged bubbles |
| `score` | `{ "target": 12000 }` | score ≥ target |
| `survive` | `{ "shots": 40 }` | play all shots without filling the board |

Multiple objectives are AND-ed. Ship at most two per level until players are fluent.

---

## 4. Validator (run in CI)

```python
def validate(level: dict, rules: dict) -> list[str]:
    errs = []
    cols, rows = level["grid"]["cols"], level["grid"]["rows"]
    if not 9 <= cols <= 13:
        errs.append(f"id {level['id']}: cols {cols} outside 9-13")
    if len(level["layout"]) > rows:
        errs.append(f"id {level['id']}: layout has more rows than grid.rows")
    for r, line in enumerate(level["layout"]):
        if len(line) > cols:
            errs.append(f"id {level['id']}: row {r} has {len(line)} chars > {cols}")
    # a level must be solvable from the first shot: at least one colour must
    # appear 3+ times, or the first shot can never pop anything
    from collections import Counter
    counts = Counter(ch for line in level["layout"] for ch in line if ch.isdigit())
    if counts and max(counts.values()) < 3:
        errs.append(f"id {level['id']}: no colour appears 3+ times at start")
    if any(int(ch) > len(level["palette"]) for ch in counts):
        errs.append(f"id {level['id']}: layout uses a palette index out of range")
    s = level["stars"]
    if not (s["1"] < s["2"] < s["3"]):
        errs.append(f"id {level['id']}: star thresholds not ascending")
    if level["shots"] < 5:
        errs.append(f"id {level['id']}: fewer than 5 shots is not a level")
    return errs
```

Add a *playability* check that matters more than any of the above: simulate the level with the level's own
seed and confirm a greedy solver can clear it within `shots * 1.15`. A greedy solver is 40 lines —
repeatedly take the shot that produces the largest immediate cluster. If greedy cannot get close, a human
cannot either.

---

## 5. Difficulty curve

Difficulty is a product of four independent dials. Move **one** dial per level.

| Dial | Easy | Hard |
|---|---|---|
| Colour count | 3 | 6 |
| Shots vs. bubbles ratio | 2.0 | 1.1 |
| Blocker density | 0 % | 35 % |
| Ceiling drop | never | every 6 shots |

Recommended schedule for the first 100 levels:

| Levels | Colours | Shots ratio | Blockers | Ceiling drop | Purpose |
|---|---|---|---|---|---|
| 1-5 | 3 | 2.0 | none | no | teach aim, match, swap |
| 6-12 | 3-4 | 1.8 | none | no | teach star chasing |
| 13-25 | 4 | 1.6 | ice (1 hp) | no | teach blockers |
| 26-40 | 4-5 | 1.5 | ice + stone | no | teach routing around obstacles |
| 41-60 | 5 | 1.4 | mixed | every 8 | introduce pressure |
| 61-85 | 5-6 | 1.25 | mixed | every 6 | mastery |
| 86-100 | 6 | 1.15 | dense | every 5 | endgame |

Insert a **breather** every 8-10 levels: one level with the previous world's easiest settings. Players who
hit a wall of four hard levels in a row churn.

---

## 6. Star thresholds

Derive, do not guess. For each level, compute the score of a perfect-ish run with the greedy solver, call it
`S_greedy`, then:

```
stars1 = round(0.55 * S_greedy / 500) * 500
stars2 = round(0.75 * S_greedy / 500) * 500
stars3 = round(0.95 * S_greedy / 500) * 500
```

This gives a curve where the first star is nearly guaranteed for a competent player (good for retention),
the second needs a decent plan, and the third needs efficiency. Recompute whenever the scoring formula or
the level changes — thresholds that were right for one formula are wrong for the next.

---

## 7. Generation

Hand-author the first 30 levels: they teach the game and must be perfect. Generate the rest.

Generator outline:

1. Pick a target silhouette (full rows, arch, checker, diamond, twin towers) — silhouette variety is what
   makes levels *look* different.
2. Fill with colours so that no colour exceeds 30 % of the board and every colour appears at least 3 times.
3. Place blockers on the silhouette edges, never in the interior of a shape that must be cleared from below.
4. Set `shots = ceil(colouredBubbles / 3.2) + 4` as a first guess.
5. Run the greedy solver; adjust `shots` until greedy finishes with 2-6 shots to spare.
6. Compute star thresholds from the greedy score.
7. Human review pass — 10 seconds per level, reject anything that looks like the last one.

Reject conditions for the generator: more than 6 colours, a starting board where a single colour is
unreachable, or any layout where the top row is entirely empty (the board floats).

---

## 8. Content budget

At 100 levels with an average of 60 bubbles each, your level data is ~120 KB of JSON. Ship it as one file
per world, loaded on demand, and keep a `levels/index.json` with `{id, world, file}` so the map screen can
render without loading gameplay data.

---

## 9. Definition of done

- `npm run validate:levels` passes for all levels in CI.
- Every level is solvable by the greedy solver with ≥ 1 shot spare.
- No level reuses another's silhouette within the same world.
- A designer can add a level and see it in-game without a code change.
