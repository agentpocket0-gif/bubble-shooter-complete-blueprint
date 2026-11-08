# 02 · Grid Geometry, Physics and Matching

**Scope:** the algorithms for a staggered bubble grid, written so you can implement them directly.
All constants are yours to tune; the maths is what matters.

---

## 1. Coordinates

A bubble board is a staggered grid: every odd row is shifted half a bubble to the right. Three numbers
define it completely.

- `d` — bubble diameter in pixels (measure the largest bubble sprite; typically `screenWidth / 11`).
- `rowPitch = d * sqrt(3) / 2 ≈ 0.866 * d` — vertical distance between row centres.
- `oddOffset = d / 2` — horizontal shift applied to rows where `row % 2 === 1`.

Centre of the cell at column `q`, row `r`:

```
x(q, r) = originX + q * d + (r % 2) * (d / 2)
y(r)    = originY + r * rowPitch
```

`originX` is normally `d / 2` (so the first bubble's left edge touches the wall), `originY` is the ceiling.

To go the other way (pixel → nearest cell):

```
r = round((y - originY) / rowPitch)
q = round((x - originX - (r % 2) * d / 2) / d)
```

Note that `q` depends on `r`, so round `r` first. Getting this order wrong is the single most common
snapping bug.

### Neighbours

The neighbour set depends on row parity. For cell `(q, r)`:

```
even row (r % 2 == 0)          odd row (r % 2 == 1)
  (q-1, r)   (q+1, r)            (q-1, r)   (q+1, r)
  (q-1, r-1) (q,   r-1)          (q,   r-1) (q+1, r-1)
  (q-1, r+1) (q,   r+1)          (q,   r+1) (q+1, r+1)
```

Always six neighbours, always at distance `d`. If your implementation returns five or seven, the parity
test is inverted.

### Board bounds

Row width alternates: even rows hold `cols` cells, odd rows hold `cols - 1` (or `cols`, if you inset the
board so both fit — the inset variant is easier to render and harder to look wrong, so prefer it).

---

## 2. Board data structure

```ts
type Cell = { color: number | null; hp: number; blocker: number | null };
class Board {
  cols: number; rows: number;
  cells: Cell[];               // length cols * rows, index = r * cols + q
  at(q: number, r: number): Cell | null;   // null when out of bounds
  neighbours(q: number, r: number): [number, number][];
  isFull(q: number, r: number): boolean;
}
```

Flat arrays with an index function beat nested arrays: no allocation during BFS, cache-friendly.

**Important:** the board's `rows` is a maximum. Empty rows at the bottom are legal and normal — the grid
grows downward as bubbles accumulate.

---

## 3. Projectile physics

The cannon sits at `(cannonX, cannonY)` near the bottom. A shot is a point that moves.

```
v = launchSpeed * (sin(angle), -cos(angle))     // angle 0 = straight up
p += v * dt
```

Choose `launchSpeed` so a shot crosses the play area in ~0.45-0.7 s: `launchSpeed ≈ playHeight / 0.55`.
Scale it with `d` (e.g. `28 * d` per second) so the feel is identical on every screen size.

**Substep to prevent tunnelling.** Never integrate with a frame `dt` larger than the time to travel half a
bubble:

```
maxStep = (d * 0.5) / |v|
steps   = ceil(dt / maxStep)
```

At 60 fps and a fast shot this is 2-3 substeps. Skipping this makes fast shots pass through bubbles at low
frame rates — the classic "my bubble went through the wall" bug report.

### Collision test

Two checks per substep:

1. **Bubble hit** — for each occupied cell within `2d` of `p`, if `distance(p, centre) < d * 0.92` → hit.
   The `0.92` factor makes contact feel slightly early rather than late, which players read as responsive.
2. **Ceiling hit** — if `p.y <= originY` → attach to row 0.

### Snapping

On a hit, do **not** snap to the cell nearest the projectile. Snap to the *empty cell adjacent to the bubble
you hit* whose centre is closest to the projectile's position:

```ts
function snapCell(hitQ: number, hitR: number, p: Vec2): [number, number] | null {
  let best: [number, number] | null = null;
  let bestDist = Infinity;
  for (const [q, r] of board.neighbours(hitQ, hitR)) {
    if (!inBounds(q, r) || board.isFull(q, r)) continue;
    const dist = distanceSq(p, centreOf(q, r));
    if (dist < bestDist) { bestDist = dist; best = [q, r]; }
  }
  return best;
}
```

If every neighbour is occupied (rare, deep inside the board), fall back to the nearest empty cell within
`2d` by BFS. If there is none, the board is full → end the level as a loss.

### Wall bounce

```
if (p.x - radius < leftWall)  { p.x = leftWall + radius + (leftWall - (p.x - radius)); v.x = -v.x; }
if (p.x + radius > rightWall) { p.x = rightWall - radius - ((p.x + radius) - rightWall); v.x = -v.x; }
```

Reflect rather than clamp, otherwise the bubble sticks to the wall for a frame and the trajectory preview
disagrees with the real shot.

---

## 4. Aim preview

Run the **same** integrator the real shot uses, without collision resolution, for a fixed number of
substeps, and stop at the first bubble or ceiling contact. Draw a polyline through the sampled positions,
capped at 3 bounces.

Cheap version: analytic ray against two vertical lines, up to 3 reflections. It is faster but drifts from
the real path wherever the collision radius differs. Ship the simulated version; a preview that lies is
worse than no preview.

Add a ghost bubble at the predicted landing cell — it removes almost all mis-aim frustration.

---

## 5. Match detection

Breadth-first search over same-colour neighbours from the landed cell.

```ts
function findCluster(q: number, r: number): [number, number][] {
  const start = board.at(q, r);
  if (!start || start.color === null) return [];
  const target = start.color;
  const seen = new Set<string>([`${q},${r}`]);
  const stack: [number, number][] = [[q, r]];
  const out: [number, number][] = [];
  while (stack.length) {
    const [cq, cr] = stack.pop()!;
    out.push([cq, cr]);
    for (const [nq, nr] of board.neighbours(cq, cr)) {
      const key = `${nq},${nr}`;
      if (seen.has(key)) continue;
      const cell = board.at(nq, nr);
      if (!cell || cell.color !== target) continue;
      seen.add(key);
      stack.push([nq, nr]);
    }
  }
  return out;
}
```

Pop when `cluster.length >= 3`. Then re-run detection from the popped cells' neighbours if you want
cascade behaviour (popping a bubble that was holding a same-colour pair together is satisfying, but it also
makes the board unpredictable — pick one and be consistent).

### Floating clusters

A bubble is anchored if it is connected to row 0 through occupied cells of **any** colour.

```ts
function findFloating(): [number, number][] {
  const anchored = new Set<string>();
  const stack: [number, number][] = [];
  for (let q = 0; q < board.cols; q++) {
    if (board.isFull(q, 0)) { stack.push([q, 0]); anchored.add(`${q},0`); }
  }
  while (stack.length) {
    const [cq, cr] = stack.pop()!;
    for (const [nq, nr] of board.neighbours(cq, cr)) {
      const key = `${nq},${nr}`;
      if (anchored.has(key) || !board.isFull(nq, nr)) continue;
      anchored.add(key);
      stack.push([nq, nr]);
    }
  }
  const floating: [number, number][] = [];
  for (let r = 0; r < board.rows; r++)
    for (let q = 0; q < board.cols; q++)
      if (board.isFull(q, r) && !anchored.has(`${q},${r}`)) floating.push([q, r]);
  return floating;
}
```

Order matters: pop the cluster **first**, remove it from the board, **then** run the floating pass.
Running floating detection before removal makes every popped bubble look disconnected.

### Falling animation

Give each falling bubble its own body: `vy += 2600 * dt`, `rotation += ω * dt`, cull when `y > screenHeight + d`.
Do not animate them as a group — a group fall reads as a texture sliding down, not as physics.

---

## 6. Scoring

```ts
const base = 10;
const clusterScore = base * n * (1 + 0.25 * (n - 3));   // n = cluster size, 3..∞
const dropScore    = 20 * floating.length;
const shotBonus    = 50 * movesLeft;                    // awarded only on win
total = clusterScore + dropScore + shotBonus;
```

Why the `0.25 * (n - 3)` term: without it, four separate 3-pops always beat one 12-pop, which teaches the
player to avoid the fun move. With it, big clusters are worth chasing.

---

## 7. Edge cases that must be handled

| Case | Behaviour |
|---|---|
| Board full, no empty neighbour | level lost, "no space" message |
| Only one bubble left, unmatched | level won when objective is `clear_all` |
| Shot bounces and hits the cannon row | treat cannon row as a hard floor → attach to the lowest free cell |
| Player drags outside the cannon arc | clamp to ±75°, never to the horizontal (a horizontal shot is a wasted shot) |
| App backgrounded mid-shot | resolve the shot on resume, do not replay input |
| Two bubbles land in the same frame | resolve in order of first contact; second shot is invalidated |
| Colour requested but absent from the board | re-roll the queue from colours currently on the board |

That last one is the highest-value fix in the whole system: a shooter that hands you a colour you cannot
possibly use is the most common source of rage-quits.

---

## 8. Determinism

Seed the colour queue with `seed = hash(levelId, attemptIndex)` and store `attemptIndex` in the save. This
gives you reproducible levels for balancing and bug reports, plus a fair "retry" (same sequence) without
the exploit of a fresh random queue per attempt.

---

## 9. Performance targets

- Grid scan and BFS on a 12 × 20 board: well under 0.1 ms — never optimise this further.
- Collision test: only query occupied cells inside the projectile's swept AABB, not the whole board.
- Pool every bubble node, particle and floating body. Allocation during play is the only thing that causes
  GC hitches on low-end Android.
- Particle count cap: 300 live particles; drop the oldest, never the newest.
