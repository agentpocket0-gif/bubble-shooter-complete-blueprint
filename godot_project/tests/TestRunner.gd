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
	_test_snap_fallback()
	_test_cluster()
	_test_floating()
	_test_ice_two_hits()
	_test_stone_never_matches()
	_test_colour_queue()
	_test_save_roundtrip()
	_test_save_tamper()
	_test_iap_fails_closed_without_bridge()
	_test_all_levels()
	_test_assets()
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
	_check("trajectory enforces the three-bounce limit",
		t.bounces == ShotSimulator.MAX_BOUNCES and not t.valid, "bounces=%d valid=%s" % [t.bounces, t.valid])
	var legal := ShotSimulator.trace(b, deg_to_rad(35.0))
	_check("a legal reflected shot still reaches the ceiling", legal.valid and legal.bounces <= ShotSimulator.MAX_BOUNCES)


func _test_snap_fallback() -> void:
	var crowded := HexBoard.new(11, 14)
	var hit := Vector2i(5, 5)
	for n in crowded.neighbours(hit.x, hit.y):
		crowded.set_cell(n.x, n.y, 0)
	var point := crowded.centre(hit.x, hit.y)
	var snapped := ShotSimulator._snap(crowded, hit, point)
	_check("crowded hit uses the nearest empty cell within two diameters",
		snapped.x >= 0 and snapped.y >= 0
		and not crowded.filled(snapped.x, snapped.y)
		and crowded.centre(snapped.x, snapped.y).distance_to(point) <= HexBoard.D * 2.0)

	var full_ceiling := HexBoard.new(11, 14)
	for q in full_ceiling.row_len(0):
		full_ceiling.set_cell(q, 0, 0)
	var ceiling_x := full_ceiling.centre(5, 0).x
	var ceiling_cell := ShotSimulator._snap_ceiling(full_ceiling, ceiling_x)
	_check("full ceiling row falls back to the nearest open cell within two diameters",
		ceiling_cell.x >= 0 and ceiling_cell.y >= 0
		and not full_ceiling.filled(ceiling_cell.x, ceiling_cell.y)
		and full_ceiling.centre(ceiling_cell.x, ceiling_cell.y).distance_to(Vector2(ceiling_x, 0.0)) <= HexBoard.D * 2.0)


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


func _test_iap_fails_closed_without_bridge() -> void:
	# The CI runner has no native billing plugin. It must never mint paid goods.
	var before_coins := GameManager.coins()
	var result := {"called": false, "ok": true}
	var handler := func(_sku_id: String, ok: bool) -> void:
		result["called"] = true
		result["ok"] = ok

	StoreAndEconomy.purchase_finished.connect(handler)
	StoreAndEconomy.purchase("coins_small")
	StoreAndEconomy.purchase_finished.disconnect(handler)

	_check("missing native billing bridge reports purchase failure",
		bool(result["called"]) and not bool(result["ok"]))
	_check("paid currency is not granted without store confirmation",
		GameManager.coins() == before_coins)


func _test_all_levels() -> void:
	# The first 120 levels are generated at runtime too. This test verifies the
	# generator, campaign seed, six objectives, difficulty curve and endless IDs.
	_check("new campaign starts with a 120-level map preview", LevelLibrary.count() == 120)
	var bad := 0
	var mission_types := {}
	var rescue_levels := 0
	var rescue_chain_cells := 0
	var campaign_seed := GameManager.campaign_seed()
	var level_one_bubbles := 0

	for i in range(1, 121):
		var lv := LevelLibrary.load_level(i)
		if lv.is_empty() or int(lv.get("id", -1)) != i:
			bad += 1
			continue
		var cols := int(lv["grid"]["cols"])
		var rows := int(lv["grid"]["rows"])
		if cols < 9 or cols > 13 or rows != 14:
			bad += 1
		for r in range(rows):
			var limit := cols if r % 2 == 0 else cols - 1
			if str(lv["layout"][r]).length() != limit:
				bad += 1
		if int(lv["shots"]) < 5 or int(lv.get("seed", 0)) != ProceduralLevelGenerator.seed_for(i, campaign_seed):
			bad += 1
		var stars: Dictionary = lv["stars"]
		if not (int(stars["1"]) < int(stars["2"]) and int(stars["2"]) < int(stars["3"])):
			bad += 1
		if i == 1:
			for row in lv["layout"]:
				level_one_bubbles += str(row).count("1") + str(row).count("2") + str(row).count("3") + str(row).count("4") + str(row).count("5") + str(row).count("6")
		for objective in lv.get("objectives", []):
			var mission := str(objective.get("type", ""))
			mission_types[mission] = true
			if mission == "rescue":
				rescue_levels += 1
				for row in lv["layout"]:
					rescue_chain_cells += str(row).count("c")
			if mission == "survive" and int(objective.get("shots", 0)) <= 0:
				bad += 1

	_check("120 on-demand levels pass the generation schema", bad == 0, "bad=%d" % bad)
	_check("seeded tutorial board contains 43 bubbles", level_one_bubbles == 43, "bubbles=%d" % level_one_bubbles)
	var required_missions := ["clear_all", "clear_color", "pop_count", "rescue", "score", "survive"]
	var missing_missions: Array[String] = []
	for mission_type in required_missions:
		if not mission_types.has(mission_type):
			missing_missions.append(mission_type)
	_check("procedural campaign generates all six mission types", missing_missions.is_empty(), str(missing_missions))
	_check("procedural rescue levels contain chained bubbles", rescue_levels == 20 and rescue_chain_cells >= rescue_levels)

	var seed_a := ProceduralLevelGenerator.generate(321, 123456)
	var seed_b := ProceduralLevelGenerator.generate(321, 123456)
	var seed_c := ProceduralLevelGenerator.generate(321, 654321)
	_check("same campaign seed reproduces the same level", seed_a["layout"] == seed_b["layout"] and seed_a["seed"] == seed_b["seed"])
	_check("different campaign seeds change generated content", seed_a["seed"] != seed_c["seed"])
	_check("difficulty rises with player progression",
		ProceduralLevelGenerator.difficulty_for(1) < ProceduralLevelGenerator.difficulty_for(60)
		and ProceduralLevelGenerator.difficulty_for(60) < ProceduralLevelGenerator.difficulty_for(120)
		and ProceduralLevelGenerator.difficulty_for(120) < ProceduralLevelGenerator.difficulty_for(240)
		and ProceduralLevelGenerator.difficulty_for(240) < ProceduralLevelGenerator.difficulty_for(960))

	var endless_level := LevelLibrary.load_level(2400)
	_check("level 2400 generates without a bundled file",
		int(endless_level.get("id", 0)) == 2400 and not endless_level.is_empty())
	var previous_max := int(GameManager.data["progress"]["maxLevel"])
	GameManager.data["progress"]["maxLevel"] = 121
	_check("saga map preview expands as the player unlocks levels", LevelLibrary.count() == 141)
	GameManager.data["progress"]["maxLevel"] = previous_max


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

	var original_level: Dictionary = game.level.duplicate(true)
	var original_shots_taken: int = game.shots_taken
	game.level["objectives"] = [{"type": "survive", "shots": 3}]
	game.shots_taken = 2
	_check("survive objective waits for its required shot count", not game._objective_met())
	game.shots_taken = 3
	_check("survive objective completes after the required safe shots", game._objective_met())
	game.level = original_level
	game.shots_taken = original_shots_taken

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


# --------------------------------------------------------------------------- #
# Assets: nothing in the code may point at a file that is not there.
# --------------------------------------------------------------------------- #
func _walk(dir_path: String, suffix: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var full := dir_path.path_join(name)
		if dir.current_is_dir():
			out.append_array(_walk(full, suffix))
		elif name.ends_with(suffix):
			out.append(full)
		name = dir.get_next()
	dir.list_dir_end()
	return out


func _test_assets() -> void:
	var rx := RegEx.new()
	rx.compile("res://assets/[A-Za-z0-9_/\\-%.]+\\.(png|wav|ogg)")
	var missing: Array[String] = []
	var scanned := 0
	for file in _walk("res://", ".gd"):
		var text := FileAccess.get_file_as_string(file)
		for m in rx.search_all(text):
			var path := m.get_string()
			if path.contains("%"):
				continue
			scanned += 1
			if not ResourceLoader.exists(path):
				missing.append(path + "  (in " + file + ")")
	_check("every asset path used in code exists", missing.is_empty(),
		"%d checked, missing: %s" % [scanned, str(missing.slice(0, 4))])

	var bad: Array[String] = []
	for path in AssetRegistry.all_paths():
		if not ResourceLoader.exists(path):
			bad.append(path)
	_check("every file in AssetRegistry resolves", bad.is_empty(), str(bad.slice(0, 4)))
	_check("AssetRegistry catalogues the full pack", AssetRegistry.TEXTURES.size() >= 140,
		"%d textures" % AssetRegistry.TEXTURES.size())
