extends Node2D
## The level: hex board, cannon, aim preview, matching, boosters, HUD.
##
## Simulation runs in board space (ceiling y = 0, cannon y = 1450); everything
## is drawn with OFFSET_Y added, so the maths is identical to the Python level
## generator and to the headless tests.

const OFFSET_Y := 230.0
const CANNON_POS := Vector2(540.0, 1450.0)
const SPEED := 2600.0
const COLOUR_NAMES := ["red", "blue", "green", "yellow", "purple", "orange"]
const FLOOR_Y := 1520.0   # board space: where a dropped bubble bounces

enum Phase { AIM, FLYING, RESOLVING, DONE }

var level: Dictionary = {}
var board: HexBoard
var palette: Array = []
var rng: Rng32

var shots_left := 0
var score := 0
var popped_total := 0
var freed_total := 0
var shots_taken := 0
var phase: int = Phase.AIM

var current_colour := 0
var next_colour := 0
var aim_angle := 0.0
var dragging := false
var pending_booster := ""
var laser_armed := false

# nodes
var board_layer: Node2D
var fx_layer: Node2D
var aim: AimLine
var ghost: Sprite2D
var projectile: Sprite2D
var next_preview: Sprite2D
var loaded: Sprite2D
var cannon_base: Sprite2D
var cannon_barrel: Sprite2D
var hud: CanvasLayer
var hud_root: Control
var coins_pill: PanelContainer
var lives_pill: PanelContainer
var shots_pill: PanelContainer
var score_label: Label
var objective_label: Label
var booster_row: HBoxContainer
var pause_overlay: Control

var _cell_sprites: Dictionary = {}
var _falling: Array = []
var _flight_path := PackedVector2Array()
var _flight_t := 0.0
var _flight_len := 0.0
var _landing_cell := Vector2i(-1, -1)
var _combo := 0
var _pop_frames_cache: Dictionary = {}
var _floor_bonus := 0


func _ready() -> void:
	level = LevelLibrary.load_level(GameManager.current_level_id)
	if level.is_empty():
		push_error("Gameplay: level %d failed to load" % GameManager.current_level_id)
		GameManager.open_map()
		return
	palette = level.get("palette", ["red", "blue", "green"])
	board = HexBoard.new(int(level["grid"]["cols"]), int(level["grid"]["rows"]))
	board.load_layout(level["layout"], palette.size(), level.get("blockers", []))
	shots_left = int(level["shots"])
	if GameManager.pending_bonus_shots > 0:
		shots_left += GameManager.pending_bonus_shots
		GameManager.pending_bonus_shots = 0
	rng = Rng32.new(Rng32.seed_for(int(level["id"]), GameManager.attempt_index))

	_build_scene()
	_refill_queue()
	_refresh_board_visuals()
	_refresh_hud()
	AudioManager.play_music("bgm_game")


# --------------------------------------------------------------------------- #
# scene construction
# --------------------------------------------------------------------------- #
func _build_scene() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#12121A")
	bg.size = Vector2(1080, 1920)
	bg.z_index = -10
	add_child(bg)

	board_layer = Node2D.new()
	board_layer.position = Vector2(0, OFFSET_Y)
	add_child(board_layer)

	fx_layer = Node2D.new()
	fx_layer.position = Vector2(0, OFFSET_Y)
	add_child(fx_layer)

	aim = AimLine.new()
	aim.offset = Vector2(0, OFFSET_Y)
	aim.z_index = 5
	add_child(aim)

	ghost = Sprite2D.new()
	ghost.visible = false
	ghost.modulate = Color(1, 1, 1, 0.35)
	ghost.z_index = 4
	add_child(ghost)

	cannon_base = Sprite2D.new()
	cannon_base.texture = UI.tex("res://assets/cannon/cannon_base.png")
	cannon_base.position = CANNON_POS + Vector2(0, OFFSET_Y)
	cannon_base.scale = Vector2(0.9, 0.9)
	add_child(cannon_base)

	cannon_barrel = Sprite2D.new()
	cannon_barrel.texture = UI.tex("res://assets/cannon/cannon_barrel.png")
	cannon_barrel.position = CANNON_POS + Vector2(0, OFFSET_Y - 70)
	cannon_barrel.offset = Vector2(0, -60)
	cannon_barrel.scale = Vector2(0.8, 0.8)
	add_child(cannon_barrel)

	projectile = Sprite2D.new()
	projectile.visible = false
	projectile.z_index = 6
	add_child(projectile)

	# the bubble actually sitting in the cannon: without this the player cannot
	# see what they are about to fire
	loaded = Sprite2D.new()
	loaded.position = CANNON_POS + Vector2(0, OFFSET_Y - 34)
	loaded.z_index = 3
	add_child(loaded)

	next_preview = Sprite2D.new()
	next_preview.position = CANNON_POS + Vector2(-190, -20 + OFFSET_Y)
	next_preview.scale = Vector2(0.5, 0.5)
	next_preview.modulate = Color(1, 1, 1, 0.85)
	add_child(next_preview)

	var next_tag := Label.new()
	next_tag.text = "NEXT"
	next_tag.add_theme_font_size_override("font_size", 22)
	next_tag.add_theme_color_override("font_color", UI.MUTED)
	next_tag.position = CANNON_POS + Vector2(-226, 40 + OFFSET_Y)
	add_child(next_tag)

	_build_hud()


func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	hud_root = Control.new()
	UI.full_rect(hud_root)
	hud.add_child(hud_root)

	var top := HBoxContainer.new()
	top.position = Vector2(24, 24)
	top.size = Vector2(1032, 100)
	top.add_theme_constant_override("separation", 16)
	hud_root.add_child(top)

	coins_pill = UI.pill("icon_coin", str(GameManager.coins()), 250)
	top.add_child(coins_pill)

	shots_pill = UI.pill("icon_play", str(shots_left), 200)
	top.add_child(shots_pill)

	var badge := UI.label("LEVEL %d" % int(level["id"]), 34, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(badge)

	var pause := UI.icon_button("icon_pause", 96, _toggle_pause)
	top.add_child(pause)

	score_label = UI.label("0", 34, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	score_label.position = Vector2(0, 128)
	score_label.size = Vector2(1080, 40)
	hud_root.add_child(score_label)

	objective_label = UI.label(_objective_status_text(), 27, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	objective_label.position = Vector2(70, 168)
	objective_label.size = Vector2(940, 46)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	hud_root.add_child(objective_label)

	# tap the "next" slot to swap: it has to live on the HUD canvas, not the
	# 2D scene, so it gets touch input
	var swap_btn := Button.new()
	swap_btn.flat = true
	swap_btn.set_meta("action", "swap_tap")
	swap_btn.position = CANNON_POS + Vector2(-250, -80 + OFFSET_Y)
	swap_btn.size = Vector2(120, 120)
	swap_btn.pressed.connect(_tap_swap)
	hud_root.add_child(swap_btn)

	booster_row = HBoxContainer.new()
	booster_row.position = Vector2(80, 1800)
	booster_row.size = Vector2(920, 120)
	booster_row.add_theme_constant_override("separation", 26)
	booster_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hud_root.add_child(booster_row)
	_rebuild_boosters()


func _rebuild_boosters() -> void:
	for c in booster_row.get_children():
		c.queue_free()
	for kind in ["swap", "laser", "bomb", "rainbow", "extra_moves"]:
		var b := TextureButton.new()
		b.texture_normal = UI.tex("res://assets/boosters/booster_%s.png" % ("extra_moves" if kind == "extra_moves" else kind))
		b.ignore_texture_size = true
		b.custom_minimum_size = Vector2(104, 104)
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		var count := GameManager.booster_count(kind)
		b.modulate = Color(1, 1, 1, 1) if count > 0 else Color(1, 1, 1, 0.35)
		var badge := UI.label(str(count), 34, UI.INK, HORIZONTAL_ALIGNMENT_CENTER)
		badge.position = Vector2(66, 66)
		badge.size = Vector2(40, 36)
		badge.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		badge.add_theme_constant_override("shadow_offset_y", 3)
		b.add_child(badge)
		b.pressed.connect(_on_booster_pressed.bind(kind))
		booster_row.add_child(b)


# --------------------------------------------------------------------------- #
# rendering
# --------------------------------------------------------------------------- #
func _bubble_texture(colour: int) -> Texture2D:
	if colour < 0 or colour >= COLOUR_NAMES.size():
		return UI.tex("res://assets/bubbles/bubble_ghost.png")
	return UI.tex("res://assets/bubbles/bubble_%s_idle.png" % COLOUR_NAMES[colour])


func _refresh_board_visuals() -> void:
	for s in _cell_sprites.values():
		(s as Node).queue_free()
	_cell_sprites.clear()
	for r in board.rows:
		for q in board.row_len(r):
			if not board.filled(q, r):
				continue
			_add_cell_sprite(q, r)


func _add_cell_sprite(q: int, r: int) -> void:
	var key := Vector2i(q, r)
	if _cell_sprites.has(key):
		(_cell_sprites[key] as Node).queue_free()
	var node := Node2D.new()
	node.position = board.centre(q, r)
	var blk := board.blocker_at(q, r)
	var col := board.colour_at(q, r)
	var s := Sprite2D.new()
	if blk == HexBoard.B_STONE:
		s.texture = UI.tex("res://assets/blockers/blocker_stone.png")
	else:
		s.texture = _bubble_texture(col)
	node.add_child(s)
	if blk == HexBoard.B_ICE:
		var o := Sprite2D.new()
		o.texture = UI.tex("res://assets/blockers/blocker_ice_0%d.png" % clampi(board.hp_at(q, r), 1, 3))
		o.modulate = Color(1, 1, 1, 0.9)
		node.add_child(o)
	elif blk == HexBoard.B_CHAIN:
		var c := Sprite2D.new()
		c.texture = UI.tex("res://assets/blockers/blocker_chain.png")
		node.add_child(c)
	board_layer.add_child(node)
	_cell_sprites[key] = node


func _set_cannon_sprite(colour: int) -> void:
	projectile.texture = _bubble_texture(colour)
	if loaded != null:
		loaded.texture = _bubble_texture(colour)
		loaded.visible = true


# --------------------------------------------------------------------------- #
# colour queue
# --------------------------------------------------------------------------- #
func _pick_colour() -> int:
	# Never hand the player a colour that is not on the board: that is the
	# single most rage-inducing bug in this genre.
	var present := board.colours_present()
	if present.is_empty():
		return rng.next_range(palette.size())
	return present[rng.next_range(present.size())]


func _refill_queue() -> void:
	current_colour = _pick_colour()
	next_colour = _pick_colour()
	_set_cannon_sprite(current_colour)
	if next_preview != null:
		next_preview.texture = _bubble_texture(next_colour)


# --------------------------------------------------------------------------- #
# input
# --------------------------------------------------------------------------- #
func _unhandled_input(event: InputEvent) -> void:
	if phase != Phase.AIM or pause_overlay != null:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			dragging = true
			_aim_at(t.position)
		elif dragging:
			dragging = false
			_shoot()
	elif event is InputEventScreenDrag:
		_aim_at((event as InputEventScreenDrag).position)
	elif event is InputEventMouseButton:
		var m := event as InputEventMouseButton
		if m.button_index == MOUSE_BUTTON_LEFT:
			if m.pressed:
				dragging = true
				_aim_at(m.position)
			elif dragging:
				dragging = false
				_shoot()
	elif event is InputEventMouseMotion and dragging:
		_aim_at((event as InputEventMouseMotion).position)


func _aim_at(screen_pos: Vector2) -> void:
	var local := screen_pos - (CANNON_POS + Vector2(0, OFFSET_Y))
	if local.y > -20.0:
		local.y = -20.0
	aim_angle = ShotSimulator.clamp_angle(atan2(local.x, -local.y))
	cannon_barrel.rotation = aim_angle
	_update_preview()


func _update_preview() -> void:
	var tr := ShotSimulator.trace(board, aim_angle)
	aim.points = tr.points
	aim.queue_redraw()
	if tr.valid:
		ghost.visible = true
		ghost.texture = _bubble_texture(current_colour)
		ghost.position = board.centre(tr.cell.x, tr.cell.y) + Vector2(0, OFFSET_Y)
		_landing_cell = tr.cell
	else:
		ghost.visible = false
		_landing_cell = Vector2i(-1, -1)


# --------------------------------------------------------------------------- #
# shooting
# --------------------------------------------------------------------------- #
func _shoot() -> void:
	if phase != Phase.AIM:
		return
	var tr := ShotSimulator.trace(board, aim_angle)
	if not tr.valid:
		_shake_hud()
		return
	phase = Phase.FLYING
	aim.visible_line = false
	aim.queue_redraw()
	ghost.visible = false
	_flight_path = tr.points
	_flight_t = 0.0
	_flight_len = 0.0
	for i in range(1, _flight_path.size()):
		_flight_len += _flight_path[i].distance_to(_flight_path[i - 1])
	_landing_cell = tr.cell
	projectile.visible = true
	projectile.texture = _bubble_texture(current_colour)
	if loaded != null:
		loaded.visible = false
	projectile.position = _flight_path[0] + Vector2(0, OFFSET_Y)
	projectile.scale = Vector2.ONE
	AudioManager.play("sfx_shot")


func _process(delta: float) -> void:
	if phase == Phase.FLYING:
		_flight_t += delta * SPEED
		var remaining := _flight_t
		var pos := _flight_path[0]
		for i in range(1, _flight_path.size()):
			var seg := _flight_path[i].distance_to(_flight_path[i - 1])
			if remaining <= seg:
				pos = _flight_path[i - 1].lerp(_flight_path[i], remaining / max(seg, 0.001))
				break
			remaining -= seg
			pos = _flight_path[i]
		projectile.position = pos + Vector2(0, OFFSET_Y)
		if _flight_t >= _flight_len:
			_resolve_shot()
	_update_falling(delta)


func _update_falling(delta: float) -> void:
	var dead: Array = []
	for body in _falling:
		var node: Node2D = body["node"]
		body["vy"] += 2600.0 * delta
		node.position += Vector2(body["vx"] * delta, body["vy"] * delta)
		node.rotation += body["spin"] * delta
		# bounce off the floor once or twice, paying a small bonus each time
		if node.position.y > FLOOR_Y and body["vy"] > 0.0:
			node.position.y = FLOOR_Y
			body["vy"] = -body["vy"] * 0.45
			body["vx"] *= 0.7
			body["bounces"] = int(body.get("bounces", 0)) + 1
			_floor_bonus += 5
			score += 5
			AudioManager.play("sfx_drop_land", 1.0, -6.0)
			_refresh_hud()
			if int(body["bounces"]) >= 3:
				body["vy"] = 0.0
				body["vx"] = 0.0
		if node.position.y > 1920.0 + 100.0:
			dead.append(body)
	for body in dead:
		(body["node"] as Node).queue_free()
		_falling.erase(body)


# --------------------------------------------------------------------------- #
# resolution
# --------------------------------------------------------------------------- #
func _resolve_shot() -> void:
	phase = Phase.RESOLVING
	projectile.visible = false
	shots_taken += 1
	shots_left -= 1

	var cell := _landing_cell
	if cell.x < 0:
		_lose("no space")
		return

	board.set_cell(cell.x, cell.y, current_colour)
	_add_cell_sprite(cell.x, cell.y)

	var popped: Array[Vector2i] = []
	var cluster := board.find_cluster(cell.x, cell.y)
	var forced := false
	if pending_booster == "bomb":
		cluster = _blast_radius(cell.x, cell.y, 1)
		pending_booster = ""
		forced = true
	elif pending_booster == "rainbow":
		cluster = _rainbow_cluster(cell.x, cell.y)
		pending_booster = ""
		forced = true

	if forced or cluster.size() >= 3:
		if cluster.size() >= 6:
			AudioManager.play("sfx_cluster_big")
		popped = _pop_cells(cluster)

	var freed := _free_chains(popped)
	freed_total += freed

	var floating := board.find_floating()
	if not floating.is_empty():
		_drop_cells(floating)
		AudioManager.play("sfx_drop_start")

	var n := popped.size()
	var gained := int(round(10.0 * n * (1.0 + 0.25 * max(0, n - 3)) + 20.0 * floating.size()))
	score += gained
	popped_total += n
	GameManager.add_stat("bubblesPopped", n)
	AudioManager.haptic(12 if n < 5 else 30)
	_refresh_hud()

	await get_tree().create_timer(0.28).timeout

	if _survive_failed():
		_lose("board reached danger line")
		return
	if _objective_met():
		_win()
		return
	if shots_left <= 0:
		_lose("out of shots")
		return
	if _board_jammed():
		_lose("no space")
		return

	if _should_ceiling_drop():
		_ceiling_drop()

	_refill_queue()
	phase = Phase.AIM
	aim.visible_line = true
	aim.queue_redraw()
	_update_preview()


func _pop_cells(cells: Array) -> Array[Vector2i]:
	var popped: Array[Vector2i] = []
	var step := 0
	for c in cells:
		var cell: Vector2i = c
		if not board.filled(cell.x, cell.y):
			continue
		if board.blocker_at(cell.x, cell.y) == HexBoard.B_ICE and board.hp_at(cell.x, cell.y) > 1:
			board.hp[cell.y * board.cols + cell.x] -= 1
			_add_cell_sprite(cell.x, cell.y)
			AudioManager.play("sfx_blocker_crack")
			continue
		var col := board.colour_at(cell.x, cell.y)
		board.clear_cell(cell.x, cell.y)
		popped.append(cell)
		_animate_pop(cell, col, step)
		step += 1
	return popped


func _pop_frames(colour: int) -> SpriteFrames:
	if _pop_frames_cache.has(colour):
		return _pop_frames_cache[colour]
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("pop")
	sf.set_animation_speed("pop", 20.0)
	sf.set_animation_loop("pop", false)
	var cname: String = COLOUR_NAMES[clampi(colour, 0, COLOUR_NAMES.size() - 1)]
	for i in 8:
		var path := "res://assets/bubbles/pop/bubble_%s_pop_%02d.png" % [cname, i]
		if ResourceLoader.exists(path):
			sf.add_frame("pop", load(path))
	_pop_frames_cache[colour] = sf
	return sf


func _animate_pop(cell: Vector2i, colour: int, step: int) -> void:
	AudioManager.play_pop(step)
	var node: Node2D = _cell_sprites.get(cell, null)
	if node != null:
		_cell_sprites.erase(cell)
		node.queue_free()
	# frame-by-frame pop from the sliced sprite set, not a scale tween
	var anim := AnimatedSprite2D.new()
	anim.sprite_frames = _pop_frames(colour)
	anim.position = board.centre(cell.x, cell.y)
	anim.z_index = 2
	fx_layer.add_child(anim)
	anim.play("pop")
	anim.animation_finished.connect(anim.queue_free)
	_spawn_particles(cell)


func _spawn_particles(cell: Vector2i) -> void:
	var origin := board.centre(cell.x, cell.y)
	for i in 6:
		var dot := Sprite2D.new()
		dot.texture = UI.tex("res://assets/fx/fx_particle_dot.png")
		dot.position = origin
		dot.scale = Vector2(0.6, 0.6)
		fx_layer.add_child(dot)
		var dir := Vector2.from_angle(randf() * TAU) * randf_range(120.0, 380.0)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(dot, "position", origin + dir, 0.35)
		tw.tween_property(dot, "modulate:a", 0.0, 0.35)
		tw.chain().tween_callback(dot.queue_free)


func _drop_cells(cells: Array) -> void:
	for c in cells:
		var cell: Vector2i = c
		var node: Node2D = _cell_sprites.get(cell, null)
		if node != null:
			_cell_sprites.erase(cell)
			_falling.append({
				"node": node,
				"vx": randf_range(-120.0, 120.0),
				"vy": randf_range(-60.0, 60.0),
				"spin": deg_to_rad(randf_range(-240.0, 240.0)),
				"bounces": 0,
			})
		board.clear_cell(cell.x, cell.y)
	AudioManager.play("sfx_drop_land")


func _free_chains(popped: Array) -> int:
	var freed := 0
	for c in popped:
		var cell: Vector2i = c
		for n in board.neighbours(cell.x, cell.y):
			if board.blocker_at(n.x, n.y) == HexBoard.B_CHAIN:
				board.blocker[n.y * board.cols + n.x] = HexBoard.B_NONE
				_add_cell_sprite(n.x, n.y)
				freed += 1
	if freed > 0:
		AudioManager.play("sfx_chain_break")
	return freed


func _blast_radius(q: int, r: int, radius: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var origin := board.centre(q, r)
	for rr in range(maxi(0, r - radius), mini(board.rows, r + radius + 1)):
		for qq in board.row_len(rr):
			if not board.filled(qq, rr):
				continue
			if board.centre(qq, rr).distance_to(origin) <= HexBoard.D * (radius + 0.55):
				out.append(Vector2i(qq, rr))
	AudioManager.play("sfx_booster_bomb")
	return out


func _rainbow_cluster(q: int, r: int) -> Array[Vector2i]:
	# The rainbow bubble takes the colour of the first bubble it touches, then
	# pops every bubble of that colour.
	var target := -1
	for n in board.neighbours(q, r):
		if board.filled(n.x, n.y) and board.colour_at(n.x, n.y) >= 0:
			target = board.colour_at(n.x, n.y)
			break
	var out: Array[Vector2i] = [Vector2i(q, r)]
	if target < 0:
		return out
	for rr in board.rows:
		for qq in board.row_len(rr):
			if board.colour_at(qq, rr) == target and board.blocker_at(qq, rr) != HexBoard.B_CHAIN:
				out.append(Vector2i(qq, rr))
	AudioManager.play("sfx_booster_rainbow")
	return out


func _board_jammed() -> bool:
	# no angle produces a legal landing cell
	for i in 15:
		var angle := lerpf(-deg_to_rad(75.0), deg_to_rad(75.0), float(i) / 14.0)
		if ShotSimulator.trace(board, angle).valid:
			return false
	return true


func _should_ceiling_drop() -> bool:
	var every := int(level.get("ceilingDropEvery", 0))
	return every > 0 and shots_taken > 0 and shots_taken % every == 0


func _ceiling_drop() -> void:
	# Drop two rows at a time so row parity (and therefore the inset geometry)
	# is preserved.
	var nb := HexBoard.new(board.cols, board.rows)
	for r in range(board.rows - 3, -1, -1):
		for q in board.row_len(r):
			if board.filled(q, r):
				nb.set_cell(q, r + 2, board.colour_at(q, r), board.blocker_at(q, r), board.hp_at(q, r))
	var present := board.colours_present()
	for r in range(2):
		for q in nb.row_len(r):
			var col: int = present[rng.next_range(present.size())] if not present.is_empty() else 0
			nb.set_cell(q, r, col)
	board = nb
	_refresh_board_visuals()
	AudioManager.play("sfx_ceiling_drop")
	AudioManager.haptic(30)


# --------------------------------------------------------------------------- #
# objectives
# --------------------------------------------------------------------------- #
func _has_survive_objective() -> bool:
	for obj in level.get("objectives", []):
		if str(obj.get("type", "")) == "survive":
			return true
	return false


func _survive_failed() -> bool:
	return _has_survive_objective() and board.max_row_used() >= board.rows - 1


func _objective_met() -> bool:
	for obj in level.get("objectives", []):
		var t := str(obj.get("type", "clear_all"))
		match t:
			"clear_all":
				if board.coloured_count() > 1:
					return false
			"clear_color":
				var target := str(obj.get("color", "red"))
				var idx := palette.find(target)
				for r in board.rows:
					for q in board.row_len(r):
						if board.colour_at(q, r) == idx:
							return false
			"pop_count":
				if popped_total < int(obj.get("count", 0)):
					return false
			"rescue":
				if freed_total < int(obj.get("count", 0)):
					return false
			"score":
				if score < int(obj.get("target", 0)):
					return false
			"survive":
				if shots_taken < int(obj.get("shots", 0)) or _survive_failed():
					return false
	return true


func _objective_status_text() -> String:
	var objectives: Array = level.get("objectives", [])
	if objectives.is_empty():
		return "CLEAR ALL BUBBLES"
	var obj: Dictionary = objectives[0]
	match str(obj.get("type", "clear_all")):
		"clear_all":
			return "CLEAR ALL BUBBLES"
		"clear_color":
			return "CLEAR %s BUBBLES" % str(obj.get("color", "red")).to_upper()
		"pop_count":
			return "POP %d / %d BUBBLES" % [popped_total, int(obj.get("count", 0))]
		"rescue":
			return "FREE %d / %d CHAINS" % [freed_total, int(obj.get("count", 0))]
		"score":
			return "SCORE %d / %d" % [score, int(obj.get("target", 0))]
		"survive":
			var required := int(obj.get("shots", 0))
			return "SURVIVE %d / %d SHOTS" % [mini(shots_taken, required), required]
	return "CLEAR ALL BUBBLES"


func _compute_stars() -> int:
	var s: Dictionary = level.get("stars", {})
	if score >= int(s.get("3", 3000)):
		return 3
	if score >= int(s.get("2", 2000)):
		return 2
	if score >= int(s.get("1", 1000)):
		return 1
	return 1


func _win() -> void:
	if phase == Phase.DONE:
		return
	phase = Phase.DONE
	AudioManager.play("sfx_level_win")
	var stars := _compute_stars()
	var first_clear := GameManager.stars_for(int(level["id"])) == 0
	var rewards: Dictionary = level.get("rewards", {})
	var coins := int(rewards.get("coins", 40))
	if first_clear:
		coins += int(rewards.get("firstClearBonus", 100))
	GameManager.add_coins(coins)
	StoreAndEconomy.add_piggy_fill(25)
	await get_tree().create_timer(0.5).timeout
	GameManager.finish_level(true, {
		"stars": stars,
		"score": score,
		"coins": coins,
		"popped": popped_total,
		"first_clear": first_clear,
		"shots_left": shots_left,
	})


func _lose(reason: String) -> void:
	if phase == Phase.DONE:
		return
	phase = Phase.DONE
	AudioManager.play("sfx_level_fail")
	await get_tree().create_timer(0.4).timeout
	GameManager.finish_level(false, {
		"stars": 0,
		"score": score,
		"coins": 0,
		"popped": popped_total,
		"reason": reason,
	})


# --------------------------------------------------------------------------- #
# HUD
# --------------------------------------------------------------------------- #
func _refresh_hud() -> void:
	if coins_pill != null:
		UI.set_pill_text(coins_pill, str(GameManager.coins()))
	if shots_pill != null:
		UI.set_pill_text(shots_pill, str(maxi(0, shots_left)))
	if score_label != null:
		score_label.text = "%d" % score
	if objective_label != null:
		objective_label.text = _objective_status_text()


func _shake_hud() -> void:
	var tw := create_tween()
	tw.tween_property(hud_root, "position", Vector2(12, 0), 0.05)
	tw.tween_property(hud_root, "position", Vector2(-12, 0), 0.05)
	tw.tween_property(hud_root, "position", Vector2.ZERO, 0.05)


# --------------------------------------------------------------------------- #
# boosters
# --------------------------------------------------------------------------- #
## Tapping the "next" slot swaps the two bubbles for free. The swap booster
## still exists for players who want to spend coins on it from the bar.
func _tap_swap() -> void:
	if phase != Phase.AIM:
		return
	var tmp := current_colour
	current_colour = next_colour
	next_colour = tmp
	_set_cannon_sprite(current_colour)
	next_preview.texture = _bubble_texture(next_colour)
	AudioManager.play("sfx_booster_swap")
	var tw := create_tween()
	tw.tween_property(next_preview, "scale", Vector2(0.62, 0.62), 0.08)
	tw.tween_property(next_preview, "scale", Vector2(0.5, 0.5), 0.08)
	_update_preview()


func _on_booster_pressed(kind: String) -> void:
	if phase != Phase.AIM:
		return
	if GameManager.booster_count(kind) <= 0:
		AudioManager.play("sfx_purchase_fail")
		return
	match kind:
		"swap":
			GameManager.take_booster("swap")
			var tmp := current_colour
			current_colour = next_colour
			next_colour = tmp
			_set_cannon_sprite(current_colour)
			next_preview.texture = _bubble_texture(next_colour)
			AudioManager.play("sfx_booster_swap")
			_update_preview()
		"extra_moves":
			GameManager.take_booster("extra_moves")
			shots_left += 5
			AudioManager.play("sfx_booster_extra_moves")
		"bomb":
			GameManager.take_booster("bomb")
			pending_booster = "bomb"
			AudioManager.play("sfx_booster_bomb")
		"rainbow":
			GameManager.take_booster("rainbow")
			pending_booster = "rainbow"
			AudioManager.play("sfx_booster_rainbow")
		"laser":
			GameManager.take_booster("laser")
			laser_armed = true
			AudioManager.play("sfx_booster_laser")
			_show_laser_marker()
	_rebuild_boosters()
	_refresh_hud()


func _show_laser_marker() -> void:
	if _landing_cell.x < 0:
		return
	var ring := Sprite2D.new()
	ring.texture = UI.tex("res://assets/fx/fx_shockwave.png")
	ring.position = board.centre(_landing_cell.x, _landing_cell.y)
	ring.modulate = Color(1.0, 0.85, 0.3, 0.85)
	fx_layer.add_child(ring)
	var tw := create_tween()
	tw.tween_property(ring, "scale", Vector2(1.4, 1.4), 0.5)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.5)
	tw.tween_callback(ring.queue_free)


# --------------------------------------------------------------------------- #
# pause
# --------------------------------------------------------------------------- #
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and pause_overlay == null:
		_toggle_pause()


func _toggle_pause() -> void:
	if pause_overlay != null:
		pause_overlay.queue_free()
		pause_overlay = null
		get_tree().paused = false
		return
	get_tree().paused = true
	pause_overlay = Control.new()
	UI.full_rect(pause_overlay)
	pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	hud_root.add_child(pause_overlay)
	pause_overlay.add_child(UI.scrim())

	var panel := UI.popup(760)
	panel.position = Vector2(160, 700)
	pause_overlay.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 28)
	panel.add_child(col)
	col.add_child(UI.title("PAUSED", 64))
	var resume := UI.button("Resume", true)
	resume.pressed.connect(_toggle_pause)
	col.add_child(resume)
	var restart := UI.button("Restart", false)
	restart.pressed.connect(func() -> void:
		get_tree().paused = false
		GameManager.retry_level())
	col.add_child(restart)
	var quit := UI.button("Quit to map", false)
	quit.pressed.connect(func() -> void:
		get_tree().paused = false
		GameManager.open_map())
	col.add_child(quit)
