extends Control
## Scrolling saga map: 120 campaign levels grouped by world, with progress HUD and side rail.

const NODE_SIZE := 168.0
const ROW_HEIGHT := 210.0

var scroll: ScrollContainer
var list: VBoxContainer
var coins_pill: PanelContainer
var lives_pill: PanelContainer
var _overlay: Control = null


func _ready() -> void:
	GameManager.state = GameManager.State.SAGA_MAP
	_build()
	AudioManager.play_music("bgm_map")


func _build() -> void:
	var bg := TextureRect.new()
	bg.texture = UI.tex("res://assets/map/map_bg_tile.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_TILE
	UI.full_rect(bg)
	bg.modulate = Color(0.85, 0.85, 0.95, 1)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.05, 0.09, 0.55)
	UI.full_rect(shade)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	scroll = ScrollContainer.new()
	scroll.position = Vector2(0, 200)
	scroll.size = Vector2(1080, 1560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	list = VBoxContainer.new()
	list.custom_minimum_size = Vector2(1080, 0)
	list.add_theme_constant_override("separation", 40)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	var world := 0
	for i in range(LevelLibrary.count()):
		var id := i + 1
		var w := LevelLibrary.world_of(id)
		if w != world:
			world = w
			list.add_child(_world_header(w))
		list.add_child(_level_row(id))

	_build_hud()
	await get_tree().process_frame
	_scroll_to_current()


func _world_header(world: int) -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(1080, 120)
	var l := UI.title("WORLD %d" % world, 56)
	l.size = Vector2(1080, 100)
	box.add_child(l)
	return box


func _level_row(id: int) -> Control:
	var row := Control.new()
	row.custom_minimum_size = Vector2(1080, ROW_HEIGHT)

	# winding path: alternate the node left and right so the map reads as a trail
	var offset := 200.0 if id % 4 < 2 else 1080.0 - 200.0 - NODE_SIZE
	var holder := Control.new()
	holder.position = Vector2(offset, (ROW_HEIGHT - NODE_SIZE) / 2.0)
	holder.size = Vector2(NODE_SIZE, NODE_SIZE)
	row.add_child(holder)

	var unlocked := GameManager.is_unlocked(id)
	var stars := GameManager.stars_for(id)
	var tex_name := "map_node_locked"
	if stars >= 3:
		tex_name = "map_node_done3"
	elif stars > 0:
		tex_name = "map_node_done"
	elif unlocked:
		tex_name = "map_node_current"

	var icon := TextureRect.new()
	icon.texture = UI.tex("res://assets/map/%s.png" % tex_name)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.custom_minimum_size = Vector2(NODE_SIZE, NODE_SIZE)
	icon.size = Vector2(NODE_SIZE, NODE_SIZE)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	holder.add_child(icon)

	var num := UI.label(str(id), 46, UI.INK, HORIZONTAL_ALIGNMENT_CENTER)
	num.position = Vector2(0, NODE_SIZE * 0.16)
	num.size = Vector2(NODE_SIZE, 56)
	num.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	num.add_theme_constant_override("shadow_offset_y", 3)
	holder.add_child(num)

	if stars > 0 and unlocked:
		var srow := UI.star_row(stars, 34)
		srow.position = Vector2(0, NODE_SIZE * 0.62)
		srow.size = Vector2(NODE_SIZE, 40)
		holder.add_child(srow)

	var btn := Button.new()
	btn.flat = true
	btn.size = Vector2(NODE_SIZE, NODE_SIZE)
	btn.set_meta("level_id", id)
	btn.set_meta("unlocked", unlocked)
	btn.pressed.connect(_on_level_pressed.bind(id))
	holder.add_child(btn)

	if unlocked and stars == 0 and id == GameManager.max_level():
		var tw := holder.create_tween().set_loops()
		tw.tween_property(holder, "scale", Vector2(1.08, 1.08), 0.7).set_trans(Tween.TRANS_SINE)
		tw.tween_property(holder, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_SINE)

	return row


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	UI.full_rect(root)
	layer.add_child(root)

	var top := HBoxContainer.new()
	top.position = Vector2(24, 40)
	top.size = Vector2(1032, 100)
	top.add_theme_constant_override("separation", 16)
	root.add_child(top)

	coins_pill = UI.pill("icon_coin", str(GameManager.coins()), 250)
	top.add_child(coins_pill)

	lives_pill = UI.pill("icon_heart", "%d  %s" % [GameManager.lives(), GameManager.lives_label()], 340)
	top.add_child(lives_pill)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)

	top.add_child(UI.icon_button("icon_settings", 96, _open_settings))

	var rail := VBoxContainer.new()
	rail.position = Vector2(938, 430)
	rail.size = Vector2(110, 620)
	rail.add_theme_constant_override("separation", 22)
	root.add_child(rail)
	_add_rail_button(rail, "icon_spin", "spin", func() -> void: _modal(Overlays.show_spin))
	_add_rail_button(rail, "icon_piggy", "piggy", func() -> void: _modal(Overlays.show_piggy))
	_add_rail_button(rail, "icon_shop", "store", func() -> void: _modal(Overlays.show_store))

	GameManager.lives_changed.connect(_refresh_hud)
	GameManager.wallet_changed.connect(_refresh_hud)


func _add_rail_button(rail: VBoxContainer, icon_name: String, action: String, cb: Callable) -> void:
	var b := UI.icon_button(icon_name, 96, cb)
	b.set_meta("action", action)
	rail.add_child(b)


## Used by the QA harness: presses the real rail button, not the handler behind it.
func press_rail_button(action: String) -> bool:
	for b in find_children("*", "TextureButton", true, false):
		if b.has_meta("action") and str(b.get_meta("action")) == action:
			(b as TextureButton).emit_signal("pressed")
			return true
	return false


func press_overlay_button(label: String) -> bool:
	if not has_overlay():
		return false
	for b in _overlay.find_children("*", "Button", true, false):
		if (b as Button).text == label:
			(b as Button).emit_signal("pressed")
			return true
	return false


func _process(_delta: float) -> void:
	if _overlay != null and is_instance_valid(_overlay) and _overlay.get_child_count() == 0:
		_overlay.queue_free()
		_overlay = null
	if lives_pill != null:
		UI.set_pill_text(lives_pill, "%d  %s" % [GameManager.lives(), GameManager.lives_label()])


func _refresh_hud() -> void:
	UI.set_pill_text(coins_pill, str(GameManager.coins()))
	UI.set_pill_text(lives_pill, "%d  %s" % [GameManager.lives(), GameManager.lives_label()])


func _scroll_to_current() -> void:
	var target := GameManager.max_level()
	var y := 0.0
	var world := 0
	for i in range(LevelLibrary.count()):
		var id := i + 1
		var w := LevelLibrary.world_of(id)
		if w != world:
			world = w
			y += 120.0 + 40.0
		if id == target:
			break
		y += ROW_HEIGHT + 40.0
	scroll.scroll_vertical = int(max(0.0, y - 600.0))


func _on_level_pressed(id: int) -> void:
	if not GameManager.is_unlocked(id):
		AudioManager.play("sfx_purchase_fail")
		return
	if GameManager.lives() <= 0:
		_modal(func(parent: Control) -> void: Overlays.show_out_of_lives(parent))
		return
	GameManager.start_level(id)


## Used by the QA harness and by the level buttons' own signal.
func press_level_button(level_id: int) -> bool:
	for b in find_children("*", "Button", true, false):
		if b.has_meta("level_id") and int(b.get_meta("level_id")) == level_id:
			(b as Button).emit_signal("pressed")
			return true
	return false


func has_overlay() -> bool:
	return _overlay != null and is_instance_valid(_overlay) and _overlay.get_child_count() > 0


func close_overlay() -> void:
	if has_overlay():
		_overlay.queue_free()
		_overlay = null


func _modal(fn: Callable) -> void:
	if _overlay != null and is_instance_valid(_overlay):
		return
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var holder := Control.new()
	UI.full_rect(holder)
	layer.add_child(holder)
	_overlay = holder
	fn.call(holder)


func _open_settings() -> void:
	_modal(Overlays.show_settings)


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	# back pops an overlay before it changes state
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
		_overlay = null
		return
	get_tree().quit()
