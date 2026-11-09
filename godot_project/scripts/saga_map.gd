extends Control

var popup_layer: Control
var coin_label: Label
var lives_label: Label

func _ready() -> void:
    _build_map()

func _build_map() -> void:
    var bg := TextureRect.new()
    bg.texture = AssetRegistry.ui("background")
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    bg.stretch_mode = TextureRect.STRETCH_SCALE
    add_child(bg)

    var title := Label.new()
    title.text = "BUBBLE BAY"
    title.position = Vector2(18, 24)
    title.size = Vector2(270, 48)
    title.add_theme_font_size_override("font_size", 29)
    title.add_theme_color_override("font_color", Color("#fff0a8"))
    add_child(title)

    coin_label = _label("COINS  %d" % GameState.coins, Vector2(20, 82), Vector2(190, 36), 17, Color("#ffe28a"))
    lives_label = _label("LIVES  %d / 5" % GameState.lives, Vector2(310, 82), Vector2(205, 36), 17, Color("#ffb7c7"))

    var world := _label("WORLD 1  •  CAMPAIGN", Vector2(18, 132), Vector2(500, 30), 16, Color("#b8e7ff"))
    world.add_theme_font_size_override("font_size", 17)

    var scroll := ScrollContainer.new()
    scroll.position = Vector2(16, 178)
    scroll.size = Vector2(508, 655)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    add_child(scroll)

    var grid := GridContainer.new()
    grid.columns = 5
    grid.add_theme_constant_override("h_separation", 7)
    grid.add_theme_constant_override("v_separation", 9)
    grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(grid)

    for level in range(1, GameState.MAX_LEVELS + 1):
        var button := Button.new()
        var stars_count := int(GameState.stars.get(str(level), 0))
        button.text = str(level) + ("\n" + "★".repeat(stars_count) if stars_count > 0 else "")
        button.custom_minimum_size = Vector2(94, 68)
        button.disabled = level > GameState.unlocked_level
        button.add_theme_font_size_override("font_size", 15)
        _style_button(button, level == GameState.unlocked_level, button.disabled)
        button.pressed.connect(_on_level_pressed.bind(level))
        grid.add_child(button)

    var bottom := HBoxContainer.new()
    bottom.position = Vector2(12, 855)
    bottom.size = Vector2(516, 72)
    bottom.add_theme_constant_override("separation", 6)
    add_child(bottom)
    _add_nav_button(bottom, "SPIN", qa_open_spin)
    _add_nav_button(bottom, "PIGGY", qa_open_piggy)
    _add_nav_button(bottom, "EVENTS", qa_open_events)
    _add_nav_button(bottom, "SHOP", qa_open_store)
    _add_nav_button(bottom, "SETTINGS", qa_open_settings)

func _add_nav_button(parent: HBoxContainer, text_value: String, action: Callable) -> void:
    var button := Button.new()
    button.text = text_value
    button.custom_minimum_size = Vector2(96, 64)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _style_button(button, text_value == "SHOP", false)
    button.pressed.connect(action)
    parent.add_child(button)

func _label(value: String, position_value: Vector2, size_value: Vector2, font_size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = value
    label.position = position_value
    label.size = size_value
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    add_child(label)
    return label

func _style_button(button: Button, highlighted: bool, locked: bool = false) -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#24395b") if locked else (Color("#2471a7") if highlighted else Color("#16466f"))
    style.border_color = Color("#9eeaff") if not locked else Color("#50627a")
    style.set_border_width_all(2)
    style.set_corner_radius_all(16)
    style.shadow_color = Color(0, 0, 0, 0.22)
    style.shadow_size = 3
    button.add_theme_stylebox_override("normal", style)
    button.add_theme_color_override("font_color", Color("#9eafc0") if locked else Color.WHITE)

func _on_level_pressed(level: int) -> void:
    if level > GameState.unlocked_level:
        _show_popup("LEVEL LOCKED", "Clear the previous level to unlock this one.")
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
        _show_popup("DAILY SPIN", "Your next free spin is available in %d hours." % int(ceil(float(remaining) / 3600.0)))
    elif GameState.claim_daily_spin():
        _refresh_wallet()
        _show_popup("DAILY REWARD", "You received 250 coins. Come back tomorrow for another free spin.")
    else:
        _show_popup("DAILY SPIN", "The free spin is not ready yet.")

func qa_open_piggy() -> void:
    _show_popup("PIGGY BANK", "Your coin balance is %d. The bank feature will be enabled after its full reward and purchase flow is tested." % GameState.coins)

func qa_open_events() -> void:
    _show_popup("EVENTS", "There is no live event right now. Your campaign progress is saved locally.")

func _show_settings() -> void:
    _ensure_popup()
    var content := VBoxContainer.new()
    content.position = Vector2(42, 350)
    content.size = Vector2(456, 300)
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
    var offers := [
        ["Bomb", 300],
        ["Fireball", 250],
        ["Rainbow", 350],
        ["+5 Moves", 150]
    ]
    for offer in offers:
        var row := HBoxContainer.new()
        var label := Label.new()
        label.text = "%s  •  %d coins" % [offer[0], offer[1]]
        label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        label.add_theme_font_size_override("font_size", 16)
        label.add_theme_color_override("font_color", Color.WHITE)
        row.add_child(label)
        var buy := Button.new()
        buy.text = "BUY"
        buy.custom_minimum_size = Vector2(100, 50)
        _style_button(buy, true)
        buy.pressed.connect(_buy_offer.bind(str(offer[0]), int(offer[1])))
        row.add_child(buy)
        content.add_child(row)
    var note := Label.new()
    note.text = "Offline coin shop preview. Real-money billing is not connected."
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
    title.add_theme_font_size_override("font_size", 28)
    title.add_theme_color_override("font_color", Color("#ffe49b"))
    parent.add_child(title)

func _add_close_to_popup() -> void:
    var close := Button.new()
    close.text = "CLOSE"
    close.position = Vector2(160, 780)
    close.size = Vector2(220, 52)
    _style_button(close, true)
    close.pressed.connect(func():
        if popup_layer != null:
            popup_layer.queue_free()
            popup_layer = null
    )
    popup_layer.add_child(close)

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
    close.pressed.connect(func():
        if popup_layer != null:
            popup_layer.queue_free()
            popup_layer = null
    )
    panel.add_child(close)

