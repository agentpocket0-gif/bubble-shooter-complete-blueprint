extends Control
## Scrolling saga map: 100 nodes in 5 worlds, HUD, side rail.

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
	add_child(bg)

	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.05, 0.09, 0.55)
	UI.full_rect(shade)
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
	num.position = Vector2(0, NODE_SIZE * 0.28)
	num.size = Vector2(NODE_SIZE, 56)
	num.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	num.add_theme_constant_override("shadow_offset_y", 3)
	holder.add_child(num)

	if not unlocked:
		var lock := TextureRect.new()
		lock.texture = UI.icon("icon_lock", false)
		lock.position = Vector2(NODE_SIZE * 0.5 - 24, NODE_SIZE * 0.72)
		lock.custom_minimum_size = Vector2(48, 48)
		lock.size = Vector2(48, 48)
		lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		holder.add_child(lock)
	elif stars > 0:
		var srow := UI.star_row(stars, 40)
		srow.position = Vector2(0, NODE_SIZE - 34)
		srow.size = Vector2(NODE_SIZE, 44)
		holder.add_child(srow)

	var btn := Button.new()
	btn.flat = true
	btn.size = Vector2(NODE_SIZE, NODE_SIZE)
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
	rail.position = Vector2(940, 460)
	rail.size = Vector2(120, 620)
	rail.add_theme_constant_override("separation", 26)
	root.add_child(rail)
	rail.add_child(UI.icon_button("icon_spin", 110, func() -> void: _modal(Overlays.show_spin)))
	rail.add_child(UI.icon_button("icon_piggy", 110, func() -> void: _modal(Overlays.show_piggy)))
	rail.add_child(UI.icon_button("icon_shop", 110, func() -> void: _modal(Overlays.show_store)))
	rail.add_child(UI.icon_button("icon_gift", 110, func() -> void: _modal(Overlays.show_store)))

	GameManager.lives_changed.connect(_refresh_hud)
	GameManager.wallet_changed.connect(_refresh_hud)


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


func _modal(fn: Callable) -> void:
	if _overlay != null and is_instance_valid(_overlay):
		return
	var holder := Control.new()
	UI.full_rect(holder)
	add_child(holder)
	_overlay = holder
	fn.call(holder)


func _open_settings() -> void:
	_modal(Overlays.show_settings)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()
