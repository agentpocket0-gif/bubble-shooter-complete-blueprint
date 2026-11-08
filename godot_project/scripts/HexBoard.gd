class_name HexBoard
extends RefCounted
## Staggered hex grid for a bubble shooter.
##
## Geometry (blueprint 02):
##   row pitch  = d * sqrt(3)/2
##   odd rows   = shifted right by d/2 and one cell shorter (the inset variant,
##                so both parities fit inside the same walls)
##   neighbours = six, always at distance d
##
## Storage is flat PackedInt32Arrays indexed by r * cols + q: no per-cell
## objects, no allocation during BFS, and a clone is a memcpy.

const D := 96.0
const ROW_PITCH := 96.0 * 0.8660254037844386
const HALF := 48.0
const HIT_FACTOR := 0.92
const LEFT_WALL := 12.0
const RIGHT_WALL := 1068.0
const ORIGIN_X := 60.0            # LEFT_WALL + HALF
const EMPTY := -1

const B_NONE := 0
const B_STONE := 1
const B_ICE := 2
const B_CHAIN := 3

var cols: int = 11
var rows: int = 14
var colour := PackedInt32Array()
var hp := PackedInt32Array()
var blocker := PackedInt32Array()


func _init(p_cols: int = 11, p_rows: int = 14) -> void:
	cols = p_cols
	rows = p_rows
	var n := cols * rows
	colour.resize(n)
	colour.fill(EMPTY)
	hp.resize(n)
	hp.fill(0)
	blocker.resize(n)
	blocker.fill(B_NONE)


func _idx(q: int, r: int) -> int:
	return r * cols + q


func clone() -> HexBoard:
	var b := HexBoard.new(cols, rows)
	b.colour = colour.duplicate()
	b.hp = hp.duplicate()
	b.blocker = blocker.duplicate()
	return b


func row_len(r: int) -> int:
	return cols if r % 2 == 0 else cols - 1


func in_bounds(q: int, r: int) -> bool:
	return r >= 0 and r < rows and q >= 0 and q < row_len(r)


func filled(q: int, r: int) -> bool:
	if not in_bounds(q, r):
		return false
	var i := _idx(q, r)
	return colour[i] != EMPTY or blocker[i] == B_STONE


func colour_at(q: int, r: int) -> int:
	if not in_bounds(q, r):
		return EMPTY
	return colour[_idx(q, r)]


func blocker_at(q: int, r: int) -> int:
	if not in_bounds(q, r):
		return B_NONE
	return blocker[_idx(q, r)]


func hp_at(q: int, r: int) -> int:
	if not in_bounds(q, r):
		return 0
	return hp[_idx(q, r)]


func centre(q: int, r: int) -> Vector2:
	return Vector2(ORIGIN_X + q * D + (r % 2) * HALF, r * ROW_PITCH)


func nearest_cell(p: Vector2) -> Vector2i:
	# round the row first: q depends on the row's parity
	var r := int(round(p.y / ROW_PITCH))
	r = clampi(r, 0, rows - 1)
	var q := int(round((p.x - ORIGIN_X - (r % 2) * HALF) / D))
	q = clampi(q, 0, row_len(r) - 1)
	return Vector2i(q, r)


func neighbours(q: int, r: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var cand: Array[Vector2i]
	if r % 2 == 0:
		cand = [Vector2i(q - 1, r), Vector2i(q + 1, r), Vector2i(q - 1, r - 1),
			Vector2i(q, r - 1), Vector2i(q - 1, r + 1), Vector2i(q, r + 1)]
	else:
		cand = [Vector2i(q - 1, r), Vector2i(q + 1, r), Vector2i(q, r - 1),
			Vector2i(q + 1, r - 1), Vector2i(q, r + 1), Vector2i(q + 1, r + 1)]
	for c in cand:
		if in_bounds(c.x, c.y):
			out.append(c)
	return out


func set_cell(q: int, r: int, col: int, blk: int = B_NONE, hit_points: int = 0) -> void:
	if not in_bounds(q, r):
		return
	var i := _idx(q, r)
	colour[i] = col
	blocker[i] = blk
	hp[i] = hit_points


func clear_cell(q: int, r: int) -> void:
	set_cell(q, r, EMPTY, B_NONE, 0)


func colours_present() -> Array[int]:
	var seen := {}
	for r in rows:
		for q in row_len(r):
			var i := _idx(q, r)
			if colour[i] >= 0 and blocker[i] != B_CHAIN:
				seen[colour[i]] = true
	var out: Array[int] = []
	for k in seen.keys():
		out.append(int(k))
	out.sort()
	return out


func coloured_count() -> int:
	var n := 0
	for i in colour.size():
		if colour[i] >= 0:
			n += 1
	return n


func max_row_used() -> int:
	for r in range(rows - 1, -1, -1):
		for q in row_len(r):
			if colour[_idx(q, r)] != EMPTY or blocker[_idx(q, r)] == B_STONE:
				return r
	return -1


func occupied_count() -> int:
	var n := 0
	for r in rows:
		for q in row_len(r):
			if filled(q, r):
				n += 1
	return n


## Breadth-first same-colour cluster. Stone and chained bubbles never match.
func find_cluster(q: int, r: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not filled(q, r):
		return out
	var target := colour[_idx(q, r)]
	if target < 0:
		return out
	var blk := blocker[_idx(q, r)]
	if blk == B_STONE or blk == B_CHAIN:
		return out
	var seen := {Vector2i(q, r): true}
	var stack: Array[Vector2i] = [Vector2i(q, r)]
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		out.append(c)
		for n in neighbours(c.x, c.y):
			if seen.has(n):
				continue
			var i := _idx(n.x, n.y)
			if colour[i] != target:
				continue
			if blocker[i] == B_STONE or blocker[i] == B_CHAIN:
				continue
			seen[n] = true
			stack.append(n)
	return out


## Every bubble not connected to row 0 through occupied cells of any colour.
func find_floating() -> Array[Vector2i]:
	var anchored := {}
	var stack: Array[Vector2i] = []
	for q in row_len(0):
		if filled(q, 0):
			anchored[Vector2i(q, 0)] = true
			stack.append(Vector2i(q, 0))
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for n in neighbours(c.x, c.y):
			if anchored.has(n) or not filled(n.x, n.y):
				continue
			anchored[n] = true
			stack.append(n)
	var out: Array[Vector2i] = []
	for r in rows:
		for q in row_len(r):
			if filled(q, r) and not anchored.has(Vector2i(q, r)):
				out.append(Vector2i(q, r))
	return out


func load_layout(layout: Array, palette_size: int, blockers: Array) -> void:
	var overrides := {}
	for b in blockers:
		overrides[Vector2i(int(b.get("col", 0)), int(b.get("row", 0)))] = b
	for r in min(layout.size(), rows):
		var line: String = str(layout[r])
		for q in min(line.length(), row_len(r)):
			var ch := line.substr(q, 1)
			if ch == ".":
				continue
			if ch.is_valid_int():
				set_cell(q, r, int(ch) - 1)
			elif ch == "x":
				set_cell(q, r, EMPTY, B_STONE, 0)
			elif ch == "i":
				var b: Dictionary = overrides.get(Vector2i(q, r), {})
				var col := int(b.get("color", (r * 3 + q) % max(1, palette_size)))
				set_cell(q, r, col, B_ICE, int(b.get("hp", 1)))
			elif ch == "c":
				var b2: Dictionary = overrides.get(Vector2i(q, r), {})
				var col2 := int(b2.get("color", (r + q) % max(1, palette_size)))
				set_cell(q, r, col2, B_CHAIN, 0)
