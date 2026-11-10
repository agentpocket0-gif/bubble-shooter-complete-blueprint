extends Control

func _ready() -> void:
    var background := TextureRect.new()
    background.texture = AssetRegistry.ui("background")
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    background.stretch_mode = TextureRect.STRETCH_SCALE
    add_child(background)

    var logo := TextureRect.new()
    logo.texture = AssetRegistry.ui("logo")
    logo.position = Vector2(36, 270)
    logo.size = Vector2(468, 270)
    logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    logo.modulate.a = 0.0
    add_child(logo)

    var version := Label.new()
    version.text = "VERSION 1.1"
    version.position = Vector2(24, 890)
    version.size = Vector2(492, 28)
    version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    version.add_theme_font_size_override("font_size", 13)
    version.add_theme_color_override("font_color", Color("#b9dff0"))
    add_child(version)

    var tween := create_tween()
    tween.tween_property(logo, "modulate:a", 1.0, 0.2)
    tween.tween_interval(0.8)
    tween.tween_property(logo, "modulate:a", 0.0, 0.25)
    await tween.finished
    if not is_inside_tree():
        return
    var next_scene := "res://scenes/Intro.tscn" if not GameState.tutorial_done else "res://scenes/Loading.tscn"
    get_tree().change_scene_to_file(next_scene)

