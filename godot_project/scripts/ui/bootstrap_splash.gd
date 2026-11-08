extends Control

const BACKGROUND_COLOR := Color(0.035, 0.055, 0.11, 1.0)
const PANEL_COLOR := Color(0.075, 0.11, 0.2, 1.0)
const ACCENT_COLOR := Color(1.0, 0.78, 0.24, 1.0)


func _ready() -> void:
	GameManager.change_state(GameManager.AppState.SPLASH)
	_build_screen()


func _build_screen() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.color = BACKGROUND_COLOR
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 460)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = PANEL_COLOR
	panel_style.set_corner_radius_all(34)
	panel_style.set_content_margin_all(42)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 24)
	panel.add_child(content)

	var title := Label.new()
	title.text = "CLASSIC BLAST"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 58)
	title.add_theme_color_override("font_color", ACCENT_COLOR)
	content.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Bubble Shooter"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 34)
	subtitle.add_theme_color_override("font_color", Color(0.9, 0.94, 1.0, 1.0))
	content.add_child(subtitle)

	var status := Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 22)
	status.add_theme_color_override("font_color", Color(0.72, 0.8, 0.91, 1.0))
	if AssetRegistry.manifest_ready:
		status.text = "Asset manifest loaded. Registered assets: %d" % AssetRegistry.get_registered_asset_count()
	else:
		status.text = "Asset manifest is awaiting verification."
	content.add_child(status)

	var footer := Label.new()
	footer.text = "Milestone 1 · project foundation"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 18)
	footer.add_theme_color_override("font_color", Color(0.58, 0.66, 0.78, 1.0))
	content.add_child(footer)
