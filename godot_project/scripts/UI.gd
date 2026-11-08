class_name UI
extends RefCounted
## Shared widget factory. Every screen builds itself from these so the look is
## identical everywhere and there is exactly one place to change a colour.

const INK := Color("#F5F6FA")
const MUTED := Color("#9AA0B4")
const ACCENT := Color("#F2C94C")
const DANGER := Color("#E8453C")
const GOOD := Color("#27AE60")
const PANEL_BG := Color("#1A1A22")

const UI_DIR := "res://assets/ui/"
const HUD_DIR := "res://assets/hud/"

static var _tex_cache: Dictionary = {}


static func tex(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	if not ResourceLoader.exists(path):
		return null
	var t: Texture2D = load(path)
	_tex_cache[path] = t
	return t


static func ui_tex(name: String) -> Texture2D:
	return tex(UI_DIR + name)


static func icon(name: String, big: bool = true) -> Texture2D:
	var suffix := "_96.png" if big else "_64.png"
	return tex(HUD_DIR + name + suffix)


static func theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 40
	t.set_color("font_color", "Label", INK)
	return t


static func label(text: String, size: int = 40, color: Color = INK, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	return l


static func title(text: String, size: int = 72) -> Label:
	var l := label(text, size, INK, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_y", 4)
	return l


static func stylebox(name: String) -> StyleBox:
	var t := ui_tex(name)
	if t == null:
		var sb := StyleBoxFlat.new()
		sb.bg_color = PANEL_BG
		sb.set_corner_radius_all(24)
		return sb
	var s := StyleBoxTexture.new()
	s.texture = t
	s.texture_margin_left = 24
	s.texture_margin_right = 24
	s.texture_margin_top = 24
	s.texture_margin_bottom = 24
	s.content_margin_left = 32
	s.content_margin_right = 32
	s.content_margin_top = 20
	s.content_margin_bottom = 20
	return s


static func button(text: String, primary: bool = true, size: int = 44) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 128)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", Color("#1A1A22") if primary else INK)
	b.add_theme_color_override("font_hover_color", Color("#1A1A22") if primary else INK)
	b.add_theme_color_override("font_pressed_color", Color("#1A1A22") if primary else INK)
	var prefix := "btn_primary_" if primary else "btn_secondary_"
	b.add_theme_stylebox_override("normal", stylebox(prefix + "normal.png"))
	b.add_theme_stylebox_override("hover", stylebox(prefix + "normal.png"))
	b.add_theme_stylebox_override("pressed", stylebox(prefix + "pressed.png"))
	b.add_theme_stylebox_override("disabled", stylebox(prefix + "disabled.png"))
	return b


static func icon_button(icon_name: String, size: float = 96.0, cb: Callable = Callable()) -> TextureButton:
	var b := TextureButton.new()
	b.texture_normal = icon(icon_name, true)
	b.custom_minimum_size = Vector2(size, size)
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


static func pill(icon_name: String, text: String, width: float = 240.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(width, 84)
	p.add_theme_stylebox_override("panel", stylebox("pill_hud.png"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(row)
	if icon_name != "":
		var ic := TextureRect.new()
		ic.texture = icon(icon_name, true)
		ic.custom_minimum_size = Vector2(56, 56)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(ic)
	var l := label(text, 38, INK, HORIZONTAL_ALIGNMENT_CENTER)
	l.name = "Value"
	row.add_child(l)
	return p


static func set_pill_text(p: PanelContainer, text: String) -> void:
	var v := p.find_child("Value", true, false)
	if v is Label:
		(v as Label).text = text


static func popup(width: float = 900.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(width, 0)
	p.add_theme_stylebox_override("panel", stylebox("popup_frame.png"))
	return p


static func progress(width: float = 600.0, height: float = 32.0) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.custom_minimum_size = Vector2(width, height)
	pb.show_percentage = false
	pb.max_value = 100.0
	var bg := stylebox("progress_bg.png")
	var fg := stylebox("progress_fill.png")
	pb.add_theme_stylebox_override("background", bg)
	pb.add_theme_stylebox_override("fill", fg)
	return pb


static func star_row(stars: int, size: float = 72.0) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	for i in 3:
		var tr := TextureRect.new()
		tr.texture = icon("icon_star_on" if i < stars else "icon_star_off", true)
		tr.custom_minimum_size = Vector2(size, size)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(tr)
	return row


static func full_rect(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


static func scrim() -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0, 0, 0, 0.72)
	full_rect(r)
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	return r


static func background(color_a: Color = Color("#1A1A22"), color_b: Color = Color("#2B2B3C")) -> Control:
	var t := ui_tex("popup_scrim.png")
	var r := TextureRect.new()
	if t != null:
		r.texture = t
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_SCALE
	else:
		var cr := ColorRect.new()
		cr.color = color_a
		full_rect(cr)
		return null
	full_rect(r)
	r.modulate = Color(1, 1, 1, 1)
	return r
