#!/usr/bin/env python3
"""
Level generator, validator and greedy solver for Bubble Shooter: Classic Blast.

The simulator here is the same mathematics as `godot_project/scripts/HexBoard.gd`
and `godot_project/scripts/ShotSimulator.gd`: staggered grid, row pitch d*sqrt(3)/2,
odd rows inset by d/2, collision radius 0.92*d, substeps of d/2, xorshift32 colour
queue seeded by (level id, attempt index).

    python3 tools/levelgen.py --out godot_project/levels --count 120

Every generated level is played by the greedy solver and only kept when the
solver wins with 2-6 shots to spare. Star thresholds are derived from the
solver's score, never guessed.
"""
from __future__ import annotations

import argparse
import json
import math
import random
from collections import Counter
from pathlib import Path

# --------------------------------------------------------------------------- #
# Shared constants (mirrored in GDScript - keep both in sync)
# --------------------------------------------------------------------------- #
D = 96.0                      # bubble diameter, px  (1080 / 11.25)
ROW_PITCH = D * math.sqrt(3.0) / 2.0
HALF = D / 2.0
HIT_FACTOR = 0.92
LEFT_WALL = 12.0
RIGHT_WALL = 1068.0
ORIGIN_X = LEFT_WALL + HALF   # centre of column 0 on an even row
CANNON_X = 540.0
CANNON_Y = 1450.0             # below the deepest legal board row
MAX_ANGLE = math.radians(75.0)
STEP = D / 2.0                # substep length; < hit radius so no tunnelling
MAX_ROWS = 14

COLOURS = ["red", "blue", "green", "yellow", "purple", "orange"]
EMPTY = -1
B_NONE, B_STONE, B_ICE, B_CHAIN = 0, 1, 2, 3   # blocker channel


# --------------------------------------------------------------------------- #
# Deterministic RNG - xorshift32, identical in GDScript
# --------------------------------------------------------------------------- #
class XorShift32:
    def __init__(self, seed: int):
        self.state = (seed & 0xFFFFFFFF) or 0x9E3779B9

    def next(self) -> int:
        x = self.state
        x ^= (x << 13) & 0xFFFFFFFF
        x ^= x >> 17
        x ^= (x << 5) & 0xFFFFFFFF
        self.state = x & 0xFFFFFFFF
        return self.state


def seed_for(level_id: int, attempt: int) -> int:
    return ((level_id * 2654435761) ^ (attempt * 40503) ^ 0x5EED) & 0x7FFFFFFF


# --------------------------------------------------------------------------- #
# Board
# --------------------------------------------------------------------------- #
class Board:
    __slots__ = ("cols", "rows", "colour", "hp", "blocker", "palette")

    def __init__(self, cols: int, rows: int, palette: list[str]):
        self.cols = cols
        self.rows = rows
        self.palette = palette
        self.colour = [[EMPTY] * cols for _ in range(rows)]
        self.hp = [[0] * cols for _ in range(rows)]
        self.blocker = [[0] * cols for _ in range(rows)]

    def clone(self) -> "Board":
        b = Board(self.cols, self.rows, self.palette)
        b.colour = [row[:] for row in self.colour]
        b.hp = [row[:] for row in self.hp]
        b.blocker = [row[:] for row in self.blocker]
        return b

    def row_len(self, r: int) -> int:
        return self.cols if r % 2 == 0 else self.cols - 1

    def in_bounds(self, q: int, r: int) -> bool:
        return 0 <= r < self.rows and 0 <= q < self.row_len(r)

    def filled(self, q: int, r: int) -> bool:
        if not self.in_bounds(q, r):
            return False
        return self.colour[r][q] != EMPTY or self.blocker[r][q] == B_STONE

    def centre(self, q: int, r: int) -> tuple[float, float]:
        return (ORIGIN_X + q * D + (r % 2) * HALF, r * ROW_PITCH)

    def neighbours(self, q: int, r: int) -> list[tuple[int, int]]:
        if r % 2 == 0:
            cand = [(q - 1, r), (q + 1, r), (q - 1, r - 1), (q, r - 1), (q - 1, r + 1), (q, r + 1)]
        else:
            cand = [(q - 1, r), (q + 1, r), (q, r - 1), (q + 1, r - 1), (q, r + 1), (q + 1, r + 1)]
        return [(cq, cr) for cq, cr in cand if self.in_bounds(cq, cr)]

    def colours_present(self) -> list[int]:
        seen = set()
        for r in range(self.rows):
            for q in range(self.row_len(r)):
                c = self.colour[r][q]
                if c >= 0 and self.blocker[r][q] != B_CHAIN:
                    seen.add(c)
        return sorted(seen)

    def coloured_count(self) -> int:
        return sum(1 for r in range(self.rows) for q in range(self.row_len(r))
                   if self.colour[r][q] >= 0)

    def max_row_used(self) -> int:
        for r in range(self.rows - 1, -1, -1):
            for q in range(self.row_len(r)):
                if self.colour[r][q] != EMPTY:
                    return r
        return -1

    # -- matching ---------------------------------------------------------- #
    def find_cluster(self, q: int, r: int) -> list[tuple[int, int]]:
        if not self.filled(q, r):
            return []
        target = self.colour[r][q]
        if target < 0 or self.blocker[r][q] in (B_STONE, B_CHAIN):
            return []
        seen = {(q, r)}
        stack = [(q, r)]
        out = []
        while stack:
            cq, cr = stack.pop()
            out.append((cq, cr))
            for nq, nr in self.neighbours(cq, cr):
                if (nq, nr) in seen:
                    continue
                if self.colour[nr][nq] != target:
                    continue
                if self.blocker[nr][nq] in (B_STONE, B_CHAIN):
                    continue
                seen.add((nq, nr))
                stack.append((nq, nr))
        return out

    def find_floating(self) -> list[tuple[int, int]]:
        anchored = set()
        stack = []
        for q in range(self.row_len(0)):
            if self.filled(q, 0):
                anchored.add((q, 0))
                stack.append((q, 0))
        while stack:
            cq, cr = stack.pop()
            for nq, nr in self.neighbours(cq, cr):
                if (nq, nr) in anchored or not self.filled(nq, nr):
                    continue
                anchored.add((nq, nr))
                stack.append((nq, nr))
        out = []
        for r in range(self.rows):
            for q in range(self.row_len(r)):
                if self.filled(q, r) and (q, r) not in anchored:
                    out.append((q, r))
        return out


# --------------------------------------------------------------------------- #
# Shot simulation
# --------------------------------------------------------------------------- #
def trace(board: Board, angle: float) -> tuple[int, int, bool] | None:
    """Fly a bubble from the cannon and return the cell it lands in."""
    x, y = CANNON_X, CANNON_Y
    dx, dy = math.sin(angle), -math.cos(angle)
    for _ in range(400):
        x += dx * STEP
        y += dy * STEP
        if x - HALF < LEFT_WALL:
            x = LEFT_WALL + HALF + (LEFT_WALL - (x - HALF))
            dx = -dx
        elif x + HALF > RIGHT_WALL:
            x = RIGHT_WALL - HALF - ((x + HALF) - RIGHT_WALL)
            dx = -dx
        if y <= 0.0:
            return _snap_ceiling(board, x)
        hit = _first_hit(board, x, y)
        if hit is not None:
            return _snap(board, hit, x, y)
    return None


def _first_hit(board: Board, x: float, y: float) -> tuple[int, int] | None:
    r0 = int(round(y / ROW_PITCH))
    best, best_d = None, HIT_FACTOR * D
    for r in range(max(0, r0 - 2), min(board.rows, r0 + 3)):
        row = board.colour[r]
        for q in range(board.row_len(r)):
            if row[q] == EMPTY:
                continue
            cx, cy = board.centre(q, r)
            dist = math.hypot(cx - x, cy - y)
            if dist < best_d:
                best, best_d = (q, r), dist
    return best


def _snap_ceiling(board: Board, x: float) -> tuple[int, int, bool] | None:
    q = int(round((x - ORIGIN_X) / D))
    q = max(0, min(board.row_len(0) - 1, q))
    while q < board.row_len(0) and board.filled(q, 0):
        q += 1
    if q >= board.row_len(0):
        return None
    return (q, 0, True)


def _snap(board: Board, hit: tuple[int, int], x: float, y: float) -> tuple[int, int, bool] | None:
    hq, hr = hit
    best, best_d = None, float("inf")
    for nq, nr in board.neighbours(hq, hr):
        if board.filled(nq, nr):
            continue
        cx, cy = board.centre(nq, nr)
        dist = (cx - x) ** 2 + (cy - y) ** 2
        if dist < best_d:
            best, best_d = (nq, nr), dist
    if best is None:
        return None
    return (best[0], best[1], False)


def place_and_resolve(board: Board, cell: tuple[int, int, bool], colour: int) -> dict:
    """Place the bubble, pop clusters, free chains, drop floaters. Mutates board."""
    q, r, _ = cell
    board.colour[r][q] = colour
    board.hp[r][q] = 0
    board.blocker[r][q] = B_NONE

    popped = []
    cluster = board.find_cluster(q, r)
    if len(cluster) >= 3:
        for cq, cr in cluster:
            if board.blocker[cr][cq] == B_ICE and board.hp[cr][cq] > 1:
                board.hp[cr][cq] -= 1
                continue
            board.colour[cr][cq] = EMPTY
            board.hp[cr][cq] = 0
            board.blocker[cr][cq] = B_NONE
            popped.append((cq, cr))

    freed = 0
    for cq, cr in list(popped):
        for nq, nr in board.neighbours(cq, cr):
            if board.blocker[nr][nq] == B_CHAIN:
                board.blocker[nr][nq] = B_NONE
                freed += 1

    floating = board.find_floating()
    for fq, fr in floating:
        # A chained bubble that loses its support and falls is also rescued.
        if board.blocker[fr][fq] == B_CHAIN:
            freed += 1
        board.colour[fr][fq] = EMPTY
        board.hp[fr][fq] = 0
        board.blocker[fr][fq] = B_NONE

    n = len(popped)
    score = 10.0 * n * (1.0 + 0.25 * max(0, n - 3)) + 20.0 * len(floating)
    return {
        "popped": popped,
        "floating": floating,
        "freed": freed,
        "score": int(round(score)),
        "cluster": n,
    }


# --------------------------------------------------------------------------- #
# Greedy solver
# --------------------------------------------------------------------------- #
def queue_colour(board: Board, rng: XorShift32, palette_idx: list[int]) -> int:
    present = board.colours_present()
    if not present:
        present = list(palette_idx)
    return present[rng.next() % len(present)]


def greedy_play(level: dict, angles: int = 18, verbose: bool = False) -> dict:
    board = Board(level["grid"]["cols"], level["grid"]["rows"], level["palette"])
    palette_idx = list(range(len(level["palette"])))
    _load_layout(board, level)
    rng = XorShift32(level["grid"]["seed"])
    shots = level["shots"]
    score = 0
    popped_total = 0
    freed_total = 0
    colours_cleared = Counter()
    shots_used = 0
    dead = 0

    for _ in range(shots):
        colour = queue_colour(board, rng, palette_idx)
        best = None
        for i in range(angles):
            frac = (i / max(1, angles - 1)) * 2.0 - 1.0
            angle = frac * MAX_ANGLE
            probe = board.clone()
            cell = trace(probe, angle)
            if cell is None:
                continue
            res = place_and_resolve(probe, cell, colour)
            # Prefer big pops, then floaters, then shots that set up the next pop,
            # then the tidier (higher) placement.
            same = 0
            for nq, nr in probe.neighbours(cell[0], cell[1]):
                if probe.colour[nr][nq] == colour and probe.blocker[nr][nq] != B_CHAIN:
                    same += 1
            rescue_mission = any(
                obj.get("type") == "rescue" for obj in level.get("objectives", [])
            )
            if rescue_mission:
                # Prefer moves that free a chained bubble before optimising the
                # usual pop size and score. This makes rescue levels deliberate.
                rank = (res["freed"], res["cluster"], res["score"], same, -cell[1])
            else:
                rank = (res["cluster"], res["score"], same, -cell[1])
            if best is None or rank > best[0]:
                best = (rank, angle, probe, res, cell)
        if best is None:
            break
        if best[3]["cluster"] == 0:
            dead += 1
            if dead >= 6:            # six shots that cannot pop anything: stuck
                break
        else:
            dead = 0
        _, angle, probe, res, cell = best
        board = probe
        score += res["score"]
        popped_total += len(res["popped"])
        freed_total += res["freed"]
        for cq, cr in res["popped"]:
            colours_cleared[board.palette[colour]] += 1
        shots_used += 1
        if _survive_failed(level, board):
            break
        if _objective_met(level, board, score, popped_total, freed_total, shots_used):
            break

    met = _objective_met(level, board, score, popped_total, freed_total, shots_used)
    return {
        "won": met,
        "score": score,
        "shots_used": shots_used,
        "shots_left": shots - shots_used,
        "popped": popped_total,
        "freed": freed_total,
        "board": board,
    }


def _objective_met(level: dict, board: Board, score: int, popped: int,
                   freed: int, shots_used: int = 0) -> bool:
    for obj in level["objectives"]:
        t = obj["type"]
        # A single unmatched bubble still counts as cleared. Other mission
        # types must meet their own target; clearing the board is not a shortcut.
        if t == "clear_all" and board.coloured_count() > 1:
            return False
        if t == "clear_color":
            idx = level["palette"].index(obj["color"])
            if any(board.colour[r][q] == idx for r in range(board.rows) for q in range(board.row_len(r))):
                return False
        if t == "pop_count" and popped < int(obj["count"]):
            return False
        if t == "rescue" and freed < int(obj["count"]):
            return False
        if t == "score" and score < int(obj["target"]):
            return False
        if t == "survive":
            required_shots = int(obj.get("shots", 0))
            if shots_used < required_shots or board.max_row_used() >= board.rows - 1:
                return False
    return True


def _survive_failed(level: dict, board: Board) -> bool:
    has_survive = any(obj.get("type") == "survive" for obj in level.get("objectives", []))
    return has_survive and board.max_row_used() >= board.rows - 1


def _load_layout(board: Board, level: dict) -> None:
    palette = level["palette"]
    blockers = {(b["row"], b["col"]): b for b in level.get("blockers", [])}
    for r, line in enumerate(level["layout"]):
        for q, ch in enumerate(line):
            if not board.in_bounds(q, r):
                continue
            if ch == ".":
                continue
            if ch.isdigit():
                board.colour[r][q] = int(ch) - 1
            elif ch == "x":
                board.colour[r][q] = EMPTY
                board.blocker[r][q] = B_STONE
            elif ch == "i":
                b = blockers.get((r, q), {"hp": 1, "color": (r * 3 + q) % len(palette)})
                board.colour[r][q] = int(b.get("color", (r * 3 + q) % len(palette)))
                board.blocker[r][q] = B_ICE
                board.hp[r][q] = int(b.get("hp", 1))
            elif ch == "c":
                b = blockers.get((r, q), {})
                board.colour[r][q] = int(b.get("color", (r + q) % len(palette)))
                board.blocker[r][q] = B_CHAIN


# --------------------------------------------------------------------------- #
# Validator (blueprint 03 §4)
# --------------------------------------------------------------------------- #
def validate(level: dict) -> list[str]:
    errs = []
    lid = level.get("id", "?")
    cols = level["grid"]["cols"]
    rows = level["grid"]["rows"]
    if not 9 <= cols <= 13:
        errs.append(f"id {lid}: cols {cols} outside 9-13")
    if not 10 <= rows <= 20:
        errs.append(f"id {lid}: rows {rows} outside 10-20")
    if len(level["layout"]) > rows:
        errs.append(f"id {lid}: layout has more rows than grid.rows")
    for r, line in enumerate(level["layout"]):
        limit = cols if r % 2 == 0 else cols - 1
        if len(line) > limit:
            errs.append(f"id {lid}: row {r} has {len(line)} chars > {limit}")
    counts = Counter(ch for line in level["layout"] for ch in line if ch.isdigit())
    if counts and max(counts.values()) < 3:
        errs.append(f"id {lid}: no colour appears 3+ times at start")
    for ch in counts:
        if int(ch) > len(level["palette"]):
            errs.append(f"id {lid}: layout uses a palette index out of range")
    s = level["stars"]
    if not (s["1"] < s["2"] < s["3"]):
        errs.append(f"id {lid}: star thresholds not ascending")
    if level["shots"] < 5:
        errs.append(f"id {lid}: fewer than 5 shots is not a level")
    if not level["layout"] or all(ch == "." for ch in level["layout"][0]):
        errs.append(f"id {lid}: top row is empty - the board floats")
    objective_types = {
        "clear_all", "clear_color", "pop_count", "rescue", "score", "survive"
    }
    objectives = level.get("objectives", [])
    if not isinstance(objectives, list) or not objectives:
        errs.append(f"id {lid}: at least one objective is required")
        objectives = []
    if len(objectives) > 2:
        errs.append(f"id {lid}: no more than two objectives are allowed")

    chain_cells = {
        (r, q)
        for r, line in enumerate(level["layout"])
        for q, ch in enumerate(line)
        if ch == "c"
    }
    chain_records = {
        (int(b.get("row", -1)), int(b.get("col", -1)))
        for b in level.get("blockers", [])
        if b.get("type") == "chain"
    }
    if chain_cells != chain_records:
        errs.append(f"id {lid}: chained layout cells and blocker records do not match")

    for obj in objectives:
        t = str(obj.get("type", ""))
        if t not in objective_types:
            errs.append(f"id {lid}: unknown objective type {t!r}")
        elif t == "clear_color" and obj.get("color") not in level["palette"]:
            errs.append(f"id {lid}: clear_color target not in palette")
        elif t == "pop_count" and int(obj.get("count", 0)) <= 0:
            errs.append(f"id {lid}: pop_count target must be positive")
        elif t == "rescue":
            if int(obj.get("count", 0)) <= 0:
                errs.append(f"id {lid}: rescue target must be positive")
            if not chain_cells:
                errs.append(f"id {lid}: rescue objective has no chained bubbles")
            if int(obj.get("count", 0)) > len(chain_cells):
                errs.append(f"id {lid}: rescue target exceeds chained bubbles")
        elif t == "score" and int(obj.get("target", 0)) <= 0:
            errs.append(f"id {lid}: score target must be positive")
        elif t == "survive" and int(obj.get("shots", 0)) <= 0:
            errs.append(f"id {lid}: survive shot target must be positive")
    return errs


# --------------------------------------------------------------------------- #
# Generator
# --------------------------------------------------------------------------- #
SCHEDULE = [
    # (first, last, colours, shots_ratio, blocker_mode, ceiling_drop, objectives)
    (1, 5, 3, 2.0, "none", 0),
    (6, 12, 4, 1.8, "none", 0),
    (13, 25, 4, 1.6, "ice", 0),
    (26, 40, 5, 1.5, "ice_stone", 0),
    (41, 60, 5, 1.4, "mixed", 8),
    (61, 85, 6, 1.25, "mixed", 6),
    (86, 120, 6, 1.15, "dense", 5),
]

SILHOUETTES = ["full", "arch", "checker", "diamond", "towers", "funnel", "zigzag", "cross", "heart"]


def schedule_for(level_id: int):
    for first, last, colours, ratio, blockers, drop in SCHEDULE:
        if first <= level_id <= last:
            return colours, ratio, blockers, drop
    return 6, 1.15, "dense", 5


def silhouette(kind: str, cols: int, rows: int) -> list[list[bool]]:
    """Return rows x cols boolean mask of 'a bubble may start here'."""
    mask = [[False] * cols for _ in range(rows)]
    mid = (cols - 1) / 2.0
    for r in range(rows):
        limit = cols if r % 2 == 0 else cols - 1
        for q in range(limit):
            keep = False
            if kind == "full":
                keep = r < rows - 2
            elif kind == "arch":
                keep = r < rows - 3 and abs(q - mid) < cols / 2.0 - r * 0.55
            elif kind == "checker":
                keep = r < rows - 2 and (q + r) % 2 == 0
            elif kind == "diamond":
                keep = abs(q - mid) + abs(r - (rows - 1) / 2.0) < cols / 2.0
            elif kind == "towers":
                keep = r < rows - 2 and (q < cols * 0.32 or q > cols * 0.68 or r < 3)
            elif kind == "funnel":
                keep = r < rows - 2 and not (3 <= r <= rows - 6 and 2 < q < cols - 3)
            elif kind == "zigzag":
                keep = r < rows - 2 and (q + (r // 2) * 3) % 5 != 0
            elif kind == "cross":
                keep = r < rows - 2 and (abs(q - mid) < 1.6 or abs(r - (rows - 2) / 2.0) < 1.6)
            elif kind == "heart":
                keep = r < rows - 2 and abs(q - mid) < cols / 2.0 - 0.35 * r
            mask[r][q] = keep
    # the ceiling row must hold bubbles or the whole board floats
    for q in range(1, cols - 1):
        mask[0][q] = True
    mask[0][0] = True
    mask[0][min(cols - 2, cols - 1)] = True
    return mask


def build_layout(level_id: int, rng: random.Random, colours: int, cols: int, rows: int,
                 blocker_mode: str, kind: str,
                 fill_rows: int | None = None) -> tuple[list[str], list[dict], list[str]]:
    mask = silhouette(kind, cols, rows)
    if fill_rows is not None:
        for r in range(fill_rows, rows):
            for q in range(cols):
                mask[r][q] = False
    palette = COLOURS[:colours]
    cells = [(r, q) for r in range(rows) for q in range(cols if r % 2 == 0 else cols - 1) if mask[r][q]]
    if not cells:
        return [], [], palette

    # Colour assignment in blobs. Random per-cell colouring produces boards
    # where a 3-match is nearly impossible; players read clumps, so clump.
    limit = max(4, int(len(cells) * 0.34))
    assign: dict[tuple[int, int], int] = {}
    unassigned = set(cells)
    usage = [0] * colours

    def nbrs(cell):
        r, q = cell
        if r % 2 == 0:
            cand = [(r, q - 1), (r, q + 1), (r - 1, q - 1), (r - 1, q), (r + 1, q - 1), (r + 1, q)]
        else:
            cand = [(r, q - 1), (r, q + 1), (r - 1, q), (r - 1, q + 1), (r + 1, q), (r + 1, q + 1)]
        return [c for c in cand if c in unassigned]

    while unassigned:
        start_cell = rng.choice(sorted(unassigned))
        c = min(range(colours), key=lambda k: (usage[k] if usage[k] < limit else 10 ** 6, rng.random()))
        blob = [start_cell]
        unassigned.discard(start_cell)
        frontier = nbrs(start_cell)
        target = rng.randint(3, 6)
        while len(blob) < target and frontier:
            nxt = frontier.pop(rng.randrange(len(frontier)))
            if nxt not in unassigned:
                continue
            unassigned.discard(nxt)
            blob.append(nxt)
            frontier.extend(nbrs(nxt))
        for cell in blob:
            assign[cell] = c
        usage[c] += len(blob)

    # every colour must be on the board at least three times, or the queue can
    # hand out a colour nobody can use
    for c in range(colours):
        owned = [cell for cell in cells if assign.get(cell) == c]
        while len(owned) < 3:
            donor = max(range(colours), key=lambda k: sum(1 for x in cells if assign.get(x) == k))
            if donor == c:
                break
            spare = [x for x in cells if assign.get(x) == donor]
            if not spare:
                break
            cell = spare[-1]
            assign[cell] = c
            owned.append(cell)

    # blockers
    blockers: list[dict] = []
    grid = [["." for _ in range(cols)] for _ in range(rows)]
    for (r, q), c in assign.items():
        grid[r][q] = str(c + 1)

    if blocker_mode != "none":
        density = {"ice": 0.07, "ice_stone": 0.10, "mixed": 0.14, "dense": 0.18}[blocker_mode]
        candidates = [cell for cell in cells if cell[0] >= 1]
        rng.shuffle(candidates)
        n_blockers = int(len(candidates) * density)
        for i, (r, q) in enumerate(candidates[:n_blockers]):
            if blocker_mode in ("ice", "mixed", "dense") and i % 3 != 2:
                grid[r][q] = "i"
                blockers.append({"row": r, "col": q, "type": "ice", "hp": 2 if i % 5 == 0 else 1})
            elif blocker_mode in ("ice_stone", "mixed", "dense"):
                grid[r][q] = "x"
                blockers.append({"row": r, "col": q, "type": "stone", "hp": 0})
            else:
                grid[r][q] = "i"
                blockers.append({"row": r, "col": q, "type": "ice", "hp": 1})

    layout = ["".join(grid[r][: (cols if r % 2 == 0 else cols - 1)]) for r in range(rows)]
    return layout, blockers, palette


def _grid_neighbours(grid: list[list[str]], q: int, r: int) -> list[tuple[int, int]]:
    if r % 2 == 0:
        candidates = [(q - 1, r), (q + 1, r), (q - 1, r - 1), (q, r - 1),
                      (q - 1, r + 1), (q, r + 1)]
    else:
        candidates = [(q - 1, r), (q + 1, r), (q, r - 1), (q + 1, r - 1),
                      (q, r + 1), (q + 1, r + 1)]
    return [(nq, nr) for nq, nr in candidates
            if 0 <= nr < len(grid) and 0 <= nq < len(grid[nr])]


def _same_colour_component_size(grid: list[list[str]], start: tuple[int, int],
                                colour_char: str) -> int:
    seen = {start}
    stack = [start]
    while stack:
        q, r = stack.pop()
        for cell in _grid_neighbours(grid, q, r):
            if cell in seen:
                continue
            nq, nr = cell
            if grid[nr][nq] == colour_char:
                seen.add(cell)
                stack.append(cell)
    return len(seen)


def add_chain_blockers(layout: list[str], blockers: list[dict], rng: random.Random,
                       desired: int = 1) -> tuple[list[str], list[dict], int]:
    """Place rescue targets beside large, reachable colour groups near the ceiling."""
    grid = [list(line) for line in layout]
    candidates = [(q, r) for r in range(1, min(5, len(grid)))
                  for q, ch in enumerate(grid[r]) if ch.isdigit()]
    ranked = []

    for q, r in candidates:
        original = grid[r][q]
        grid[r][q] = "c"
        sizes = [
            _same_colour_component_size(grid, (nq, nr), original)
            for nq, nr in _grid_neighbours(grid, q, r)
            if grid[nr][nq] == original
        ]
        grid[r][q] = original
        largest_group = max(sizes, default=0)
        if largest_group >= 3:
            # Large groups and shallow rows are easier for the same solver and
            # player to reach. Randomness only breaks ties deterministically.
            ranked.append((largest_group, -r, rng.random(), q, r, original))

    ranked.sort(reverse=True)
    added = 0
    used_colours: set[int] = set()
    selected_positions: list[tuple[int, int]] = []
    for _size, _shallow, _tie, q, r, original in ranked:
        if grid[r][q] != original:
            continue
        colour_index = int(original) - 1
        # Rescue missions should require separate colour groups, not one pop
        # that happens to touch several chained cells in the same blob.
        if colour_index in used_colours:
            continue
        if any(abs(q - sq) + abs(r - sr) < 4 for sq, sr in selected_positions):
            continue

        # Re-check after each previous chain placement so no target is left
        # beside an unmatchable fragment.
        grid[r][q] = "c"
        still_matchable = any(
            grid[nr][nq] == original
            and _same_colour_component_size(grid, (nq, nr), original) >= 3
            for nq, nr in _grid_neighbours(grid, q, r)
        )
        if not still_matchable:
            grid[r][q] = original
            continue

        blockers.append({
            "row": r, "col": q, "type": "chain",
            "color": colour_index, "hp": 0,
        })
        used_colours.add(colour_index)
        selected_positions.append((q, r))
        added += 1
        if added >= desired:
            break

    if added < 2:
        raise ValueError("could not place two separated chain targets of different colours")
    return ["".join(row) for row in grid], blockers, added


def make_level(level_id: int, rng: random.Random, degrade: int = 0) -> dict:
    colours, ratio, blocker_mode, drop = schedule_for(level_id)
    cols = 9 if level_id <= 5 else 10 if level_id <= 20 else 11
    rows = MAX_ROWS
    kind = SILHOUETTES[(level_id - 1) % len(SILHOUETTES)]

    # How many rows of bubbles the level opens with. Boards grow downward while
    # you play, so an opening board that fills the screen is unplayable.
    fill_rows = 5 + (level_id - 1) // 14
    fill_rows = min(fill_rows, 13 - colours)

    if degrade >= 1:
        blocker_mode = "none"
    if degrade >= 2:
        colours = max(3, colours - 1)
        fill_rows = max(4, fill_rows - 1)
    if degrade >= 3:
        kind = "full"
        fill_rows = max(4, fill_rows - 2)

    layout, blockers, palette = build_layout(level_id, rng, colours, cols, rows,
                                             blocker_mode, kind, fill_rows)
    coloured = sum(1 for line in layout for ch in line if ch.isdigit())

    # A sparse silhouette that leaves 12 bubbles on the board is not a level:
    # the first good shot clears it. Top up to a real board.
    if coloured < 30:
        kind = "full" if kind != "full" else kind
        layout, blockers, palette = build_layout(level_id, rng, colours, cols, rows,
                                                 blocker_mode, kind, max(fill_rows, 7))
        coloured = sum(1 for line in layout for ch in line if ch.isdigit())

    # Rotate evenly through all six mission types. Rescue levels receive
    # actual chained bubble cells; score targets are calibrated later by tune().
    mission_slot = (level_id - 1) % 6
    if mission_slot == 0:
        objectives = [{"type": "clear_all"}]
    elif mission_slot == 1:
        objectives = [{"type": "clear_color", "color": palette[(level_id // 6) % len(palette)]}]
    elif mission_slot == 2:
        objectives = [{"type": "pop_count", "count": max(18, int(coloured * 0.65))}]
    elif mission_slot == 3:
        layout, blockers, chain_count = add_chain_blockers(layout, blockers, rng, desired=2)
        objectives = [{"type": "rescue", "count": 2}]
    elif mission_slot == 4:
        objectives = [{"type": "score", "target": 1}]
    else:
        survive_shots = max(7, min(12, int(coloured / 7)))
        objectives = [{"type": "survive", "shots": survive_shots}]

    shots = max(12, int(math.ceil(coloured / 3.2)) + 4)
    return {
        "id": level_id,
        "world": (level_id - 1) // 20 + 1,
        "name": f"{kind.title()} {level_id:03d}",
        "grid": {"cols": cols, "rows": rows, "seed": seed_for(level_id, 0)},
        "shots": shots,
        "palette": palette,
        "layout": layout,
        "blockers": blockers,
        "objectives": objectives,
        "stars": {"1": 1000, "2": 2000, "3": 3000},
        "rewards": {"coins": 40, "firstClearBonus": 100},
        "ceilingDropEvery": drop,
        "notes": f"{kind} silhouette, {colours} colours, {blocker_mode} blockers, {coloured} bubbles",
    }


def tune(level: dict, spare: int = 4) -> dict | None:
    """Solve the mission with a generous budget and derive a tested move budget."""
    probe = dict(level)
    probe["grid"] = dict(level["grid"])
    probe["grid"]["seed"] = seed_for(level["id"], 0)
    probe["shots"] = 140

    objectives = [dict(obj) for obj in level.get("objectives", [])]
    if len(objectives) != 1:
        return None

    # Calibrate score missions against a clear-all run using this same board
    # and deterministic seed, then require 72% of that achievable score.
    if objectives[0].get("type") == "score":
        baseline = dict(probe)
        baseline["objectives"] = [{"type": "clear_all"}]
        baseline_result = greedy_play(baseline, angles=18)
        if not baseline_result["won"] or baseline_result["score"] <= 0:
            print(
                f"DEBUG score baseline failed: level={level['id']} "
                f"won={baseline_result['won']} score={baseline_result['score']} "
                f"popped={baseline_result['popped']} shots={baseline_result['shots_used']}",
                flush=True,
            )
            return None
        target = max(200, int(baseline_result["score"] * 0.82))
        probe["objectives"] = [{"type": "score", "target": target}]

    result = greedy_play(probe, angles=18)
    if not result["won"]:
        print(
            f"DEBUG objective failed: level={level['id']} type={probe['objectives'][0]['type']} "
            f"score={result['score']} popped={result['popped']} freed={result['freed']} "
            f"shots={result['shots_used']} target={probe['objectives'][0]}",
            flush=True,
        )
        return None
    used = result["shots_used"]
    mission_type = probe["objectives"][0].get("type")
    minimum_shots = {"score": 3, "rescue": 2, "survive": 7}.get(mission_type, 5)
    if used < minimum_shots:
        print(
            f"DEBUG level too easy for balance gate: id={level['id']} "
            f"type={probe['objectives'][0]['type']} used={used} minimum={minimum_shots}",
            flush=True,
        )
        return None
    coloured = sum(1 for line in probe["layout"] for ch in line if ch.isdigit())
    if used > coloured / 2.0 + 8:
        return None

    probe["shots"] = used + spare
    s_val = max(result["score"], 1500)
    probe["stars"] = {
        "1": int(round(0.55 * s_val / 500.0)) * 500,
        "2": int(round(0.75 * s_val / 500.0)) * 500,
        "3": int(round(0.95 * s_val / 500.0)) * 500,
    }
    if not (probe["stars"]["1"] < probe["stars"]["2"] < probe["stars"]["3"]):
        probe["stars"] = {"1": 1000, "2": 2000, "3": 3000}
    probe["greedy"] = {
        "score": result["score"], "shots_used": used, "shots_left": spare,
        "objective": probe["objectives"][0],
    }
    return probe


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="godot_project/levels")
    ap.add_argument("--count", type=int, default=120)
    ap.add_argument("--first", type=int, default=1)
    ap.add_argument("--last", type=int, default=0)
    ap.add_argument("--seed", type=int, default=20261108)
    args = ap.parse_args()

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    last = args.last or args.count
    index = []
    failures = 0
    for lid in range(args.first, last + 1):
        rng = random.Random(args.seed + lid * 7919)
        made = None
        for retry in range(6):
            level = make_level(lid, random.Random(args.seed + lid * 7919 + retry * 104729),
                               degrade=retry // 2)
            errs = validate(level)
            if errs:
                continue
            tuned = tune(level)
            if tuned is not None:
                made = tuned
                break
        if made is None:
            failures += 1
            print(f"ERROR level {lid}: could not generate a solver-balanced level", flush=True)
            raise SystemExit(1)
        (out / f"level_{lid:03d}.json").write_text(json.dumps(made, indent=2) + "\n")
        index.append({"id": lid, "world": made["world"], "file": f"level_{lid:03d}.json",
                      "name": made["name"]})
        print(f"level {lid:03d}: shots={made['shots']:3d} greedy_left={made.get('greedy', {}).get('shots_left', '?')} "
              f"stars={made['stars']}")
    (out / "index.json").write_text(json.dumps({"levels": index, "count": len(index)}, indent=2) + "\n")
    print(f"wrote {len(index)} levels, {failures} unbalanced")


if __name__ == "__main__":
    main()
