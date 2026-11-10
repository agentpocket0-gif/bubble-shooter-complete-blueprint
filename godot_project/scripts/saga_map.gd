extends Control

const PathDrawer = preload("res://scripts/map_path_drawer.gd")
const MODE_NAMES := {"classic": "CLASSIC", "hard": "HARD LEVELS", "challenge": "CHALLENGE"}
const WORLD_COUNT := 6
const LEVELS_PER_WORLD := 100

var popup_layer: Control
var coin_label: Label
var lives_label: Label
var life_timer: Label
var world_label: Label
var world_buttons: Array[Button] = []
var scroll: ScrollContainer
var path: Control
var selected_world := 1

func _ready() -> void:
    var unlocked := GameState.get_mode_unlocked_level()
    selected_world = clampi(int((unlocked - 1) / LEVELS_PER_WORLD) + 1, 1, WORLD_COUNT)
    await _build_map()

func _build_map() -> void:
    var bg := TextureRect.new()
    bg.texture = AssetRegistry.ui("background")
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    bg.stretch_mode = TextureRect.STRETCH_SCALE
    add_child(bg)

    var header := Panel.new()
    header.position = Vector2(12, 12)
    header.size = Vector2(516, 124)
    var header_style := StyleBoxFlat.new()
    header_style.bg_color = Color("#0d2855")
    header_style.border_color = Color("#7fdfff")
    header_style.set_border_width_all(2)
    header_style.set_corner_radius_all(22)
    header.add_theme_stylebox_override("panel", header_style)
    add_child(header)

    header.add_child(_label("BUBBLE BAY", Vector2(20, 16), Vector2(250, 42), 28, Color("#fff0a8")))
    var mode_button := Button.new()
    mode_button.text = str(MODE_NAMES.get(GameState.game_mode, "CLASSIC")) + "  ▾"
    mode_button.position = Vector2(280, 14)
    mode_button.size = Vector2(215, 44)
    _style_button(mode_button, true)
    mode_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ModeSelect.tscn"))
    header.add_child(mode_button)

    coin_label = _label("COINS  %d" % GameState.coins, Vector2(20, 73), Vector2(178, 30), 16, Color("#ffe28a"))
    header.add_child(coin_label)
    lives_label = _label("LIVES  %d / 5" % GameState.lives, Vector2(214, 73), Vector2(145, 30), 16, Color("#ffb7c7"))
    header.add_child(lives_label)
    life_timer = _label(_life_timer_text(), Vector2(354, 75), Vector2(145, 26), 12, Color("#c8e7ff"))
    header.add_child(life_timer)

    world_label = _label("", Vector2(20, 145), Vector2(490, 28), 15, Color("#c8edff"))
    add_child(world_label)

    var world_picker := HBoxContainer.new()
    world_picker.position = Vector2(12, 176)
    world_picker.size = Vector2(516, 52)
    world_picker.add_theme_constant_override("separation", 5)
    add_child(world_picker)
    for world_index in range(1, WORLD_COUNT + 1):
        var world_button := Button.new()
        world_button.text = "WORLD %d" % world_index
        world_button.custom_minimum_size = Vector2(78, 48)
        world_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        world_button.add_theme_font_size_override("font_size", 11)
        world_button.pressed.connect(_select_world.bind(world_index))
        world_picker.add_child(world_button)
        world_buttons.append(world_button)

    scroll = ScrollContainer.new()
    scroll.position = Vector2(12, 236)
    scroll.size = Vector2(516, 600)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    add_child(scroll)

    var bottom := HBoxContainer.new()
    bottom.position = Vector2(8, 850)
    bottom.size = Vector2(524, 82)
    bottom.add_theme_constant_override("separation", 5)
    add_child(bottom)
    _add_nav_button(bottom, "SPIN", qa_open_spin)
    _add_nav_button(bottom, "PIGGY", qa_open_piggy)
    _add_nav_button(bottom, "EVENTS", qa_open_events)
    _add_nav_button(bottom, "SHOP", qa_open_store)
    _add_nav_button(bottom, "SETTINGS", qa_open_settings)

    await _rebuild_level_path(true)

func _select_world(world_index: int) -> void:
    selected_world = clampi(world_index, 1, WORLD_COUNT)
    await _rebuild_level_path(false)

func _rebuild_level_path(initial_load: bool) -> void:
    if path != null and is_instance_valid(path):
        path.queue_free()
        await get_tree().process_frame

    var unlocked_level := GameState.get_mode_unlocked_level()
    var first_level := (selected_world - 1) * LEVELS_PER_WORLD + 1
    var last_level := selected_world * LEVELS_PER_WORLD
    var world_unlocked := unlocked_level >= first_level
    var cleared := clampi(unlocked_level - first_level, 0, LEVELS_PER_WORLD)
    world_label.text = "WORLD %d  •  LEVELS %03d–%03d  •  %d / 100 CLEARED" % [
        selected_world, first_level, last_level, cleared
    ]

    for index in range(world_buttons.size()):
        var world_index := index + 1
        _style_world_button(world_buttons[index], world_index == selected_world,
            world_index == 1 or unlocked_level >= (world_index - 1) * LEVELS_PER_WORLD + 1)

    path = PathDrawer.new()
    path.name = "WorldLevelPath"
    path.custom_minimum_size = Vector2(500, 55.0 + 92.0 * LEVELS_PER_WORLD)
    path.size = path.custom_minimum_size
    scroll.add_child(path)

    for local_level in range(1, LEVELS_PER_WORLD + 1):
        var level_id := first_level + local_level - 1
        var stars_count := GameState.get_mode_stars(level_id)
        var unlocked := level_id <= unlocked_level
        var button := Button.new()
        button.text = str(local_level) + ("\n" + "★".repeat(stars_count) if stars_count > 0 else "")
        button.position = path.node_position(local_level) - Vector2(34, 34)
        button.custom_minimum_size = Vector2(68, 68)
        button.size = Vector2(68, 68)
        button.disabled = not unlocked
        button.add_theme_font_size_override("font_size", 14)
        _style_node(button, level_id == unlocked_level, not unlocked, stars_count)
        button.pressed.connect(_on_level_pressed.bind(level_id))
        path.add_child(button)

    await get_tree().process_frame
    if scroll != null and is_instance_valid(scroll):
        var local_current := clampi(unlocked_level - first_level + 1, 1, LEVELS_PER_WORLD)
        scroll.scroll_vertical = int(path.node_position(local_current).y - scroll.size.y * 0.45) if initial_load and world_unlocked else 0

func _process(_delta: float) -> void:
    if life_timer != null:
        life_timer.text = _life_timer_text()
    if lives_label != null:
        lives_label.text = "LIVES  %d / 5" % GameState.lives

func _life_timer_text() -> String:
    if GameState.lives >= GameState.MAX_LIVES:
        return "LIVES FULL"
    var seconds := GameState.life_seconds_remaining()
    return "NEXT LIFE  %02d:%02d" % [int(seconds / 60), seconds % 60]

func _add_nav_button(parent: HBoxContainer, title_text: String, action: Callable) -> void:
    var button := Button.new()
    button.text = title_text
    button.icon = AssetRegistry.ui_icon(title_text.to_lower())
    button.icon_max_width = 22
    button.custom_minimum_size = Vector2(96, 68)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _style_button(button, title_text == "SHOP")
    button.pressed.connect(action)
    parent.add_child(button)

func _label(value: String, position_value: Vector2, size_value: Vector2, font_size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = value
    label.position = position_value
    label.size = size_value
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    return label

func _style_button(button: Button, highlighted: bool) -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#2471a7") if highlighted else Color("#16466f")
    style.border_color = Color("#9eeaff")
    style.set_border_width_all(2)
    style.set_corner_radius_all(16)
    style.shadow_color = Color(0, 0, 0, 0.22)
    style.shadow_size = 3
    button.add_theme_stylebox_override("normal", style)
    button.add_theme_color_override("font_color", Color.WHITE)

func _style_world_button(button: Button, selected: bool, available: bool) -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#287f9e") if selected else (Color("#17466f") if available else Color("#29394c"))
    style.border_color = Color("#ffe49b") if selected else Color("#83c7e8")
    style.set_border_width_all(3 if selected else 1)
    style.set_corner_radius_all(12)
    button.add_theme_stylebox_override("normal", style)
    button.add_theme_color_override("font_color", Color.WHITE if available else Color("#94a4b3"))

func _style_node(button: Button, current: bool, locked: bool, stars_count: int) -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#273b54") if locked else (Color("#e4a934") if stars_count >= 3 else (Color("#2487ae") if current else Color("#174c7d"))
    style.border_color = Color("#697d91") if locked else (Color("#fff2b0") if current else Color("#8ceaff"))
    style.set_border_width_all(3 if current else 2)
    style.set_corner_radius_all(34)
    button.add_theme_stylebox_override("normal", style)
    button.add_theme_color_override("font_color", Color("#8292a4") if locked else Color.WHITE)

func _on_level_pressed(level: int) -> void:
    var unlocked := GameState.get_mode_unlocked_level()
    if level > unlocked:
        _show_popup("LEVEL LOCKED", "Complete level %d to open this node." % (level - 1))
        return
    if not GameState.spend_life():
        _show_popup("OUT OF LIVES", "Your next life arrives in %s. You can return when the timer is ready." % _life_timer_text())
        return
    GameState.current_level = level
    GameState.save_progress()
    get_tree().change_scene_to_file("res://scenes/Gameplay.tscn")

func qa_open_settings() -> void:
    _show_settings()

func qa_open_store() -> void:
    _show_store()

func qa_open_spin() -> void:
    var remaining := GameState.daily_spin_seconds_remaining()
    if remaining > 0:
        _show_popup("DAILY SPIN", "Next free spin in %d hours." % int(ceil(float(remaining) / 3600.0)))
    elif GameState.claim_daily_spin():
        _refresh_wallet()
        _show_popup("DAILY REWARD", "You won %s." % GameState.daily_spin_reward)
    else:
        _show_popup("DAILY SPIN", "The free spin is not ready yet.")

func qa_open_piggy() -> void:
    var body := "Piggy bank: %d / %d coins. It fills by 10 coins on each first level clear." % [GameState.piggy_bank_coins, GameState.PIGGY_CAPACITY]
    if GameState.piggy_bank_coins >= GameState.PIGGY_CAPACITY:
        body += "\nThe bank is full. Real-money unlock is not connected in this build."
    _show_popup("PIGGY BANK", body)

func qa_open_events() -> void:
    _show_popup("EVENTS", "No limited-time event is active. Your campaign remains playable offline.")

func _show_settings() -> void:
    _ensure_popup()
    var content := VBoxContainer.new()
    content.position = Vector2(42, 300)
    content.size = Vector2(456, 390)
    content.add_theme_constant_override("separation", 12)
    popup_layer.add_child(content)
    _popup_title(content, "SETTINGS")
    for setting_name in ["music", "sound", "haptics"]:
        var row := HBoxContainer.new()
        var label := Label.new()
        label.text = setting_name.capitalize()
        label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        label.add_theme_font_size_override("font_size", 18)
        label.add_theme_color_override("font_color", Color.WHITE)
        row.add_child(label)
        var toggle := CheckButton.new()
        toggle.button_pressed = bool(GameState.settings.get(setting_name, true))
        toggle.toggled.connect(_on_setting_toggled.bind(setting_name))
        row.add_child(toggle)
        content.add_child(row)
    var language := Label.new()
    language.text = "Language: English (Hindi localisation pending)"
    language.add_theme_font_size_override("font_size", 13)
    language.add_theme_color_override("font_color", Color("#bdeaff"))
    content.add_child(language)
    _add_close_to_popup()

func _on_setting_toggled(value: bool, setting_name: String) -> void:
    GameState.set_setting(setting_name, value)

func _show_store() -> void:
    _ensure_popup()
    var content := VBoxContainer.new()
    content.position = Vector2(35, 245)
    content.size = Vector2(470, 480)
    content.add_theme_constant_override("separation", 10)
    popup_layer.add_child(content)
    _popup_title(content, "BOOSTER SHOP")
    var offers := [["Bomb", 300], ["Fireball", 250], ["Rainbow", 350], ["+5 Moves", 150]]
    for offer in offers:
        var row := HBoxContainer.new()
        var label := Label.new()
        label.text = "%s  •  %d coins  •  owned %d" % [offer[0], offer[1], int(GameState.boosters.get(str(offer[0]), 0))]
        label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        label.add_theme_font_size_override("font_size", 15)
        label.add_theme_color_override("font_color", Color.WHITE)
        row.add_child(label)
        var buy := Button.new()
        buy.text = "BUY"
        buy.custom_minimum_size = Vector2(88, 50)
        _style_button(buy, true)
        buy.pressed.connect(_buy_offer.bind(str(offer[0]), int(offer[1])))
        row.add_child(buy)
        content.add_child(row)
    var note := Label.new()
    note.text = "Offline coin shop. Google Play Billing and real-money products are not connected."
    note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    note.add_theme_font_size_override("font_size", 13)
    note.add_theme_color_override("font_color", Color("#bdeaff"))
    content.add_child(note)
    _add_close_to_popup()

func _buy_offer(name: String, price: int) -> void:
    if GameState.buy_booster(name, price):
        _refresh_wallet()
        _show_popup("PURCHASE COMPLETE", "Added one %s booster to your inventory." % name)
    else:
        _show_popup("NOT ENOUGH COINS", "You need %d coins to buy this booster." % price)

func _refresh_wallet() -> void:
    if coin_label != null:
        coin_label.text = "COINS  %d" % GameState.coins
    if lives_label != null:
        lives_label.text = "LIVES  %d / 5" % GameState.lives
    if life_timer != null:
        life_timer.text = _life_timer_text()

func _ensure_popup() -> void:
    if popup_layer != null and is_instance_valid(popup_layer):
        popup_layer.queue_free()
    popup_layer = Control.new()
    popup_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(popup_layer)
    var shade := ColorRect.new()
    shade.color = Color(0.005, 0.015, 0.05, 0.84)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    popup_layer.add_child(shade)

func _popup_title(parent: VBoxContainer, value: String) -> void:
    var title := Label.new()
    title.text = value
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 27)
    title.add_theme_color_override("font_color", Color("#ffe49b"))
    parent.add_child(title)

func _add_close_to_popup() -> void:
    var close := Button.new()
    close.text = "CLOSE"
    close.position = Vector2(160, 780)
    close.size = Vector2(220, 52)
    _style_button(close, true)
    close.pressed.connect(_close_popup)
    popup_layer.add_child(close)

func _close_popup() -> void:
    if popup_layer != null:
        popup_layer.queue_free()
        popup_layer = null

func _show_popup(title_text: String, body_text: String) -> void:
    _ensure_popup()
    var panel := Panel.new()
    panel.position = Vector2(38, 335)
    panel.size = Vector2(464, 290)
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#153f70")
    style.border_color = Color("#91e6ff")
    style.set_border_width_all(3)
    style.set_corner_radius_all(24)
    panel.add_theme_stylebox_override("panel", style)
    popup_layer.add_child(panel)
    var title := Label.new()
    title.text = title_text
    title.position = Vector2(20, 30)
    title.size = Vector2(424, 45)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 25)
    title.add_theme_color_override("font_color", Color("#ffeaa0"))
    panel.add_child(title)
    var body := Label.new()
    body.text = body_text
    body.position = Vector2(28, 95)
    body.size = Vector2(408, 110)
    body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    body.add_theme_font_size_override("font_size", 17)
    body.add_theme_color_override("font_color", Color.WHITE)
    panel.add_child(body)
    var close := Button.new()
    close.text = "CLOSE"
    close.position = Vector2(130, 218)
    close.size = Vector2(204, 50)
    _style_button(close, true)
    close.pressed.connect(_close_popup)
    panel.add_child(close)
