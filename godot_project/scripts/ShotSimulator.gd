class_name ShotSimulator
extends RefCounted
## The one integrator used by both the aim preview and the real shot.
##
## A preview that lies is worse than no preview, so the dotted line the player
## sees and the bubble they fire run through exactly this code: substeps of
## d/2, reflection off both walls (never clamping), a hit when a bubble centre
## is within 0.92 * d, and a snap to the free neighbour of the bubble hit.

const STEP := HexBoard.D * 0.5
const MAX_STEPS := 400
const CANNON_X := 540.0
const CANNON_Y := 1450.0
const MAX_ANGLE_DEG := 75.0
const MAX_BOUNCES := 3


class Trace:
	var points: PackedVector2Array = PackedVector2Array()
	var cell := Vector2i(-1, -1)
	var hit_bubble := Vector2i(-1, -1)
	var bounces := 0
	var valid := false


static func clamp_angle(angle: float) -> float:
	var limit := deg_to_rad(MAX_ANGLE_DEG)
	return clampf(angle, -limit, limit)


static func direction(angle: float) -> Vector2:
	return Vector2(sin(angle), -cos(angle))


static func trace(board: HexBoard, angle: float, origin := Vector2(CANNON_X, CANNON_Y)) -> Trace:
	var t := Trace.new()
	var pos := origin
	var dir := direction(clamp_angle(angle))
	t.points.append(pos)
	var steps := 0
	while steps < MAX_STEPS:
		steps += 1
		pos += dir * STEP
		# reflect, do not clamp: clamping makes the bubble stick to the wall for
		# a frame and the preview disagrees with the shot
		if pos.x - HexBoard.HALF < HexBoard.LEFT_WALL:
			if t.bounces >= MAX_BOUNCES:
				pos.x = HexBoard.LEFT_WALL + HexBoard.HALF
				t.points.append(pos)
				return t
			pos.x = HexBoard.LEFT_WALL + HexBoard.HALF + (HexBoard.LEFT_WALL - (pos.x - HexBoard.HALF))
			dir.x = -dir.x
			t.bounces += 1
			t.points.append(pos)
		elif pos.x + HexBoard.HALF > HexBoard.RIGHT_WALL:
			if t.bounces >= MAX_BOUNCES:
				pos.x = HexBoard.RIGHT_WALL - HexBoard.HALF
				t.points.append(pos)
				return t
			pos.x = HexBoard.RIGHT_WALL - HexBoard.HALF - ((pos.x + HexBoard.HALF) - HexBoard.RIGHT_WALL)
			dir.x = -dir.x
			t.bounces += 1
			t.points.append(pos)
		if pos.y <= 0.0:
			t.points.append(pos)
			var cell := _snap_ceiling(board, pos.x)
			if cell.x >= 0:
				t.cell = cell
				t.valid = true
			return t
		var hit := _first_hit(board, pos)
		if hit.x >= 0:
			t.points.append(pos)
			t.hit_bubble = hit
			var cell2 := _snap(board, hit, pos)
			if cell2.x >= 0:
				t.cell = cell2
				t.valid = true
			return t
	t.points.append(pos)
	return t


static func _first_hit(board: HexBoard, p: Vector2) -> Vector2i:
	var r0 := int(round(p.y / HexBoard.ROW_PITCH))
	var best := Vector2i(-1, -1)
	var best_d := HexBoard.HIT_FACTOR * HexBoard.D
	for r in range(max(0, r0 - 2), min(board.rows, r0 + 3)):
		for q in board.row_len(r):
			if not board.filled(q, r):
				continue
			var dist := board.centre(q, r).distance_to(p)
			if dist < best_d:
				best_d = dist
				best = Vector2i(q, r)
	return best


static func _snap_ceiling(board: HexBoard, x: float) -> Vector2i:
	var q := clampi(int(round((x - HexBoard.ORIGIN_X) / HexBoard.D)), 0, board.row_len(0) - 1)
	var best := Vector2i(-1, -1)
	var best_d := INF
	# Pick the closest open cell in row 0, searching both directions.
	for candidate in board.row_len(0):
		if board.filled(candidate, 0):
			continue
		var d := absf(board.centre(candidate, 0).x - x)
		if d < best_d:
			best_d = d
			best = Vector2i(candidate, 0)
	if best.x >= 0:
		return best
	# A full ceiling row can still have room within the two-cell fallback ring.
	return _nearest_empty_within(board, Vector2i(q, 0), Vector2(x, 0))


static func _snap(board: HexBoard, hit: Vector2i, p: Vector2) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for n in board.neighbours(hit.x, hit.y):
		if board.filled(n.x, n.y):
			continue
		var d := board.centre(n.x, n.y).distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = n
	if best.x >= 0:
		return best
	return _nearest_empty_within(board, hit, p)


static func _nearest_empty_within(board: HexBoard, start: Vector2i, point: Vector2) -> Vector2i:
	if not board.in_bounds(start.x, start.y):
		return Vector2i(-1, -1)
	var max_distance_sq := pow(HexBoard.D * 2.0, 2.0)
	var best := Vector2i(-1, -1)
	var best_d := INF
	var queue: Array[Vector2i] = [start]
	var depth_by_cell := {start: 0}
	var cursor := 0
	while cursor < queue.size():
		var cell: Vector2i = queue[cursor]
		cursor += 1
		var depth := int(depth_by_cell[cell])
		var d := board.centre(cell.x, cell.y).distance_squared_to(point)
		if not board.filled(cell.x, cell.y) and d <= max_distance_sq and d < best_d:
			best = cell
			best_d = d
		if depth >= 2:
			continue
		for neighbour in board.neighbours(cell.x, cell.y):
			if depth_by_cell.has(neighbour):
				continue
			depth_by_cell[neighbour] = depth + 1
			queue.append(neighbour)
	return best


## Landing cell for the ghost bubble / laser booster: nearest free cell when the
## shot would otherwise be impossible.
static func landing_cell(board: HexBoard, angle: float) -> Vector2i:
	return trace(board, angle).cell
