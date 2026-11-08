extends Node
## Music, SFX and the combo pitch ladder.
##
## Chain pops in one shot rise by 8 % per step (1.0, 1.08, 1.16 ...), which is
## the cheapest way to make a big clear feel like a big clear.

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const SETTINGS_PATH := "user://audio_settings.json"

const SFX_NAMES := [
	"sfx_shot", "sfx_pop_01", "sfx_pop_02", "sfx_pop_03", "sfx_pop_04", "sfx_pop_05",
	"sfx_cluster_big", "sfx_drop_start", "sfx_drop_land", "sfx_level_win", "sfx_level_fail",
	"sfx_booster_bomb", "sfx_booster_laser", "sfx_booster_rainbow", "sfx_booster_swap",
	"sfx_booster_extra_moves", "sfx_coin_tick", "sfx_countdown", "sfx_life_refill",
	"sfx_lives_empty", "sfx_popup_open", "sfx_popup_close", "sfx_purchase_success",
	"sfx_purchase_fail", "sfx_ad_reward", "sfx_blocker_crack", "sfx_blocker_break",
	"sfx_ceiling_drop", "sfx_chain_break", "sfx_aim_lock", "sfx_piggy_fill",
	"sfx_cannon_rotate",
]

var music_on := true
var sfx_on := true
var haptics_on := true

var _streams: Dictionary = {}
var _music_player: AudioStreamPlayer
var _music_name := ""
var _pool: Array[AudioStreamPlayer] = []
var _pool_index := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	_music_player.volume_db = -8.0
	add_child(_music_player)
	for i in 12:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)


func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		music_on = bool(parsed.get("music", true))
		sfx_on = bool(parsed.get("sfx", true))
		haptics_on = bool(parsed.get("haptics", true))


func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"music": music_on, "sfx": sfx_on, "haptics": haptics_on}))
	f.close()


func _stream(name: String) -> AudioStream:
	if _streams.has(name):
		return _streams[name]
	var path := SFX_DIR + name + ".wav"
	if not ResourceLoader.exists(path):
		return null
	var s: AudioStream = load(path)
	_streams[name] = s
	return s


func play(name: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if not sfx_on:
		return
	var s := _stream(name)
	if s == null:
		return
	var p := _pool[_pool_index]
	_pool_index = (_pool_index + 1) % _pool.size()
	p.stream = s
	p.pitch_scale = clampf(pitch, 0.5, 2.5)
	p.volume_db = volume_db
	p.play()


func play_pop(combo_step: int) -> void:
	var names := ["sfx_pop_01", "sfx_pop_02", "sfx_pop_03", "sfx_pop_04", "sfx_pop_05"]
	play(names[combo_step % names.size()], 1.0 + combo_step * 0.08, -2.0)


func play_music(track: String) -> void:
	if not music_on:
		return
	if track == _music_name and _music_player.playing:
		return
	var path := MUSIC_DIR + track + ".wav"
	if not ResourceLoader.exists(path):
		return
	_music_player.stream = load(path)
	_music_name = track
	_music_player.play()


func stop_music() -> void:
	_music_player.stop()
	_music_name = ""


func set_music(on: bool) -> void:
	music_on = on
	if on:
		if _music_name != "":
			_music_player.play()
	else:
		_music_player.stop()
	save_settings()


func set_sfx(on: bool) -> void:
	sfx_on = on
	save_settings()


func set_haptics(on: bool) -> void:
	haptics_on = on
	save_settings()


func haptic(ms: int = 12) -> void:
	if not haptics_on:
		return
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)
