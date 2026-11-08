extends Node

var music_enabled := true
var sfx_enabled := true


func play_sfx(asset_key: StringName, volume_db: float = 0.0) -> void:
	if not sfx_enabled:
		return

	var stream := AssetRegistry.get_audio(asset_key)
	if stream == null:
		return

	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func set_music_enabled(enabled: bool) -> void:
	music_enabled = enabled


func set_sfx_enabled(enabled: bool) -> void:
	sfx_enabled = enabled
