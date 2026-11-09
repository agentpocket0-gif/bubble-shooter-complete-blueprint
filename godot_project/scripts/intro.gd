extends Control

const SLIDES := [
    {"title": "MATCH THREE", "body": "Bring three or more bubbles of the same colour together to clear them."},
    {"title": "AIM AND BOUNCE", "body": "Drag to aim. Use the side walls to reach bubbles that are hard to hit."},
    {"title": "CLEAR THE BOARD", "body": "Finish the objective before your moves run out. Detached bubbles fall away."}
]

var slide_index := 0
var card: Panel
var title_label: Label
var body_label: Label
var dots_label: Label
var next_button: Button

func _ready() -> void:
    var bg := TextureRect.new()
    bg.texture = AssetRegistry.ui("background")
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    bg.stretch_mode = TextureRect.STRETCH_SCALE
    add_child(bg)

    var heading := Label.new()
    heading.text = "HOW TO PLAY"
    heading.position = Vector2(24, 118)
    heading.size = Vector2(492, 60)
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    heading.add_theme_font_size_override("font_size", 30)
    heading.add_theme_color_override("font_color", Color("#fff0a8"))
    add_child(heading)

    var skip := Button.new()
    skip.text = "SKIP"
    skip.position = Vector2(410, 40)
    skip.size = Vector2(100, 54)
    _style_button(skip)
    skip.pressed.connect(_finish)
    add_child(skip)

    card = Panel.new()
    card.position = Vector2(35, 285)
    card.size = Vector2(470, 380)
    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color("#153e70")
    panel_style.border_color = Color("#9de8ff")
    panel_style.set_border_width_all(3)
    panel_style.set_corner_radius_all(28)
    card.add_theme_stylebox_override("panel", panel_style)
    add_child(card)

    title_label = Label.new()
    title_label.position = Vector2(24, 45)
    title_label.size = Vector2(422, 58)
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_label.add_theme_font_size_override("font_size", 28)
    title_label.add_theme_color_override("font_color", Color("#ffdf83"))
    card.add_child(title_label)

    body_label = Label.new()
    body_label.position = Vector2(38, 135)
    body_label.size = Vector2(394, 150)
    body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    body_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    body_label.add_theme_font_size_override("font_size", 22)
    body_label.add_theme_color_override("font_color", Color.WHITE)
    card.add_child(body_label)

    dots_label = Label.new()
    dots_label.position = Vector2(40, 310)
    dots_label.size = Vector2(390, 36)
    dots_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    dots_label.add_theme_font_size_override("font_size", 20)
    dots_label.add_theme_color_override("font_color", Color("#c6edff"))
    card.add_child(dots_label)

    next_button = Button.new()
    next_button.position = Vector2(115, 730)
    next_button.size = Vector2(310, 66)
    _style_button(next_button)
    next_button.pressed.connect(_next_slide)
    add_child(next_button)
    _refresh_slide()

func _refresh_slide() -> void:
    var slide: Dictionary = SLIDES[slide_index]
    title_label.text = str(slide.title)
    body_label.text = str(slide.body)
    dots_label.text = "●  ".repeat(slide_index + 1) + "○  ".repeat(SLIDES.size() - slide_index - 1)
    next_button.text = "CONTINUE" if slide_index < SLIDES.size() - 1 else "PLAY"

func _next_slide() -> void:
    if slide_index < SLIDES.size() - 1:
        slide_index += 1
        _refresh_slide()
    else:
        _finish()

func _finish() -> void:
    GameState.tutorial_done = true
    GameState.save_progress()
    get_tree().change_scene_to_file("res://scenes/Loading.tscn")

func _style_button(button: Button) -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#176b9f")
    style.border_color = Color("#b5edff")
    style.set_border_width_all(2)
    style.set_corner_radius_all(18)
    button.add_theme_stylebox_override("normal", style)
    button.add_theme_color_override("font_color", Color.WHITE)
    button.add_theme_font_size_override("font_size", 19)

