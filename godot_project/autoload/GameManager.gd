extends Node
## Global state machine, progression, wallet and lives.
##
## One owner per state: only this node starts and stops scenes. Scenes never
## call each other. Overlays live inside a scene, not in this machine.
## Save on transition, never on a timer.

enum State { BOOT, SPLASH, SAGA_MAP, LEVEL_PLAY, RESULT_WIN, RESULT_LOSE }

const SAVE_PATH := "user://save_data.json"
const MAX_LIVES := 5
const LIFE_SECONDS := 30 * 60
const LEVEL_COUNT := 120

signal state_changed(new_state: int)
signal wallet_changed()
signal lives_changed()

var state: int = State.BOOT
var data: Dictionary = {}
var current_level_id: int = 1
var last_result: Dictionary = {}
var attempt_index: int = 0
var pending_level_id: int = 1
## Set by the QA harness so a button press can be exercised without the scene
## tree being torn down underneath the test.
var suppress_scene_changes := false
## Extra shots granted by the "continue" offer on the lose screen. Consumed by
## the next Gameplay boot, and never charged as a life.
var pending_bonus_shots := 0

var _lives_tick := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_or_create()


func _process(delta: float) -> void:
	_lives_tick += delta
	if _lives_tick < 1.0:
		return
	_lives_tick = 0.0
	if refill_lives():
		save()


# --------------------------------------------------------------------------- #
# save data
# --------------------------------------------------------------------------- #
func _default_save() -> Dictionary:
	return {
		"version": 3,
		"progress": {"maxLevel": 1, "stars": {}, "best": {}},
		"wallet": {"coins": 300},
		"lives": {"count": MAX_LIVES, "lastRefillTs": int(Time.get_unix_time_from_system())},
		"boosters": {"bomb": 1, "rainbow": 0, "swap": 2, "extra_moves": 3, "laser": 1},
		"flags": {"tutorialDone": false, "firstPurchaseDone": false, "adsRemoved": false,
			"introSeen": false, "rated": false},
		"stats": {"levelsPlayed": 0, "levelsWon": 0, "bubblesPopped": 0,
			"adImpressionsToday": 0, "lastAdTs": 0, "sessionCount": 0,
			"piggyFill": 0, "lastSpinTs": 0, "spinStreak": 0},
	}


func load_or_create() -> void:
	data = SaveSystem.read(SAVE_PATH)
	if data.is_empty():
		data = _default_save()
		data["stats"]["sessionCount"] = 1
	else:
		data["stats"]["sessionCount"] = int(data["stats"].get("sessionCount", 0)) + 1
		_ensure_shape()
	refill_lives()
	save()


func _ensure_shape() -> void:
	var base := _default_save()
	for key in base.keys():
		if not data.has(key):
			data[key] = base[key]
		elif typeof(data[key]) == TYPE_DICTIONARY:
			for sub in base[key].keys():
				if not data[key].has(sub):
					data[key][sub] = base[key][sub]


func save() -> void:
	SaveSystem.write_atomic(SAVE_PATH, data)


# --------------------------------------------------------------------------- #
# state machine
# --------------------------------------------------------------------------- #
func go_to(new_state: int, scene_path: String = "") -> void:
	state = new_state
	state_changed.emit(state)
	if scene_path != "" and not suppress_scene_changes:
		# deferred: a state change is often requested from _ready(), and the
		# scene tree is busy adding children at that moment
		get_tree().call_deferred("change_scene_to_file", scene_path)


func open_map() -> void:
	save()
	go_to(State.SAGA_MAP, "res://scenes/SagaMap.tscn")


func open_splash() -> void:
	go_to(State.SPLASH, "res://scenes/Splash.tscn")


func start_level(level_id: int) -> bool:
	if not spend_life():
		return false
	current_level_id = level_id
	attempt_index = 0
	save()
	go_to(State.LEVEL_PLAY, "res://scenes/Gameplay.tscn")
	return true


## Restart the current level without spending another life. The attempt index
## advances, so the colour queue is reproducible but not identical to the run
## the player just lost.
## Continue after a loss: keep the same level, hand out extra shots, no life.
func continue_level(bonus_shots: int) -> void:
	pending_bonus_shots = bonus_shots
	attempt_index += 1
	save()
	go_to(State.LEVEL_PLAY, "res://scenes/Gameplay.tscn")


func retry_level() -> void:
	attempt_index += 1
	save()
	go_to(State.LEVEL_PLAY, "res://scenes/Gameplay.tscn")


func finish_level(won: bool, result: Dictionary) -> void:
	last_result = result
	last_result["level"] = current_level_id
	last_result["won"] = won
	if won:
		var stars := int(result.get("stars", 1))
		var stars_map: Dictionary = data["progress"]["stars"]
		var key := str(current_level_id)
		if int(stars_map.get(key, 0)) < stars:
			stars_map[key] = stars
		data["progress"]["maxLevel"] = max(int(data["progress"]["maxLevel"]),
			min(current_level_id + 1, LEVEL_COUNT))
		data["stats"]["levelsWon"] = int(data["stats"]["levelsWon"]) + 1
	data["stats"]["levelsPlayed"] = int(data["stats"]["levelsPlayed"]) + 1
	data["stats"]["bubblesPopped"] = int(data["stats"]["bubblesPopped"]) + int(result.get("popped", 0))
	save()
	go_to(State.RESULT_WIN if won else State.RESULT_LOSE, "res://scenes/Result.tscn")


# --------------------------------------------------------------------------- #
# progression
# --------------------------------------------------------------------------- #
func max_level() -> int:
	return int(data["progress"]["maxLevel"])


func is_unlocked(level_id: int) -> bool:
	return level_id <= max_level()


func stars_for(level_id: int) -> int:
	return int(data["progress"]["stars"].get(str(level_id), 0))


func total_stars() -> int:
	var n := 0
	for v in data["progress"]["stars"].values():
		n += int(v)
	return n


# --------------------------------------------------------------------------- #
# wallet and lives
# --------------------------------------------------------------------------- #
func coins() -> int:
	return int(data["wallet"]["coins"])


func add_coins(n: int) -> void:
	data["wallet"]["coins"] = max(0, coins() + n)
	wallet_changed.emit()
	save()


func spend_coins(n: int) -> bool:
	if coins() < n:
		return false
	data["wallet"]["coins"] = coins() - n
	wallet_changed.emit()
	save()
	return true


func lives() -> int:
	return int(data["lives"]["count"])


func spend_life() -> bool:
	if lives() <= 0:
		return false
	if lives() == MAX_LIVES:
		data["lives"]["lastRefillTs"] = int(Time.get_unix_time_from_system())
	data["lives"]["count"] = lives() - 1
	lives_changed.emit()
	save()
	return true


func add_life(n: int = 1) -> void:
	data["lives"]["count"] = min(MAX_LIVES, lives() + n)
	if lives() == MAX_LIVES:
		data["lives"]["lastRefillTs"] = int(Time.get_unix_time_from_system())
	lives_changed.emit()
	save()


func refill_lives() -> bool:
	var now := int(Time.get_unix_time_from_system())
	var count := lives()
	if count >= MAX_LIVES:
		data["lives"]["lastRefillTs"] = now
		return false
	var last := int(data["lives"].get("lastRefillTs", now))
	if last > now:
		last = now
	var gained := int((now - last) / LIFE_SECONDS)
	if gained <= 0:
		return false
	data["lives"]["count"] = min(MAX_LIVES, count + gained)
	data["lives"]["lastRefillTs"] = now if lives() >= MAX_LIVES else last + gained * LIFE_SECONDS
	lives_changed.emit()
	return true


func seconds_to_next_life() -> int:
	if lives() >= MAX_LIVES:
		return 0
	var now := int(Time.get_unix_time_from_system())
	var last := int(data["lives"].get("lastRefillTs", now))
	return maxi(0, LIFE_SECONDS - (now - last))


func lives_label() -> String:
	var s := seconds_to_next_life()
	if s <= 0:
		return "FULL"
	return "%02d:%02d" % [s / 60, s % 60]


# --------------------------------------------------------------------------- #
# boosters
# --------------------------------------------------------------------------- #
func booster_count(kind: String) -> int:
	return int(data["boosters"].get(kind, 0))


func take_booster(kind: String) -> bool:
	if booster_count(kind) <= 0:
		return false
	data["boosters"][kind] = booster_count(kind) - 1
	save()
	return true


func grant_booster(kind: String, n: int = 1) -> void:
	data["boosters"][kind] = booster_count(kind) + n
	save()


func flag(key: String) -> bool:
	return bool(data["flags"].get(key, false))


func set_flag(key: String, value: bool) -> void:
	data["flags"][key] = value
	save()


func stat(key: String) -> int:
	return int(data["stats"].get(key, 0))


func add_stat(key: String, n: int = 1) -> void:
	data["stats"][key] = stat(key) + n
	save()
