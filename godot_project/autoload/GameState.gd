extends Node

const SAVE_PATH := "user://classic_blast_save.json"
const SAVE_VERSION := 3
const MAX_LEVELS := 600
const MAX_LIVES := 5
const LIFE_REFILL_SECONDS := 1800
const PIGGY_CAPACITY := 500
const MODES := ["classic", "hard", "challenge"]

var coins: int = 250
var lives: int = MAX_LIVES
var last_life_unix: int = 0
var current_level: int = 1
var unlocked_level: int = 1
var game_mode: String = "classic"
var mode_progress: Dictionary = {
    "classic": {"unlocked_level": 1, "stars": {}, "rewards_claimed": {}},
    "hard": {"unlocked_level": 1, "stars": {}, "rewards_claimed": {}},
    "challenge": {"unlocked_level": 1, "stars": {}, "rewards_claimed": {}}
}
var stars: Dictionary = {}
var rewards_claimed: Dictionary = {}
var attempts: Dictionary = {}
var boosters: Dictionary = {"Bomb": 2, "Fireball": 1, "Rainbow": 2, "+5 Moves": 2}
var settings: Dictionary = {"music": true, "sound": true, "haptics": true, "language": "en"}
var tutorial_done: bool = false
var last_daily_spin_unix: int = 0
var daily_spin_reward: String = ""
var piggy_bank_coins: int = 0
var pending_result: Dictionary = {}
var level_catalogs: Dictionary = {}

func _ready() -> void:
    load_progress()
    _refill_lives()

func _process(_delta: float) -> void:
    _refill_lives()

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
    last_life_unix = maxi(0, int(parsed.get("last_life_unix", 0)))
    current_level = clampi(int(parsed.get("current_level", current_level)), 1, MAX_LEVELS)
    unlocked_level = clampi(int(parsed.get("unlocked_level", unlocked_level)), 1, MAX_LEVELS)
    game_mode = str(parsed.get("game_mode", "classic"))
    if not MODES.has(game_mode):
        game_mode = "classic"

    stars = _dictionary_or_empty(parsed.get("stars", {}))
    rewards_claimed = _dictionary_or_empty(parsed.get("rewards_claimed", {}))
    attempts = _dictionary_or_empty(parsed.get("attempts", {}))
    boosters = _dictionary_or_default(parsed.get("boosters", {}), boosters)
    settings = _dictionary_or_default(parsed.get("settings", {}), settings)
    tutorial_done = bool(parsed.get("tutorial_done", false))
    last_daily_spin_unix = maxi(0, int(parsed.get("last_daily_spin_unix", 0)))
    daily_spin_reward = str(parsed.get("daily_spin_reward", ""))
    piggy_bank_coins = clampi(int(parsed.get("piggy_bank_coins", 0)), 0, PIGGY_CAPACITY)
    mode_progress = _normalise_mode_progress(parsed.get("mode_progress", {}))

    # Migrate the old v1/v2 campaign-only save without losing earned stars.
    if version < SAVE_VERSION:
        var classic: Dictionary = mode_progress["classic"]
        classic["unlocked_level"] = maxi(int(classic.get("unlocked_level", 1)), unlocked_level)
        classic["stars"] = _merge_dict(classic.get("stars", {}), stars)
        classic["rewards_claimed"] = _merge_dict(classic.get("rewards_claimed", {}), rewards_claimed)
        mode_progress["classic"] = classic
        if lives < MAX_LIVES and last_life_unix <= 0:
            last_life_unix = int(Time.get_unix_time_from_system())
        save_progress()

func _dictionary_or_empty(value: Variant) -> Dictionary:
    return value if typeof(value) == TYPE_DICTIONARY else {}

func _dictionary_or_default(value: Variant, defaults: Dictionary) -> Dictionary:
    var result: Dictionary = defaults.duplicate(true)
    if typeof(value) == TYPE_DICTIONARY:
        for key in value:
            result[key] = value[key]
    return result

func _merge_dict(base: Variant, extra: Dictionary) -> Dictionary:
    var result := _dictionary_or_empty(base).duplicate(true)
    for key in extra:
        if not result.has(key):
            result[key] = extra[key]
    return result

func _normalise_mode_progress(value: Variant) -> Dictionary:
    var result: Dictionary = {
        "classic": {"unlocked_level": 1, "stars": {}, "rewards_claimed": {}},
        "hard": {"unlocked_level": 1, "stars": {}, "rewards_claimed": {}},
        "challenge": {"unlocked_level": 1, "stars": {}, "rewards_claimed": {}}
    }
    if typeof(value) != TYPE_DICTIONARY:
        return result
    for mode in MODES:
        var source: Dictionary = _dictionary_or_empty(value.get(mode, {}))
        var target: Dictionary = result[mode]
        target["unlocked_level"] = clampi(int(source.get("unlocked_level", 1)), 1, MAX_LEVELS)
        target["stars"] = _dictionary_or_empty(source.get("stars", {}))
        target["rewards_claimed"] = _dictionary_or_empty(source.get("rewards_claimed", {}))
        result[mode] = target
    return result

func save_progress() -> void:
    var payload := {
        "version": SAVE_VERSION,
        "coins": coins,
        "lives": lives,
        "last_life_unix": last_life_unix,
        "current_level": current_level,
        "unlocked_level": unlocked_level,
        "game_mode": game_mode,
        "mode_progress": mode_progress,
        "stars": stars,
        "rewards_claimed": rewards_claimed,
        "attempts": attempts,
        "boosters": boosters,
        "settings": settings,
        "tutorial_done": tutorial_done,
        "last_daily_spin_unix": last_daily_spin_unix,
        "daily_spin_reward": daily_spin_reward,
        "piggy_bank_coins": piggy_bank_coins
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

func set_game_mode(mode: String) -> bool:
    if not MODES.has(mode):
        return false
    game_mode = mode
    current_level = clampi(current_level, 1, MAX_LEVELS)
    save_progress()
    return true

func get_mode_unlocked_level(mode: String = "") -> int:
    var selected := game_mode if mode.is_empty() else mode
    if not MODES.has(selected):
        selected = "classic"
    var progress: Dictionary = mode_progress.get(selected, {})
    var fallback := unlocked_level if selected == "classic" else 1
    return clampi(int(progress.get("unlocked_level", fallback)), 1, MAX_LEVELS)

func get_mode_stars(level_id: int, mode: String = "") -> int:
    var selected := game_mode if mode.is_empty() else mode
    if not MODES.has(selected):
        selected = "classic"
    var progress: Dictionary = mode_progress.get(selected, {})
    var earned: Dictionary = _dictionary_or_empty(progress.get("stars", {}))
    return int(earned.get(str(clampi(level_id, 1, MAX_LEVELS)), 0))

func get_mode_stars_total(mode: String = "") -> int:
    var selected := game_mode if mode.is_empty() else mode
    var progress: Dictionary = mode_progress.get(selected, {})
    var earned: Dictionary = _dictionary_or_empty(progress.get("stars", {}))
    var total := 0
    for value in earned.values():
        total += int(value)
    return total

func begin_attempt(level_id: int) -> int:
    var safe_level := clampi(level_id, 1, MAX_LEVELS)
    var key := "%s:%d" % [game_mode, safe_level]
    var next_attempt := int(attempts.get(key, 0)) + 1
    attempts[key] = next_attempt
    save_progress()
    return next_attempt

func _load_campaign_catalog() -> void:
    if not level_catalogs.is_empty():
        return
    var pack_file := FileAccess.open("res://levels/campaign_600.json", FileAccess.READ)
    if pack_file != null:
        var parsed = JSON.parse_string(pack_file.get_as_text())
        pack_file.close()
        if typeof(parsed) == TYPE_DICTIONARY:
            var modes: Dictionary = _dictionary_or_empty(parsed.get("modes", {}))
            for mode in MODES:
                var entries = modes.get(mode, [])
                if typeof(entries) == TYPE_ARRAY and entries.size() == MAX_LEVELS:
                    level_catalogs[mode] = entries
            var legacy_entries = parsed.get("levels", [])
            if not level_catalogs.has("classic") and typeof(legacy_entries) == TYPE_ARRAY:
                level_catalogs["classic"] = legacy_entries
    # A fallback keeps older project checkouts readable.
    if not level_catalogs.has("classic"):
        var legacy: Array = []
        for level_id in range(1, MAX_LEVELS + 1):
            var legacy_path := "res://levels/level_%03d.json" % level_id
            if not FileAccess.file_exists(legacy_path):
                break
            var file := FileAccess.open(legacy_path, FileAccess.READ)
            if file == null:
                break
            var entry = JSON.parse_string(file.get_as_text())
            file.close()
            if typeof(entry) != TYPE_DICTIONARY:
                break
            legacy.append(entry)
        level_catalogs["classic"] = legacy

func get_level_data(level_id: int, mode: String = "") -> Dictionary:
    var safe_id := clampi(level_id, 1, MAX_LEVELS)
    var selected := game_mode if mode.is_empty() else mode
    if not MODES.has(selected):
        selected = "classic"
    _load_campaign_catalog()
    var entries = level_catalogs.get(selected, [])
    if typeof(entries) == TYPE_ARRAY and entries.size() >= safe_id:
        var entry = entries[safe_id - 1]
        if typeof(entry) == TYPE_DICTIONARY and int(entry.get("id", 0)) == safe_id:
            return entry.duplicate(true)
    var classic_entries = level_catalogs.get("classic", [])
    if typeof(classic_entries) == TYPE_ARRAY and classic_entries.size() >= safe_id:
        var base = classic_entries[safe_id - 1]
        if typeof(base) == TYPE_DICTIONARY:
            return _build_mode_fallback(base, selected, safe_id)
    push_error("Campaign level is missing: %d (%s)" % [safe_id, selected])
    return {}

func _build_mode_fallback(base: Dictionary, mode: String, level_id: int) -> Dictionary:
    var data: Dictionary = base.duplicate(true)
    data["mode"] = mode
    if mode == "hard":
        data["shots"] = maxi(7, int(floor(float(data.get("shots", 20)) * 0.78)))
    elif mode == "challenge":
        data["shots"] = maxi(8, int(floor(float(data.get("shots", 20)) * 0.9)))
        var palette: Array = data.get("palette", [])
        if not palette.is_empty():
            data["objectives"] = [{"type": "clear_color", "color": str(palette[level_id % palette.size()])}]
    return data

func complete_level(level_id: int, earned_stars: int, reward: int) -> bool:
    var safe_level := clampi(level_id, 1, MAX_LEVELS)
    var progress: Dictionary = mode_progress.get(game_mode, {})
    var mode_stars: Dictionary = _dictionary_or_empty(progress.get("stars", {}))
    var mode_claims: Dictionary = _dictionary_or_empty(progress.get("rewards_claimed", {}))
    var key := str(safe_level)
    mode_stars[key] = maxi(int(mode_stars.get(key, 0)), clampi(earned_stars, 1, 3))
    progress["stars"] = mode_stars
    progress["unlocked_level"] = mini(MAX_LEVELS, maxi(int(progress.get("unlocked_level", 1)), safe_level + 1))
    var claim_key := "%s:%d" % [game_mode, safe_level]
    var first_clear := not bool(mode_claims.get(key, false))
    if first_clear:
        coins += maxi(0, reward)
        piggy_bank_coins = mini(PIGGY_CAPACITY, piggy_bank_coins + 10)
        mode_claims[key] = true
    progress["rewards_claimed"] = mode_claims
    mode_progress[game_mode] = progress
    rewards_claimed[claim_key] = first_clear
    if game_mode == "classic":
        unlocked_level = int(progress["unlocked_level"])
        stars[key] = int(mode_stars[key])
    save_progress()
    return first_clear

func buy_booster(booster_name: String, price: int, amount: int = 1) -> bool:
    if price < 0 or amount <= 0 or coins < price:
        return false
    coins -= price
    boosters[booster_name] = int(boosters.get(booster_name, 0)) + amount
    save_progress()
    return true

func spend_life() -> bool:
    _refill_lives()
    if lives <= 0:
        return false
    lives -= 1
    if lives < MAX_LIVES and last_life_unix <= 0:
        last_life_unix = int(Time.get_unix_time_from_system())
    save_progress()
    return true

func _refill_lives() -> void:
    if lives >= MAX_LIVES:
        lives = MAX_LIVES
        last_life_unix = 0
        return
    var now := int(Time.get_unix_time_from_system())
    if last_life_unix <= 0:
        last_life_unix = now
        return
    var elapsed := maxi(0, now - last_life_unix)
    var gained := int(floor(float(elapsed) / float(LIFE_REFILL_SECONDS)))
    if gained > 0:
        lives = mini(MAX_LIVES, lives + gained)
        if lives >= MAX_LIVES:
            last_life_unix = 0
        else:
            last_life_unix += gained * LIFE_REFILL_SECONDS
        save_progress()

func life_seconds_remaining() -> int:
    _refill_lives()
    if lives >= MAX_LIVES:
        return 0
    if last_life_unix <= 0:
        return LIFE_REFILL_SECONDS
    return maxi(0, LIFE_REFILL_SECONDS - (int(Time.get_unix_time_from_system()) - last_life_unix))

func claim_daily_spin() -> bool:
    var now := int(Time.get_unix_time_from_system())
    if now - last_daily_spin_unix < 86400:
        return false
    var rng := RandomNumberGenerator.new()
    rng.seed = int(floor(float(now) / 86400.0))
    var roll := rng.randi_range(0, 99)
    var prize := 100
    if roll >= 85:
        prize = 500
    elif roll >= 50:
        prize = 250
    coins += prize
    last_daily_spin_unix = now
    daily_spin_reward = "%d coins" % prize
    save_progress()
    return true

func daily_spin_seconds_remaining() -> int:
    var elapsed := int(Time.get_unix_time_from_system()) - last_daily_spin_unix
    return maxi(0, 86400 - elapsed)

func claim_piggy_bank() -> bool:
    if piggy_bank_coins < PIGGY_CAPACITY:
        return false
    coins += piggy_bank_coins
    piggy_bank_coins = 0
    save_progress()
    return true

func set_setting(setting_name: String, value: Variant) -> void:
    settings[setting_name] = value
    save_progress()
