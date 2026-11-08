extends Node

signal save_loaded(success: bool)
signal save_changed(data: Dictionary)

const CURRENT_VERSION := 1
const SAVE_PATH := "user://classic_blast_save.json"
const TEMP_PATH := "user://classic_blast_save.json.tmp"
const BACKUP_PATH := "user://classic_blast_save.json.bak"

var data: Dictionary = {}


func _ready() -> void:
	load_game()


func _default_data() -> Dictionary:
	return {
		"version": CURRENT_VERSION,
		"progress": {
			"max_level": 1,
			"stars": {}
		},
		"wallet": {
			"coins": 0,
			"gems": 0
		},
		"lives": {
			"count": 5,
			"last_refill_unix": 0
		},
		"boosters": {
			"bomb": 0,
			"rainbow": 0,
			"extra_moves": 0
		},
		"settings": {
			"music_enabled": true,
			"sfx_enabled": true,
			"haptics_enabled": true,
			"language": "en"
		},
		"flags": {
			"tutorial_complete": false
		}
	}


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		data = _default_data()
		var created := save_game()
		save_loaded.emit(created)
		return created

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("SaveManager: could not open save file.")
		data = _default_data()
		save_loaded.emit(false)
		return false

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()

	if not parsed is Dictionary:
		push_warning("SaveManager: save file is invalid; starting with defaults.")
		data = _default_data()
		var reset_ok := save_game()
		save_loaded.emit(reset_ok)
		return reset_ok

	data = _migrate(parsed)
	save_loaded.emit(true)
	return true


func save_game() -> bool:
	if data.is_empty():
		data = _default_data()

	data["version"] = CURRENT_VERSION
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager: could not create temporary save file.")
		return false

	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	file.close()

	var absolute_save := ProjectSettings.globalize_path(SAVE_PATH)
	var absolute_temp := ProjectSettings.globalize_path(TEMP_PATH)
	var absolute_backup := ProjectSettings.globalize_path(BACKUP_PATH)

	if FileAccess.file_exists(BACKUP_PATH):
		DirAccess.remove_absolute(absolute_backup)

	var had_previous_save := FileAccess.file_exists(SAVE_PATH)
	if had_previous_save:
		var backup_error := DirAccess.rename_absolute(absolute_save, absolute_backup)
		if backup_error != OK:
			push_warning("SaveManager: could not protect the previous save.")
			return false

	var replace_error := DirAccess.rename_absolute(absolute_temp, absolute_save)
	if replace_error != OK:
		if had_previous_save and FileAccess.file_exists(BACKUP_PATH):
			DirAccess.rename_absolute(absolute_backup, absolute_save)
		push_warning("SaveManager: could not replace the save file.")
		return false

	if FileAccess.file_exists(BACKUP_PATH):
		DirAccess.remove_absolute(absolute_backup)

	save_changed.emit(data.duplicate(true))
	return true


func set_value(key: String, value: Variant) -> void:
	data[key] = value
	save_game()


func get_value(key: String, fallback: Variant = null) -> Variant:
	return data.get(key, fallback)


func _migrate(source: Dictionary) -> Dictionary:
	var source_version := int(source.get("version", 0))
	if source_version > CURRENT_VERSION:
		push_warning("SaveManager: save was created by a newer game version.")
		return _default_data()

	var migrated := _default_data()
	migrated.merge(source, true)
	migrated["version"] = CURRENT_VERSION
	return migrated
