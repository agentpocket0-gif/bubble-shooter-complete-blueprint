extends Control

const MODE_CARDS := [
    {"id": "classic", "title": "CLASSIC", "subtitle": "600 story levels", "detail": "The main campaign. Learn the board, build combos and earn stars.", "accent": "#4bd9ff"},
    {"id": "hard", "title": "HARD LEVELS", "subtitle": "600 tougher variants", "detail": "More pressure, fewer moves and extra obstacles on familiar layouts.", "accent": "#ff9a6b"},
    {"id": "challenge", "title": "CHALLENGE", "subtitle": "600 objective variants", "detail": "Focus on special goals such as clearing a colour, reaching a score or popping a target.", "accent": "#d5a0ff"}
]

func _ready() -> void:
    var bg := TextureRect.new()
    bg.texture = AssetRegistry.ui("background")
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    bg.stretch_mode = TextureRect.STRETCH_SCALE
    add_child(bg)

    var title := Label.new()
    title.text = "CHOOSE YOUR MODE"
    title.position = Vector2(18, 52)
    title.size = Vector2(504, 52)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 27)
    title.add_theme_color_override("font_color", Color("#fff0a8"))
    add_child(title)

    for index in range(MODE_CARDS.size()):
        _add_mode_card(MODE_CARDS[index], index)

    var back := Button.new()
    back.text = "BACK TO MAP"
    back.position = Vector2(105, 875)
    back.size = Vector2(330, 58)
    _style_button(back, false)
    back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/SagaMap.tscn"))
    add_child(back)

func _add_mode_card(info: Dictionary, index: int) -> void:
    var y := 145.0 + float(index) * 225.0
    var card := Panel.new()
    card.position = Vector2(24, y)
    card.size = Vector2(492, 198)
    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color("#102e5c")
    panel_style.border_color = Color(str(info.accent))
    panel_style.set_border_width_all(3)
    panel_style.set_corner_radius_all(24)
    panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.3)
    panel_style.shadow_size = 8
    card.add_theme_stylebox_override("panel", panel_style)
    add_child(card)

    var heading := Label.new()
    heading.text = str(info.title)
    heading.position = Vector2(22, 18)
    heading.size = Vector2(300, 38)
    heading.add_theme_font_size_override("font_size", 24)
    heading.add_theme_color_override("font_color", Color("#fff0a8"))
    card.add_child(heading)

    var subtitle := Label.new()
    subtitle.text = str(info.subtitle)
    subtitle.position = Vector2(22, 61)
    subtitle.size = Vector2(300, 30)
    subtitle.add_theme_font_size_override("font_size", 16)
    subtitle.add_theme_color_override("font_color", Color(str(info.accent)))
    card.add_child(subtitle)

    var description := Label.new()
    description.text = str(info.detail)
    description.position = Vector2(22, 98)
    description.size = Vector2(280, 78)
    description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    description.add_theme_font_size_override("font_size", 14)
    description.add_theme_color_override("font_color", Color("#e7f5ff"))
    card.add_child(description)

    var play := Button.new()
    play.text = "PLAY"
    play.position = Vector2(340, 68)
    play.size = Vector2(126, 64)
    _style_button(play, true)
    play.pressed.connect(_select_mode.bind(str(info.id)))
    card.add_child(play)

    var progress := Label.new()
    progress.text = "BEST  %d / 1800 STARS" % GameState.get_mode_stars_total(str(info.id))
    progress.position = Vector2(22, 168)
    progress.size = Vector2(330, 22)
    progress.add_theme_font_size_override("font_size", 11)
    progress.add_theme_color_override("font_color", Color("#b8d9ee"))
    card.add_child(progress)

func _select_mode(mode: String) -> void:
    if GameState.set_game_mode(mode):
        GameState.current_level = GameState.get_mode_unlocked_level(mode)
        get_tree().change_scene_to_file("res://scenes/SagaMap.tscn")

func _style_button(button: Button, highlighted: bool) -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#1885b8") if highlighted else Color("#17466f")
    style.border_color = Color("#b3efff")
    style.set_border_width_all(2)
    style.set_corner_radius_all(16)
    button.add_theme_stylebox_override("normal", style)
    button.add_theme_color_override("font_color", Color.WHITE)
    button.add_theme_font_size_override("font_size", 18)

