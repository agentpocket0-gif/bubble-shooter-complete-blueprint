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
    logo.position = Vector2(36, 285)
    logo.size = Vector2(468, 250)
    logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    add_child(logo)
    var title := Label.new()
    title.text = "LOADING YOUR NEXT ADVENTURE"
    title.position = Vector2(24, 610)
    title.size = Vector2(492, 46)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 20)
    title.add_theme_color_override("font_color", Color("#e8f7ff"))
    add_child(title)
    var bar := ProgressBar.new()
    bar.position = Vector2(70, 675)
    bar.size = Vector2(400, 20)
    bar.max_value = 100
    bar.value = 15
    add_child(bar)
    var tween := create_tween()
    tween.tween_property(bar, "value", 100.0, 1.1)
    await get_tree().create_timer(1.35).timeout
    if is_inside_tree():
        get_tree().change_scene_to_file("res://scenes/SagaMap.tscn")
