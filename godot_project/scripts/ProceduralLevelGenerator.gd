class_name ProceduralLevelGenerator
extends RefCounted
## Seeded, math-driven campaign generation. A level is generated when the player
## reaches it; no level JSON file or remote connection is required at runtime.
## The same campaign seed + level number always creates the same board.

const COLOURS := ["red", "blue", "green", "yellow", "purple", "orange"]
const SHAPES := ["full", "arch", "diamond", "towers", "funnel", "zigzag", "cross", "heart", "checker"]
const TOTAL_ROWS := 14
const MIN_BUBBLES := 30


static func seed_for(level_id: int, campaign_seed: int) -> int:
	var mixed: int = int(campaign_seed) ^ (maxi(1, level_id) * 2654435761) ^ 0x5EED
	return mixed & 0x7FFFFFFF


static func difficulty_for(level_id: int) -> float:
	var id := maxi(1, level_id)
	# The curve rises quickly early, then continues in smaller steps for endless play.
	var early := minf(5.0, float(id - 1) / 24.0)
	var endless := minf(2.0, float(maxi(0, id - 120)) / 60.0)
	return 1.0 + early + endless


static func generate(level_id: int, campaign_seed: int) -> Dictionary:
	var id := maxi(1, level_id)
	var seed_value := seed_for(id, campaign_seed)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var difficulty := difficulty_for(id)
	var stage := int(floor(float(id - 1) / 15.0))
	var cols := 9 if id <= 20 else (10 if id <= 50 else 11)
	var active_rows := clampi(5 + int(floor(float(id - 1) / 15.0)), 5, 12)
	var colour_count := clampi(3 + int(floor(float(id - 1) / 30.0)), 3, 6)
	var shape := SHAPES[posmod(id - 1 + int(campaign_seed % SHAPES.size()), SHAPES.size())]

	var cells := _make_cells(cols, active_rows, shape)
	if cells.size() < MIN_BUBBLES:
		active_rows = maxi(active_rows, 7)
		shape = "full"
		cells = _make_cells(cols, active_rows, shape)

	var grid := _make_colour_grid(cols, active_rows, cells, colour_count, rng)
	var palette: Array = COLOURS.slice(0, colour_count)
	var blockers: Array[Dictionary] = []

	_add_normal_blockers(grid, cells, blockers, id, difficulty, rng)

	var mission_slot := posmod(id - 1, 6)
	var objectives: Array[Dictionary] = []
	var rescue_count := 0
	if mission_slot == 0:
		objectives = [{"type": "clear_all"}]
	elif mission_slot == 1:
		var target_colour := (id / 6) % colour_count
		objectives = [{"type": "clear_color", "color": palette[target_colour]}]
	elif mission_slot == 2:
		var count_target := maxi(18, int(round(float(cells.size()) * 0.58)))
		objectives = [{"type": "pop_count", "count": count_target}]
	elif mission_slot == 3:
		rescue_count = _add_rescue_chain(grid, cells, blockers, rng)
		objectives = [
			{"type": "rescue", "count": rescue_count},
			{"type": "pop_count", "count": maxi(16, int(round(float(cells.size()) * 0.42)))}
		]
	elif mission_slot == 4:
		var score_target := maxi(200, int(round(float(cells.size()) * (16.0 + difficulty * 1.5))))
		objectives = [{"type": "score", "target": score_target}]
	else:
		var safe_shots := clampi(5 + int(floor(float(active_rows) * 0.55)) + int(stage / 3), 7, 18)
		objectives = [{"type": "survive", "shots": safe_shots}]

	var layout: Array[String] = []
	for r in range(TOTAL_ROWS):
		var line := ""
		for q in range(_row_len(r, cols)):
			line += str(grid[r][q]) if r < grid.size() else "."
		layout.append(line)

	var shot_divisor := maxf(2.65, 3.8 - minf(1.0, difficulty * 0.13))
	var spare_shots := maxi(2, 7 - int(floor(difficulty)))
	var shots := maxi(10, int(ceil(float(cells.size()) / shot_divisor)) + spare_shots)
	var ceiling_drop := 0
	if id >= 26:
		ceiling_drop = clampi(10 - int(floor(difficulty)), 4, 10)

	return {
		"id": id,
		"world": int(floor(float(id - 1) / 20.0)) + 1,
		"name": "%s %03d" % [shape.capitalize(), id],
		"seed": seed_value,
		"difficulty": snappedf(difficulty, 0.01),
		"generatorVersion": 1,
		"grid": {"cols": cols, "rows": TOTAL_ROWS, "seed": seed_value},
		"shots": shots,
		"palette": palette,
		"layout": layout,
		"blockers": blockers,
		"objectives": objectives,
		"stars": {"1": 700, "2": 1200, "3": 1800},
		"rewards": {"coins": 40 + int(difficulty * 4.0), "firstClearBonus": 100 + int(difficulty * 3.0)},
		"ceilingDropEvery": ceiling_drop,
		"notes": "Seeded procedural level; %d bubbles, %d colours, %.2f difficulty" % [cells.size(), colour_count, difficulty]
	}


static func _row_len(row: int, cols: int) -> int:
	return cols if row % 2 == 0 else cols - 1


static func _make_cells(cols: int, active_rows: int, shape: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for r in range(active_rows):
		for q in range(_row_len(r, cols)):
			if r == 0 or _shape_allows(shape, q, r, cols, active_rows):
				out.append(Vector2i(q, r))
	return out


static func _shape_allows(shape: String, q: int, r: int, cols: int, active_rows: int) -> bool:
	var mid := float(cols - 1) / 2.0
	var dx := absf(float(q) - mid)
	var vertical := float(r) / maxf(1.0, float(active_rows - 1))
	match shape:
		"full":
			return true
		"arch":
			return dx <= float(cols) * (0.49 - 0.20 * vertical)
		"diamond":
			return dx / maxf(1.0, float(cols) * 0.5) + absf(vertical - 0.5) * 1.45 <= 1.13
		"towers":
			return q < int(ceil(float(cols) * 0.30)) or q >= int(floor(float(cols) * 0.70)) or r < 2
		"funnel":
			return r < 3 or q < 2 or q >= _row_len(r, cols) - 2
		"zigzag":
			return posmod(q + int(floor(float(r) / 2.0)) * 3, 5) != 0
		"cross":
			return dx < 1.7 or absf(float(r) - float(active_rows - 1) * 0.5) < 1.7
		"heart":
			return dx < float(cols) * 0.50 - vertical * float(cols) * 0.28
		"checker":
			return posmod(q + r, 2) == 0 or r < 2
	return true


static func _neighbours(cell: Vector2i, cols: int, rows: int) -> Array[Vector2i]:
	var q := cell.x
	var r := cell.y
	var candidates: Array[Vector2i] = []
	if r % 2 == 0:
		candidates = [
			Vector2i(q - 1, r), Vector2i(q + 1, r),
			Vector2i(q - 1, r - 1), Vector2i(q, r - 1),
			Vector2i(q - 1, r + 1), Vector2i(q, r + 1)
		]
	else:
		candidates = [
			Vector2i(q - 1, r), Vector2i(q + 1, r),
			Vector2i(q, r - 1), Vector2i(q + 1, r - 1),
			Vector2i(q, r + 1), Vector2i(q + 1, r + 1)
		]
	var out: Array[Vector2i] = []
	for n in candidates:
		if n.y >= 0 and n.y < rows and n.x >= 0 and n.x < _row_len(n.y, cols):
			out.append(n)
	return out


static func _make_colour_grid(
	cols: int,
	active_rows: int,
	cells: Array[Vector2i],
	colour_count: int,
	rng: RandomNumberGenerator
) -> Array:
	var grid: Array = []
	for r in range(TOTAL_ROWS):
		var row: Array[String] = []
		for _q in range(_row_len(r, cols)):
			row.append(".")
		grid.append(row)

	var unassigned: Dictionary = {}
	for cell in cells:
		unassigned[cell] = true
	var usage: Array[int] = []
	usage.resize(colour_count)
	usage.fill(0)

	while not unassigned.is_empty():
		var keys: Array = unassigned.keys()
		var start: Vector2i = keys[rng.randi_range(0, keys.size() - 1)]
		var minimum_usage := 2147483647
		var least_used: Array[int] = []
		for colour in range(colour_count):
			if usage[colour] < minimum_usage:
				minimum_usage = usage[colour]
				least_used.clear()
				least_used.append(colour)
			elif usage[colour] == minimum_usage:
				least_used.append(colour)
		var colour_index: int = least_used[rng.randi_range(0, least_used.size() - 1)]
		var target_size := rng.randi_range(3, 6)
		var blob: Array[Vector2i] = [start]
		var frontier: Array[Vector2i] = []
		unassigned.erase(start)
		for n in _neighbours(start, cols, active_rows):
			if unassigned.has(n):
				frontier.append(n)

		while blob.size() < target_size and not frontier.is_empty():
			var next_index := rng.randi_range(0, frontier.size() - 1)
			var next_cell := frontier.pop_at(next_index)
			if not unassigned.has(next_cell):
				continue
			unassigned.erase(next_cell)
			blob.append(next_cell)
			for n in _neighbours(next_cell, cols, active_rows):
				if unassigned.has(n) and not frontier.has(n):
					frontier.append(n)

		for cell in blob:
			grid[cell.y][cell.x] = str(colour_index + 1)
			usage[colour_index] += 1
	return grid


static func _add_normal_blockers(
	grid: Array,
	cells: Array[Vector2i],
	blockers: Array[Dictionary],
	level_id: int,
	difficulty: float,
	rng: RandomNumberGenerator
) -> void:
	var candidates: Array[Vector2i] = []
	for cell in cells:
		if cell.y > 0 and str(grid[cell.y][cell.x]).is_valid_int():
			candidates.append(cell)
	var density := clampf(0.015 + float(level_id - 1) * 0.00145, 0.0, 0.20)
	var amount := int(floor(float(candidates.size()) * density))
	for _i in range(amount):
		if candidates.is_empty():
			break
		var cell := candidates.pop_at(rng.randi_range(0, candidates.size() - 1))
		var original_colour := int(grid[cell.y][cell.x]) - 1
		if level_id >= 31 and rng.randf() < 0.22:
			grid[cell.y][cell.x] = "x"
			blockers.append({"row": cell.y, "col": cell.x, "type": "stone", "hp": 0})
		else:
			grid[cell.y][cell.x] = "i"
			blockers.append({
				"row": cell.y, "col": cell.x, "type": "ice",
				"color": original_colour, "hp": 2 if difficulty >= 3.0 and rng.randf() < 0.25 else 1
			})


static func _add_rescue_chain(
	grid: Array,
	cells: Array[Vector2i],
	blockers: Array[Dictionary],
	rng: RandomNumberGenerator
) -> int:
	var candidates: Array[Vector2i] = []
	for cell in cells:
		if cell.y > 0 and str(grid[cell.y][cell.x]).is_valid_int():
			candidates.append(cell)
	for i in range(candidates.size()):
		var swap_index := rng.randi_range(i, candidates.size() - 1)
		var temp := candidates[i]
		candidates[i] = candidates[swap_index]
		candidates[swap_index] = temp

	for cell in candidates:
		var colour_char := str(grid[cell.y][cell.x])
		for neighbour in _neighbours(cell, grid[0].size(), TOTAL_ROWS):
			if str(grid[neighbour.y][neighbour.x]) == colour_char:
				var component := _same_colour_component(grid, neighbour, colour_char)
				if component >= 2:
					grid[cell.y][cell.x] = "c"
					blockers.append({
						"row": cell.y, "col": cell.x, "type": "chain",
						"color": int(colour_char) - 1, "hp": 0
					})
					return 1
	return 0


static func _same_colour_component(grid: Array, start: Vector2i, colour_char: String) -> int:
	var visited: Dictionary = {start: true}
	var stack: Array[Vector2i] = [start]
	while not stack.is_empty():
		var cell: Vector2i = stack.pop_back()
		for n in _neighbours(cell, grid[0].size(), grid.size()):
			if visited.has(n) or str(grid[n.y][n.x]) != colour_char:
				continue
			visited[n] = true
			stack.append(n)
	return visited.size()
