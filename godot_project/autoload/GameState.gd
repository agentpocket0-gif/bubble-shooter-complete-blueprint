extends Node

const SAVE_PATH := "user://classic_blast_save.json"
const SAVE_VERSION := 2
const MAX_LEVELS := 600
const MAX_LIVES := 5

var coins: int = 250
var lives: int = MAX_LIVES
var current_level: int = 1
var unlocked_level: int = 1
var stars: Dictionary = {}
var rewards_claimed: Dictionary = {}
var attempts: Dictionary = {}
var boosters: Dictionary = {"Bomb": 2, "Fireball": 1, "Rainbow": 2, "+5 Moves": 2}
var settings: Dictionary = {"music": true, "sound": true, "haptics": true, "language": "en"}
var tutorial_done: bool = false
var last_daily_spin_unix: int = 0
var pending_result: Dictionary = {}
var level_catalog: Array = []

func _ready() -> void:
    load_progress()

func load_progress() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        save_progress()
        return
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        push_warning("Save file could not be opened. Starting with safe defaults.")
        return
    var parsed = JSON.parse_string(file.get_as_text())
    file.close()
    if typeof(parsed) != TYPE_DICTIONARY:
        push_warning("Save file is invalid. Starting with safe defaults.")
        return
    var version := int(parsed.get("version", 1))
    coins = maxi(0, int(parsed.get("coins", coins)))
    lives = clampi(int(parsed.get("lives", lives)), 0, MAX_LIVES)
    current_level = clampi(int(parsed.get("current_level", current_level)), 1, MAX_LEVELS)
    unlocked_level = clampi(int(parsed.get("unlocked_level", unlocked_level)), 1, MAX_LEVELS)
    stars = _dictionary_or_empty(parsed.get("stars", {}))
    rewards_claimed = _dictionary_or_empty(parsed.get("rewards_claimed", {}))
    attempts = _dictionary_or_empty(parsed.get("attempts", {}))
    boosters = _dictionary_or_default(parsed.get("boosters", {}), boosters)
    settings = _dictionary_or_default(parsed.get("settings", {}), settings)
    tutorial_done = bool(parsed.get("tutorial_done", false))
    last_daily_spin_unix = maxi(0, int(parsed.get("last_daily_spin_unix", 0)))
    if version < SAVE_VERSION:
        save_progress()

func _dictionary_or_empty(value: Variant) -> Dictionary:
    return value if typeof(value) == TYPE_DICTIONARY else {}

func _dictionary_or_default(value: Variant, defaults: Dictionary) -> Dictionary:
    var result := defaults.duplicate(true)
    if typeof(value) == TYPE_DICTIONARY:
        for key in value:
            result[key] = value[key]
    return result

func save_progress() -> void:
    var payload := {
        "version": SAVE_VERSION,
        "coins": coins,
        "lives": lives,
        "current_level": current_level,
        "unlocked_level": unlocked_level,
        "stars": stars,
        "rewards_claimed": rewards_claimed,
        "attempts": attempts,
        "boosters": boosters,
        "settings": settings,
        "tutorial_done": tutorial_done,
        "last_daily_spin_unix": last_daily_spin_unix
    }
    var file := FileAccess.open(SAVE_PATH + ".tmp", FileAccess.WRITE)
    if file == null:
        push_error("Unable to write temporary save file.")
        return
    file.store_string(JSON.stringify(payload))
    file.close()
    var absolute_save := ProjectSettings.globalize_path(SAVE_PATH)
    var absolute_temp := ProjectSettings.globalize_path(SAVE_PATH + ".tmp")
    if FileAccess.file_exists(SAVE_PATH):
        var remove_error := DirAccess.remove_absolute(absolute_save)
        if remove_error != OK:
            push_error("Unable to replace old save file.")
            return
    var rename_error := DirAccess.rename_absolute(absolute_temp, absolute_save)
    if rename_error != OK:
        push_error("Unable to finalize save file.")

func begin_attempt(level_id: int) -> int:
    var key := str(clampi(level_id, 1, MAX_LEVELS))
    var next_attempt := int(attempts.get(key, 0)) + 1
    attempts[key] = next_attempt
    save_progress()
    return next_attempt

func complete_level(level_id: int, earned_stars: int, reward: int) -> bool:
    var safe_level := clampi(level_id, 1, MAX_LEVELS)
    var key := str(safe_level)
    stars[key] = maxi(int(stars.get(key, 0)), clampi(earned_stars, 1, 3))
    unlocked_level = mini(MAX_LEVELS, maxi(unlocked_level, safe_level + 1))
    var first_clear := not bool(rewards_claimed.get(key, false))
    if first_clear:
        coins += maxi(0, reward)
        rewards_claimed[key] = true
    save_progress()
    return first_clear

func get_level_data(level_id: int) -> Dictionary:
    var safe_id := clampi(level_id, 1, MAX_LEVELS)
    if level_catalog.is_empty():
        var pack_file := FileAccess.open("res://levels/campaign_600.json", FileAccess.READ)
        if pack_file != null:
            var parsed = JSON.parse_string(pack_file.get_as_text())
            pack_file.close()
            if typeof(parsed) == TYPE_DICTIONARY:
                var entries = parsed.get("levels", [])
                if typeof(entries) == TYPE_ARRAY:
                    level_catalog = entries
    if level_catalog.size() >= safe_id:
        var entry = level_catalog[safe_id - 1]
        if typeof(entry) == TYPE_DICTIONARY and int(entry.get("id", 0)) == safe_id:
            return entry.duplicate(true)
    var legacy_path := "res://levels/level_%03d.json" % safe_id
    if FileAccess.file_exists(legacy_path):
        var legacy_file := FileAccess.open(legacy_path, FileAccess.READ)
        if legacy_file != null:
            var legacy = JSON.parse_string(legacy_file.get_as_text())
            legacy_file.close()
            if typeof(legacy) == TYPE_DICTIONARY:
                return legacy
    push_error("Campaign level is missing: %d" % safe_id)
    return {}

func buy_booster(booster_name: String, price: int, amount: int = 1) -> bool:
    if price < 0 or amount <= 0 or coins < price:
        return false
    coins -= price
    boosters[booster_name] = int(boosters.get(booster_name, 0)) + amount
    save_progress()
    return true

func claim_daily_spin() -> bool:
    var now := int(Time.get_unix_time_from_system())
    if now - last_daily_spin_unix < 86400:
        return false
    coins += 250
    last_daily_spin_unix = now
    save_progress()
    return true

func daily_spin_seconds_remaining() -> int:
    var elapsed := int(Time.get_unix_time_from_system()) - last_daily_spin_unix
    return maxi(0, 86400 - elapsed)

func set_setting(setting_name: String, value: Variant) -> void:
    settings[setting_name] = value
    save_progress()

