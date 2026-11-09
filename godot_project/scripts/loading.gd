extends Control

const PRELOAD_RESOURCES := [
    "res://assets/own/ui/background.svg",
    "res://assets/own/ui/logo.svg",
    "res://assets/own/ui/cannon.svg",
    "res://assets/own/ui/coin.svg",
    "res://assets/own/ui/star.svg",
    "res://assets/own/bubbles/red.svg",
    "res://assets/own/bubbles/blue.svg",
    "res://assets/own/bubbles/green.svg",
    "res://assets/own/bubbles/yellow.svg",
    "res://assets/own/bubbles/purple.svg",
    "res://assets/own/bubbles/orange.svg"
]

var progress_bar: ProgressBar
var percent_label: Label
var tip_label: Label

func _ready() -> void:
    var bg := TextureRect.new()
    bg.texture = AssetRegistry.ui("background")
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    bg.stretch_mode = TextureRect.STRETCH_SCALE
    add_child(bg)

    var title := Label.new()
    title.text = "GETTING YOUR GAME READY"
    title.position = Vector2(25, 390)
    title.size = Vector2(490, 52)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 23)
    title.add_theme_color_override("font_color", Color("#fff0a8"))
    add_child(title)

    progress_bar = ProgressBar.new()
    progress_bar.position = Vector2(55, 470)
    progress_bar.size = Vector2(430, 25)
    progress_bar.max_value = PRELOAD_RESOURCES.size()
    progress_bar.value = 0
    add_child(progress_bar)

    percent_label = Label.new()
    percent_label.position = Vector2(55, 505)
    percent_label.size = Vector2(430, 30)
    percent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    percent_label.add_theme_font_size_override("font_size", 16)
    percent_label.add_theme_color_override("font_color", Color("#c9ecff"))
    add_child(percent_label)

    tip_label = Label.new()
    tip_label.text = "Tip: Save boosters for difficult boards."
    tip_label.position = Vector2(35, 565)
    tip_label.size = Vector2(470, 45)
    tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    tip_label.add_theme_font_size_override("font_size", 15)
    tip_label.add_theme_color_override("font_color", Color("#ffe6a1"))
    add_child(tip_label)

    _preload_assets()

func _preload_assets() -> void:
    var loaded := 0
    for resource_path in PRELOAD_RESOURCES:
        var resource = load(resource_path)
        if resource == null:
            push_error("Failed to preload: " + resource_path)
        loaded += 1
        progress_bar.value = loaded
        percent_label.text = "%d%%" % int(round(float(loaded) / float(PRELOAD_RESOURCES.size()) * 100.0))
        await get_tree().process_frame
    await get_tree().create_timer(0.2).timeout
    if is_inside_tree():
        get_tree().change_scene_to_file("res://scenes/SagaMap.tscn")

