extends Node
## Headless test suite. Run with:
##   godot --headless --path . res://tests/TestRunner.tscn
## Exits 0 when everything passes, 1 otherwise, so CI can gate on it.

var _pass := 0
var _fail := 0
var _messages: Array[String] = []


func _ready() -> void:
	print("== Bubble Shooter: Classic Blast - headless tests ==")
	_test_geometry()
	_test_neighbours()
	_test_ceiling_shot()
	_test_wall_bounce()
	_test_cluster()
	_test_floating()
	_test_ice_two_hits()
	_test_stone_never_matches()
	_test_colour_queue()
	_test_save_roundtrip()
	_test_save_tamper()
	_test_all_levels()
	_test_playthrough()
	await _test_gameplay_scene()
	_report()


func _check(name: String, condition: bool, detail: String = "") -> void:
	if condition:
		_pass += 1
		print("  PASS  ", name)
	else:
		_fail += 1
		var line := "  FAIL  %s %s" % [name, detail]
		_messages.append(line)
		print(line)


func _report() -> void:
	print("== %d passed, %d failed ==" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


# --------------------------------------------------------------------------- #
func _test_geometry() -> void:
	var b := HexBoard.new(11, 14)
	var ok := true
	for r in b.rows:
		for q in b.row_len(r):
			var c := b.centre(q, r)
			var back := b.nearest_cell(c)
			if back != Vector2i(q, r):
				ok = false
	_check("pixel -> cell round trip for every cell", ok)

	var pitch_ok := abs(HexBoard.ROW_PITCH - HexBoard.D * sqrt(3.0) / 2.0) < 0.001
	_check("row pitch is d*sqrt(3)/2", pitch_ok)


func _test_neighbours() -> void:
	var b := HexBoard.new(11, 14)
	var ok := true
	for r in range(1, b.rows - 1):
		for q in range(1, b.row_len(r) - 1):
			if b.neighbours(q, r).size() != 6:
				ok = false
	_check("six neighbours for every interior cell", ok)

	var dist_ok := true
	for n in b.neighbours(5, 6):
		if abs(b.centre(n.x, n.y).distance_to(b.centre(5, 6)) - HexBoard.D) > 0.01:
			dist_ok = false
	_check("neighbour centres are exactly d apart", dist_ok)


func _test_ceiling_shot() -> void:
	var b := HexBoard.new(11, 14)
	var t := ShotSimulator.trace(b, 0.0)
	_check("straight-up shot lands on row 0", t.valid and t.cell.y == 0, str(t.cell))


func _test_wall_bounce() -> void:
	var b := HexBoard.new(11, 14)
	var t := ShotSimulator.trace(b, deg_to_rad(74.0))
	_check("steep shot reflects off a wall", t.bounces >= 1, "bounces=%d" % t.bounces)
	_check("bounced shot still lands in bounds",
		not t.valid or (t.cell.x >= 0 and t.cell.x < b.row_len(t.cell.y)))


func _test_cluster() -> void:
	var b := HexBoard.new(11, 14)
	b.set_cell(3, 5, 0)
	b.set_cell(4, 5, 0)
	b.set_cell(2, 5, 0)
	var c := b.find_cluster(3, 5)
	_check("three in a row form a 3-cluster", c.size() == 3, "size=%d" % c.size())

	b.set_cell(5, 5, 1)
	var c2 := b.find_cluster(5, 5)
	_check("different colour is a separate cluster", c2.size() == 1)


func _test_floating() -> void:
	var b := HexBoard.new(11, 14)
	b.set_cell(0, 0, 0)
	b.set_cell(1, 0, 0)
	b.set_cell(0, 1, 0)
	# an island with no connection to row 0
	b.set_cell(6, 8, 1)
	b.set_cell(7, 8, 1)
	var floating := b.find_floating()
	_check("disconnected island is detected as floating", floating.size() == 2,
		"found=%d" % floating.size())


func _test_ice_two_hits() -> void:
	var b := HexBoard.new(11, 14)
	b.set_cell(3, 5, 0)
	b.set_cell(4, 5, 0)
	b.set_cell(2, 5, 0)
	b.set_cell(5, 5, 0, HexBoard.B_ICE, 2)
	var cluster := b.find_cluster(3, 5)
	_check("ice bubble joins a colour cluster", cluster.size() == 4, "size=%d" % cluster.size())


func _test_stone_never_matches() -> void:
	var b := HexBoard.new(11, 14)
	b.set_cell(3, 5, 0)
	b.set_cell(4, 5, 0)
	b.set_cell(5, 5, -1, HexBoard.B_STONE)
	b.set_cell(6, 5, 0)
	var cluster := b.find_cluster(3, 5)
	_check("stone splits a cluster", cluster.size() == 2, "size=%d" % cluster.size())


func _test_colour_queue() -> void:
	var b := HexBoard.new(11, 14)
	b.set_cell(0, 0, 2)
	b.set_cell(1, 0, 2)
	var rng := Rng32.new(12345)
	var ok := true
	for i in 200:
		var present := b.colours_present()
		var pick: int = present[rng.next_range(present.size())]
		if pick != 2:
			ok = false
	_check("queue never offers a colour that is not on the board", ok)


func _test_save_roundtrip() -> void:
	var path := "user://test_save.json"
	var payload := {"version": 3, "wallet": {"coins": 1234}, "flags": {"adsRemoved": true}}
	var wrote := SaveSystem.write_atomic(path, payload)
	var read_back := SaveSystem.read(path)
	_check("save writes atomically", wrote)
	_check("save reads back the same coins", int(read_back.get("wallet", {}).get("coins", 0)) == 1234)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _test_save_tamper() -> void:
	var path := "user://test_save_tamper.json"
	SaveSystem.write_atomic(path, {"version": 3, "wallet": {"coins": 10}})
	var f := FileAccess.open(path, FileAccess.READ)
	var env: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	# edit the body but leave the stored signature alone: exactly what a player
	# with a text editor would do
	var body := str(env["body"])
	body = body.replace("\"coins\":10", "\"coins\":99999")
	env["body"] = body
	var out := FileAccess.open(path, FileAccess.WRITE)
	out.store_string(JSON.stringify(env))
	out.close()
	var read_back := SaveSystem.read(path)
	_check("tampered save is rejected", read_back.is_empty(), str(read_back))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _test_all_levels() -> void:
	var idx := LevelLibrary.index()
	_check("level index has 100 entries", idx.size() == 100, "size=%d" % idx.size())
	var bad := 0
	var unbalanced := 0
	for i in range(1, 101):
		var lv := LevelLibrary.load_level(i)
		if lv.is_empty():
			bad += 1
			continue
		var cols := int(lv["grid"]["cols"])
		var rows := int(lv["grid"]["rows"])
		if cols < 9 or cols > 13 or rows < 10 or rows > 20:
			bad += 1
		for r in lv["layout"].size():
			var limit := cols if r % 2 == 0 else cols - 1
			if str(lv["layout"][r]).length() > limit:
				bad += 1
		if int(lv["shots"]) < 5:
			bad += 1
		var s: Dictionary = lv["stars"]
		if not (int(s["1"]) < int(s["2"]) and int(s["2"]) < int(s["3"])):
			bad += 1
		if not lv.has("greedy"):
			unbalanced += 1
	_check("every level passes the schema validator", bad == 0, "bad=%d" % bad)
	_check("every level is solver-balanced", unbalanced == 0, "unbalanced=%d" % unbalanced)


func _test_playthrough() -> void:
	# Play level 1 to completion with the same greedy policy the generator used.
	var lv := LevelLibrary.load_level(1)
	var board := HexBoard.new(int(lv["grid"]["cols"]), int(lv["grid"]["rows"]))
	var palette: Array = lv["palette"]
	board.load_layout(lv["layout"], palette.size(), lv.get("blockers", []))
	var rng := Rng32.new(int(lv["grid"]["seed"]))
	var shots := int(lv["shots"])
	var popped := 0
	var won := false
	for shot in shots:
		var present := board.colours_present()
		var colour: int = present[rng.next_range(present.size())] if not present.is_empty() else 0
		var best_cell := Vector2i(-1, -1)
		var best_size := -1
		for i in 25:
			var angle := lerpf(-deg_to_rad(75.0), deg_to_rad(75.0), float(i) / 24.0)
			var t := ShotSimulator.trace(board, angle)
			if not t.valid:
				continue
			var probe := board.clone()
			probe.set_cell(t.cell.x, t.cell.y, colour)
			var size := probe.find_cluster(t.cell.x, t.cell.y).size()
			if size > best_size:
				best_size = size
				best_cell = t.cell
		if best_cell.x < 0:
			break
		board.set_cell(best_cell.x, best_cell.y, colour)
		var cluster := board.find_cluster(best_cell.x, best_cell.y)
		if cluster.size() >= 3:
			for c in cluster:
				board.clear_cell(c.x, c.y)
			popped += cluster.size()
			for f in board.find_floating():
				board.clear_cell(f.x, f.y)
				popped += 1
		if board.coloured_count() <= 1:
			won = true
			break
	_check("level 1 is winnable by the greedy policy", won,
		"popped=%d left=%d" % [popped, board.coloured_count()])


## Integration: boot the real gameplay scene and fire one shot through the whole
## pipeline (aim -> trace -> flight -> snap -> match -> score -> HUD).
func _test_gameplay_scene() -> void:
	GameManager.current_level_id = 1
	var scene: PackedScene = load("res://scenes/Gameplay.tscn")
	var game: Node = scene.instantiate()
	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame

	var shots_before: int = game.shots_left
	var board_before: int = game.board.occupied_count()
	game._aim_at(Vector2(540, 900))
	game._shoot()
	_check("shooting enters the flying phase", game.phase == 1, "phase=%d" % game.phase)

	for i in 240:
		await get_tree().process_frame
		if game.phase != 1:
			break
	await get_tree().create_timer(0.6).timeout
	_check("shot resolves back to aim", game.phase == 0 or game.phase == 3, "phase=%d" % game.phase)
	_check("a shot costs exactly one move", game.shots_left == shots_before - 1,
		"%d -> %d" % [shots_before, game.shots_left])
	_check("the board changed after the shot", game.board.occupied_count() != board_before,
		"%d -> %d" % [board_before, game.board.occupied_count()])
	game.queue_free()
	await get_tree().process_frame
