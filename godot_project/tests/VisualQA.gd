extends Node
## Runtime proof + visual QA harness.
##
## Runs the real scenes, presses the real buttons and captures real frames:
##
##   xvfb-run -a -s "-screen 0 1080x1920x24" \
##     godot --path godot_project --rendering-driver opengl3 res://tests/VisualQA.tscn
##
## Writes qa_proof/*.png and qa_proof/proof_log.txt, then exits 0 (all proofs
## held) or 1 (something is broken). Every assertion here is something that can
## actually regress: a missing texture, a button whose signal is not connected,
## a popup that will not close, a shot that does not resolve.

const OUT_DIR := "res://qa_proof"

var _failures: Array[String] = []
var _checks: Array[String] = []
var _shot_index := 0


func _ready() -> void:
	GameManager.suppress_scene_changes = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	DisplayServer.window_set_size(Vector2i(1080, 1920))
	await get_tree().process_frame
	await _run()
	_report()


func _run() -> void:
	await _step_splash()
	await _step_map()
	await _step_piggy()
	await _step_store()
	await _step_gameplay()
	await _step_result()


# --------------------------------------------------------------------------- #
# 1. splash
# --------------------------------------------------------------------------- #
func _step_splash() -> void:
	var splash: Node = (load("res://scenes/Splash.tscn") as PackedScene).instantiate()
	add_child(splash)
	await get_tree().create_timer(0.5).timeout

	var logo: TextureRect = null
	for t in splash.find_children("*", "TextureRect", true, false):
		if (t as TextureRect).texture != null and str((t as TextureRect).texture.resource_path).contains("title_logo"):
			logo = t
			break
	_check("splash renders the real title logo texture", logo != null)
	await _capture("01_splash_screen.png")
	splash.queue_free()
	await get_tree().process_frame


# --------------------------------------------------------------------------- #
# 2. saga map + 3/4. piggy bank open/closed
# --------------------------------------------------------------------------- #
var _map: Node = null


func _step_map() -> void:
	_map = (load("res://scenes/SagaMap.tscn") as PackedScene).instantiate()
	add_child(_map)
	await get_tree().create_timer(0.6).timeout

	var nodes: int = 0
	for b in _map.find_children("*", "Button", true, false):
		if b.has_meta("level_id"):
			nodes += 1
	_check("saga map builds the current 120-level preview", nodes == 120, "found=%d" % nodes)

	var scroll_nodes := _map.find_children("*", "ScrollContainer", true, false)
	var can_scroll := false
	if not scroll_nodes.is_empty():
		var map_scroll := scroll_nodes[0] as ScrollContainer
		var vertical_bar := map_scroll.get_v_scroll_bar()
		can_scroll = vertical_bar.max_value > vertical_bar.page
	_check("procedural campaign map has a working vertical scroll range", can_scroll)

	var rail_actions := {}
	for rail_button in _map.find_children("*", "TextureButton", true, false):
		if rail_button.has_meta("action"):
			rail_actions[str(rail_button.get_meta("action"))] = true
	_check("map side rail has spin, piggy bank and store actions",
		rail_actions.size() == 3 and rail_actions.has("spin")
		and rail_actions.has("piggy") and rail_actions.has("store"))

	var level_one: Button = null
	for b in _map.find_children("*", "Button", true, false):
		if b.has_meta("level_id") and int(b.get_meta("level_id")) == 1:
			level_one = b
			break
	_check("level 1 button exists and is unlocked",
		level_one != null and bool(level_one.get_meta("unlocked", false)))
	_check("level 1 button has a connected pressed signal",
		level_one != null and level_one.pressed.get_connections().size() > 0)
	await _capture("02_saga_world_map.png")


func _step_piggy() -> void:
	var pressed: bool = _map.call("press_rail_button", "piggy")
	await get_tree().create_timer(0.45).timeout
	_check("piggy bank rail button opens the popup",
		pressed and bool(_map.call("has_overlay")))
	await _capture("03_piggy_bank_open.png")

	var closed: bool = _map.call("press_overlay_button", "Close")
	await get_tree().create_timer(0.45).timeout
	_check("piggy bank Close button actually closes the popup",
		closed and not bool(_map.call("has_overlay")))
	await _capture("04_piggy_bank_closed_back_to_map.png")


func _step_store() -> void:
	var pressed: bool = _map.call("press_rail_button", "store")
	await get_tree().create_timer(0.45).timeout
	_check("store rail button opens the shop", pressed and bool(_map.call("has_overlay")))
	await _capture("05_store_and_spin_wheel.png")
	_map.call("close_overlay")
	await get_tree().create_timer(0.3).timeout

	var spin_pressed: bool = _map.call("press_rail_button", "spin")
	await get_tree().create_timer(0.45).timeout
	_check("spin rail button opens the daily wheel",
		spin_pressed and bool(_map.call("has_overlay")))

	var spin_button: Button = null
	for candidate in _map.find_children("*", "Button", true, false):
		if (candidate as Button).text == "SPIN":
			spin_button = candidate as Button
			break

	var coins_before := GameManager.coins()
	_check("daily wheel offers a free spin when ready",
		spin_button != null and not spin_button.disabled and StoreAndEconomy.spin_ready())
	var spin_claimed: bool = _map.call("press_overlay_button", "SPIN")
	await get_tree().create_timer(1.0).timeout
	_check("free daily spin grants a virtual prize without spending coins",
		spin_claimed and spin_button != null and spin_button.disabled
		and GameManager.coins() >= coins_before)
	_check("daily spin starts its 24-hour cooldown",
		not StoreAndEconomy.spin_ready() and StoreAndEconomy.spin_wait_seconds() > 0)
	_map.call("close_overlay")
	await get_tree().create_timer(0.3).timeout


# --------------------------------------------------------------------------- #
# 5. level 1: real button press -> gameplay -> shot
# --------------------------------------------------------------------------- #
func _step_gameplay() -> void:
	var pressed: bool = _map.call("press_level_button", 1)
	await get_tree().create_timer(0.2).timeout
	_check("tapping level 1 starts that level",
		pressed and GameManager.current_level_id == 1 and GameManager.state == GameManager.State.LEVEL_PLAY,
		"state=%d level=%d" % [GameManager.state, GameManager.current_level_id])

	_map.queue_free()
	_map = null
	await get_tree().process_frame

	var game: Node = (load("res://scenes/Gameplay.tscn") as PackedScene).instantiate()
	add_child(game)
	await get_tree().create_timer(0.6).timeout

	var filled: int = 0
	for r in game.board.rows:
		for q in game.board.row_len(r):
			if game.board.filled(q, r):
				filled += 1
	_check("level 1 populates the hex grid from its saved campaign seed", filled > 20, "bubbles=%d" % filled)

	var sprites: int = game.board_layer.get_child_count()
	_check("the board is drawn with real bubble sprites, not drawn circles",
		sprites == filled and sprites > 20, "sprites=%d bubbles=%d" % [sprites, filled])

	var textured := true
	for node in game.board_layer.get_children():
		var sprite: Sprite2D = node.get_child(0)
		if sprite.texture == null:
			textured = false
	_check("every bubble sprite has a real texture", textured)

	_check("the bubble in the cannon is visible and textured",
		game.loaded != null and game.loaded.visible and game.loaded.texture != null)
	await _capture("06_level_1_active_gameplay.png")

	var shots_before: int = game.shots_left
	var score_before: int = game.score
	game._aim_at(Vector2(540, 900))
	game._shoot()
	for i in 300:
		await get_tree().process_frame
		if game.phase == 0:
			break
	await get_tree().create_timer(0.6).timeout
	_check("firing a bubble resolves and costs one move",
		game.shots_left == shots_before - 1, "%d -> %d" % [shots_before, game.shots_left])
	_check("the score HUD updates after the shot",
		game.score_label.text == str(game.score) and game.score >= score_before,
		"hud=%s score=%d" % [game.score_label.text, game.score])
	_check("a new bubble is loaded after the shot", game.loaded.visible)
	await _capture("07_after_shot.png")

	# 08: a booster activation, captured mid-pop so the frame-by-frame VFX is in shot
	var bombs: int = GameManager.booster_count("bomb")
	_check("a bomb booster is available to test", bombs > 0, "count=%d" % bombs)
	game._on_booster_pressed("bomb")
	game._aim_at(Vector2(720, 900))
	game._shoot()
	for i in 300:
		await get_tree().process_frame
		if game.phase == 2:
			break
	await get_tree().create_timer(0.12).timeout
	await _capture("08_booster_activation_or_combo_pop.png")
	await get_tree().create_timer(0.5).timeout
	game.queue_free()
	await get_tree().process_frame


# --------------------------------------------------------------------------- #
# 9. the win popup, with its star celebration
# --------------------------------------------------------------------------- #
func _step_result() -> void:
	GameManager.last_result = {
		"won": true, "stars": 3, "score": 4820, "coins": 140,
		"level": 1, "popped": 61, "first_clear": true, "shots_left": 4,
	}
	var result: Node = (load("res://scenes/Result.tscn") as PackedScene).instantiate()
	add_child(result)
	await get_tree().create_timer(1.0).timeout

	var buttons: int = 0
	for b in result.find_children("*", "Button", true, false):
		buttons += 1
	_check("the win popup offers its buttons", buttons >= 3, "buttons=%d" % buttons)
	await _capture("09_level_win_result_popup.png")
	result.queue_free()
	await get_tree().process_frame


# --------------------------------------------------------------------------- #
# helpers
# --------------------------------------------------------------------------- #
func _capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless":
		# headless has no renderer, so frame_post_draw never fires; bail out
		# instead of hanging, and record it as a real failure
		_check("captured %s" % filename, false, "headless: no framebuffer, run under xvfb")
		return
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	if img == null:
		_check("captured %s" % filename, false, "no framebuffer (run under xvfb with a real renderer)")
		return
	var path: String = OUT_DIR.path_join(filename)
	var err: int = img.save_png(path)
	_shot_index += 1
	_check("captured %s" % filename, err == OK, "err=%d" % err)


func _check(label: String, ok: bool, detail: String = "") -> void:
	var line := ("PASS  " if ok else "FAIL  ") + label + ("" if detail == "" else "  [%s]" % detail)
	_checks.append(line)
	print(line)
	if not ok:
		_failures.append(line)


func _report() -> void:
	var log_path: String = OUT_DIR.path_join("proof_log.txt")
	var f := FileAccess.open(log_path, FileAccess.WRITE)
	if f != null:
		for line in _checks:
			f.store_line(line)
		f.store_line("%d checks, %d failed" % [_checks.size(), _failures.size()])
		f.close()
	print("== runtime proof: %d checks, %d failed ==" % [_checks.size(), _failures.size()])
	get_tree().quit(0 if _failures.is_empty() else 1)
