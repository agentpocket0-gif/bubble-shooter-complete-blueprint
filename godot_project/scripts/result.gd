extends Control

func _ready() -> void:
    var result: Dictionary = GameState.pending_result
    var won := bool(result.get("won", false))
    var level_id := int(result.get("level", GameState.current_level))
    var score := int(result.get("score", 0))
    var star_count := int(result.get("stars", 0))
    var reward := int(result.get("reward", 0))

    var bg := TextureRect.new()
    bg.texture = AssetRegistry.ui("background")
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    bg.stretch_mode = TextureRect.STRETCH_SCALE
    add_child(bg)

    var shade := ColorRect.new()
    shade.color = Color(0.01, 0.025, 0.07, 0.35)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(shade)

    var panel := Panel.new()
    panel.position = Vector2(32, 250)
    panel.size = Vector2(476, 480)
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#153e70")
    style.border_color = Color("#a6efff")
    style.set_border_width_all(4)
    style.set_corner_radius_all(30)
    panel.add_theme_stylebox_override("panel", style)
    add_child(panel)

    var title := Label.new()
    title.text = "LEVEL COMPLETE" if won else "TRY AGAIN"
    title.position = Vector2(20, 38)
    title.size = Vector2(436, 58)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 30)
    title.add_theme_color_override("font_color", Color("#ffe49b"))
    panel.add_child(title)

    var stars_label := Label.new()
    stars_label.text = "★  ".repeat(star_count) if won else "Keep going!"
    stars_label.position = Vector2(30, 122)
    stars_label.size = Vector2(416, 55)
    stars_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stars_label.add_theme_font_size_override("font_size", 34)
    stars_label.add_theme_color_override("font_color", Color("#ffdf69"))
    panel.add_child(stars_label)

    var body := Label.new()
    body.text = "Level %d\nScore  %d\nCoins earned  +%d" % [level_id, score, reward] if won else "Level %d\nScore  %d\nTry a new angle or use a booster." % [level_id, score]
    body.position = Vector2(35, 195)
    body.size = Vector2(406, 100)
    body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    body.add_theme_font_size_override("font_size", 20)
    body.add_theme_color_override("font_color", Color.WHITE)
    panel.add_child(body)

    var primary := Button.new()
    primary.text = "NEXT LEVEL" if won else "RETRY"
    primary.position = Vector2(80, 325)
    primary.size = Vector2(316, 58)
    _style_button(primary, true)
    primary.pressed.connect(_on_primary.bind(won))
    panel.add_child(primary)

    var secondary := Button.new()
    secondary.text = "RETRY" if won else "BACK TO MAP"
    secondary.position = Vector2(80, 397)
    secondary.size = Vector2(316, 54)
    _style_button(secondary, false)
    if won:
        secondary.pressed.connect(_retry)
    else:
        secondary.pressed.connect(_go_map)
    panel.add_child(secondary)

    if won:
        var map_button := Button.new()
        map_button.text = "WORLD MAP"
        map_button.position = Vector2(80, 455)
        map_button.size = Vector2(316, 48)
        _style_button(map_button, false)
        map_button.pressed.connect(_go_map)
        panel.add_child(map_button)

func _on_primary(won: bool) -> void:
    if won:
        GameState.current_level = mini(GameState.unlocked_level, GameState.MAX_LEVELS)
        _play_current_level()
    else:
        _retry()

func _retry() -> void:
    _play_current_level()

func _play_current_level() -> void:
    GameState.save_progress()
    get_tree().change_scene_to_file("res://scenes/Gameplay.tscn")

func _go_map() -> void:
    GameState.save_progress()
    get_tree().change_scene_to_file("res://scenes/SagaMap.tscn")

func _style_button(button: Button, highlighted: bool) -> void:
    var box := StyleBoxFlat.new()
    box.bg_color = Color("#1879ad") if highlighted else Color("#17486f")
    box.border_color = Color("#b1edff")
    box.set_border_width_all(2)
    box.set_corner_radius_all(16)
    button.add_theme_stylebox_override("normal", box)
    button.add_theme_color_override("font_color", Color.WHITE)
    button.add_theme_font_size_override("font_size", 18)

