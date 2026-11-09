extends Node

const SAVE_PATH := "user://classic_blast_save.json"
var coins: int = 250
var lives: int = 5
var current_level: int = 1
var unlocked_level: int = 1
var stars: Dictionary = {}
var boosters: Dictionary = {"Bomb": 2, "Fireball": 1, "Rainbow": 2, "+5 Moves": 2}

func _ready() -> void:
    load_progress()

func load_progress() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        save_progress()
        return
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        return
    var parsed = JSON.parse_string(file.get_as_text())
    file.close()
    if typeof(parsed) != TYPE_DICTIONARY:
        return
    coins = max(0, int(parsed.get("coins", coins)))
    lives = clampi(int(parsed.get("lives", lives)), 0, 5)
    current_level = clampi(int(parsed.get("current_level", current_level)), 1, 120)
    unlocked_level = clampi(int(parsed.get("unlocked_level", unlocked_level)), 1, 120)
    stars = parsed.get("stars", {}) if typeof(parsed.get("stars", {})) == TYPE_DICTIONARY else {}
    boosters = parsed.get("boosters", boosters) if typeof(parsed.get("boosters", boosters)) == TYPE_DICTIONARY else boosters

func save_progress() -> void:
    var payload := {"version": 1, "coins": coins, "lives": lives, "current_level": current_level, "unlocked_level": unlocked_level, "stars": stars, "boosters": boosters}
    var file := FileAccess.open(SAVE_PATH + ".tmp", FileAccess.WRITE)
    if file == null:
        return
    file.store_string(JSON.stringify(payload))
    file.close()
    if FileAccess.file_exists(SAVE_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
    DirAccess.rename_absolute(ProjectSettings.globalize_path(SAVE_PATH + ".tmp"), ProjectSettings.globalize_path(SAVE_PATH))

func complete_level(level_id: int, earned_stars: int, reward: int) -> void:
    var key := str(level_id)
    stars[key] = maxi(int(stars.get(key, 0)), earned_stars)
    unlocked_level = mini(120, maxi(unlocked_level, level_id + 1))
    coins += maxi(0, reward)
    save_progress()
