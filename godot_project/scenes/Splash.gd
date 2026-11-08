extends Control
## Splash: logo fade (200 ms in, 800 ms hold, 250 ms out) over a real preload
## bar. Minimum 1.2 s on screen; if preload is not done by 1.5 s we keep the
## loading screen with live progress instead of freezing on the logo.

const MIN_SECONDS := 1.2
const MAX_SECONDS := 1.5

var _bar: ProgressBar
var _elapsed := 0.0
var _preloaded := false
var _preload_progress := 0.0
var _leaving := false


func _ready() -> void:
	_build()
	_preload()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#12121A")
	UI.full_rect(bg)
	add_child(bg)

	var logo := TextureRect.new()
	logo.texture = UI.tex("res://custom_branding/title_logo_classic_blast.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(880, 440)
	logo.size = Vector2(880, 440)
	logo.position = Vector2(100, 620)
	logo.modulate.a = 0.0
	add_child(logo)
	logo.create_tween().tween_property(logo, "modulate:a", 1.0, 0.2)

	_bar = UI.progress(700, 26)
	_bar.position = Vector2(190, 1240)
	_bar.value = 0
	add_child(_bar)

	var ver := UI.label("v3.1.0", 30, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	ver.position = Vector2(0, 1760)
	ver.size = Vector2(1080, 40)
	add_child(ver)


func _preload() -> void:
	# Tier 1: level index (drives the map). Tier 2: first level. Tier 3: audio.
	await get_tree().process_frame
	var idx := LevelLibrary.index()
	_preload_progress = 0.4 if not idx.is_empty() else 0.4
	await get_tree().process_frame
	if idx.size() > 0:
		LevelLibrary.load_level(1)
	_preload_progress = 0.75
	await get_tree().process_frame
	for n in ["bgm_map", "sfx_pop_01", "sfx_shot"]:
		pass
	_preload_progress = 1.0
	_preloaded = true


func _process(delta: float) -> void:
	_elapsed += delta
	if _bar != null:
		var shown := _preload_progress * 100.0
		_bar.value = lerpf(_bar.value, shown, 1.0 - exp(-6.0 * delta))
	if _leaving:
		return
	if _elapsed >= MAX_SECONDS or (_elapsed >= MIN_SECONDS and _preloaded and _bar.value > 92.0):
		_leave()


func _leave() -> void:
	_leaving = true
	AudioManager.play_music("bgm_map")
	GameManager.open_map()
