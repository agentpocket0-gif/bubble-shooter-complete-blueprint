extends Control

func _ready() -> void:
    var result: Dictionary = GameState.pending_result
    var won := bool(result.get("won", false))
    var level_id := int(result.get("level", GameState.current_level))
    var mode := str(result.get("mode", GameState.game_mode))
    var score := int(result.get("score", 0))
    var stars := int(result.get("stars", 0))
    var reward := int(result.get("reward", 0))
    var loss_reason := str(result.get("loss_reason", "Out of shots"))

    var bg := TextureRect.new()
    bg.texture = AssetRegistry.ui("background")
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    bg.stretch_mode = TextureRect.STRETCH_SCALE
    add_child(bg)

    var shade := ColorRect.new()
    shade.color = Color(0.01, 0.025, 0.07, 0.42)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(shade)

    var panel := Panel.new()
    panel.position = Vector2(32, 225)
    panel.size = Vector2(476, 520)
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#153e70")
    style.border_color = Color("#a6efff")
    style.set_border_width_all(4)
    style.set_corner_radius_all(30)
    panel.add_theme_stylebox_override("panel", style)
    add_child(panel)

    var title := Label.new()
    title.text = "LEVEL COMPLETE!" if won else "LEVEL FAILED"
    title.position = Vector2(20, 32)
    title.size = Vector2(436, 58)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 30)
    title.add_theme_color_override("font_color", Color("#ffe49b"))
    panel.add_child(title)

    var mode_label := Label.new()
    mode_label.text = "%s  •  LEVEL %d / %d" % [mode.to_upper(), level_id, GameState.MAX_LEVELS]
    mode_label.position = Vector2(26, 88)
    mode_label.size = Vector2(424, 32)
    mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    mode_label.add_theme_font_size_override("font_size", 15)
    mode_label.add_theme_color_override("font_color", Color("#bdeaff"))
    panel.add_child(mode_label)

    var star_label := Label.new()
    star_label.text = "★  ".repeat(stars) if won else "TRY A DIFFERENT ANGLE"
    star_label.position = Vector2(30, 135)
    star_label.size = Vector2(416, 55)
    star_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    star_label.add_theme_font_size_override("font_size", 30)
    star_label.add_theme_color_override("font_color", Color("#ffdf69"))
    panel.add_child(star_label)

    var body := Label.new()
    body.text = "Score  %d\nCoins earned  +%d" % [score, reward] if won else "%s\nScore  %d" % [loss_reason, score]
    body.position = Vector2(35, 205)
    body.size = Vector2(406, 86)
    body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    body.add_theme_font_size_override("font_size", 20)
    body.add_theme_color_override("font_color", Color.WHITE)
    panel.add_child(body)

    var final_level := won and level_id >= GameState.MAX_LEVELS
    var primary := Button.new()
    primary.text = "CAMPAIGN COMPLETE" if final_level else ("NEXT LEVEL" if won else "RETRY")
    primary.position = Vector2(80, 315)
    primary.size = Vector2(316, 58)
    _style_button(primary, true)
    primary.pressed.connect(_on_primary.bind(won, final_level))
    panel.add_child(primary)

    var secondary := Button.new()
    secondary.text = "REPLAY" if won else "BACK TO MAP"
    secondary.position = Vector2(80, 390)
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
        map_button.position = Vector2(80, 460)
        map_button.size = Vector2(316, 48)
        _style_button(map_button, false)
        map_button.pressed.connect(_go_map)
        panel.add_child(map_button)

func _on_primary(won: bool, final_level: bool) -> void:
    if final_level:
        _go_map()
    elif won:
        GameState.current_level = mini(GameState.get_mode_unlocked_level(), GameState.MAX_LEVELS)
        _play_current_level()
    else:
        _retry()

func _retry() -> void:
    _play_current_level()

func _play_current_level() -> void:
    GameState.save_progress()
    get_tree().change_scene_to_file("res://scenes/Gameplay.tscn")

func _go_map() -> void:
    GameState.pending_result = {}
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
