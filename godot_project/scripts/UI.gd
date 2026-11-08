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
	# The button art is 240x96 with rounded corners and a coloured "lip" along
	# the bottom. Stretch only the flat face band, never the corners or the lip,
	# or the button renders as two stacked rectangles.
	var h := t.get_height()
	var lip := clampf(h * 0.46, 12.0, 44.0)
	var cap := clampf(h * 0.26, 10.0, 26.0)
	s.texture_margin_left = clampf(t.get_width() * 0.17, 12.0, 44.0)
	s.texture_margin_right = s.texture_margin_left
	s.texture_margin_top = cap
	s.texture_margin_bottom = lip
	s.content_margin_left = 28
	s.content_margin_right = 28
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


static func button(text: String, primary: bool = true, size: int = 44) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 128)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_color_override("font_disabled_color", MUTED)
	b.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	b.add_theme_constant_override("shadow_offset_y", 2)
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
	# A solid card first: the frame texture is decorative and mostly transparent
	# in the middle, so on its own the map shows straight through the popup.
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color("#1A1A22")
	flat.border_color = Color("#3A3A4C")
	flat.set_border_width_all(3)
	flat.set_corner_radius_all(36)
	flat.set_content_margin_all(34)
	p.add_theme_stylebox_override("panel", flat)
	var frame := TextureRect.new()
	frame.texture = ui_tex("popup_frame.png")
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.modulate = Color(1, 1, 1, 0.5)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(frame)
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
