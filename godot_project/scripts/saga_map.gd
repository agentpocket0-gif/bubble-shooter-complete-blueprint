extends Control

var popup_layer: Control

func _ready() -> void:
    _build_map()

func _build_map() -> void:
    var bg := TextureRect.new()
    bg.texture = AssetRegistry.ui("background")
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    bg.stretch_mode = TextureRect.STRETCH_SCALE
    add_child(bg)
    _label("CLASSIC BLAST", Vector2(18, 32), Vector2(300, 52), 29, Color("#fff4c5"))
    _label("WORLD 1  •  BUBBLE BAY", Vector2(20, 95), Vector2(340, 34), 16, Color("#b8e7ff"))
    _label("COINS  %d" % GameState.coins, Vector2(345, 38), Vector2(175, 42), 19, Color("#ffe28a"))
    var scroll := ScrollContainer.new()
    scroll.position = Vector2(18, 170)
    scroll.size = Vector2(504, 650)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    add_child(scroll)
    var grid := GridContainer.new()
    grid.columns = 5
    grid.add_theme_constant_override("h_separation", 8)
    grid.add_theme_constant_override("v_separation", 12)
    grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(grid)
    for level in range(1, 121):
        var button := Button.new()
        button.custom_minimum_size = Vector2(92, 76)
        button.text = str(level) + ("\n★".repeat(int(GameState.stars.get(str(level), 0))) if GameState.stars.has(str(level)) else "")
        button.disabled = level > GameState.unlocked_level
        button.add_theme_font_size_override("font_size", 18)
        _style_button(button, level == GameState.unlocked_level)
        button.pressed.connect(_on_level_pressed.bind(level))
        grid.add_child(button)
    var settings := Button.new()
    settings.text = "SETTINGS"
    settings.position = Vector2(25, 865)
    settings.size = Vector2(150, 58)
    _style_button(settings, false)
    settings.pressed.connect(qa_open_settings)
    add_child(settings)
    var store := Button.new()
    store.text = "BOOSTERS"
    store.position = Vector2(365, 865)
    store.size = Vector2(150, 58)
    _style_button(store, true)
    store.pressed.connect(qa_open_store)
    add_child(store)

func _label(value: String, position_value: Vector2, size_value: Vector2, font_size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = value
    label.position = position_value
    label.size = size_value
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    add_child(label)
    return label

func _style_button(button: Button, highlighted: bool) -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#2471a7") if highlighted else Color("#16466f")
    style.border_color = Color("#9eeaff")
    style.set_border_width_all(3)
    style.set_corner_radius_all(18)
    style.shadow_color = Color(0, 0, 0, 0.25)
    style.shadow_size = 5
    button.add_theme_stylebox_override("normal", style)
    button.add_theme_color_override("font_color", Color.WHITE)

func _on_level_pressed(level: int) -> void:
    GameState.current_level = level
    get_tree().change_scene_to_file("res://scenes/Gameplay.tscn")

func qa_open_settings() -> void:
    _show_popup("SETTINGS", "Music  •  Sound  •  Haptics\nPrivacy and local data controls\nRestore purchases")

func qa_open_store() -> void:
    _show_popup("BOOSTER SHOP", "Bomb  •  Fireball  •  Rainbow\n+5 Moves\nAds are disabled in this build")

func _show_popup(title_text: String, body_text: String) -> void:
    if popup_layer != null and is_instance_valid(popup_layer):
        popup_layer.queue_free()
    popup_layer = Control.new()
    popup_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(popup_layer)
    var shade := ColorRect.new()
    shade.color = Color(0.015, 0.035, 0.09, 0.78)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    popup_layer.add_child(shade)
    var panel := Panel.new()
    panel.position = Vector2(38, 310)
    panel.size = Vector2(464, 340)
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#153f70")
    style.border_color = Color("#91e6ff")
    style.set_border_width_all(4)
    style.set_corner_radius_all(28)
    panel.add_theme_stylebox_override("panel", style)
    popup_layer.add_child(panel)
    var title := Label.new()
    title.text = title_text
    title.position = Vector2(20, 32)
    title.size = Vector2(424, 54)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 27)
    title.add_theme_color_override("font_color", Color("#ffeaa0"))
    panel.add_child(title)
    var body := Label.new()
    body.text = body_text
    body.position = Vector2(30, 112)
    body.size = Vector2(404, 120)
    body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    body.add_theme_font_size_override("font_size", 18)
    body.add_theme_color_override("font_color", Color.WHITE)
    panel.add_child(body)
    var close := Button.new()
    close.text = "CLOSE"
    close.position = Vector2(132, 252)
    close.size = Vector2(200, 56)
    _style_button(close, true)
    close.pressed.connect(popup_layer.queue_free)
    panel.add_child(close)
