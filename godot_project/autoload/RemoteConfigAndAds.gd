extends Node
## Remote config + the 1-click deferred ad system.
##
## Ship with ads OFF. The bundled config says `ads_enabled: false`; the same
## file is fetched from the repository on launch and cached, so flipping ads on
## later is one edit in `config/live_monetization_config.json` - no store
## update, no rebuild.
##
## Safety rules baked in (blueprint 04/05 + store policy):
##   * no interstitial in the player's first session
##   * no interstitial in the first 3 minutes of a session
##   * interstitial cooldown 120 s, hard cap 8 per day
##   * rewarded is always opt-in, never auto-played
##   * consent must be answered before any ad request in EEA/UK
##   * every ad is gated behind `ads_enabled` AND a non-placeholder unit id

signal config_ready()
signal ad_finished(placement: String, rewarded: bool)
signal consent_required()

const CONFIG_PATH := "res://config/live_monetization_config.json"
const CACHE_PATH := "user://remote_config_cache.json"
const CACHE_TTL_SECONDS := 6 * 60 * 60
const FIRST_AD_DELAY_SECONDS := 180
const INTERSTITIAL_DAILY_CAP := 8

var config: Dictionary = {}
var remote_status := "bundled"
var consent_answered := false
var consent_grants_ads := false

var _http: HTTPRequest
var _session_started_ms := 0
var _last_interstitial_ms := 0
var _pending_callback: Callable = Callable()
var _pending_placement := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_session_started_ms = Time.get_ticks_msec()
	load_bundled()
	load_cache()
	_fetch_remote.call_deferred()


# --------------------------------------------------------------------------- #
# config
# --------------------------------------------------------------------------- #
func load_bundled() -> void:
	var f := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if f == null:
		push_error("ads: bundled config missing at %s" % CONFIG_PATH)
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		config = parsed


func load_cache() -> void:
	if not FileAccess.file_exists(CACHE_PATH):
		return
	var f := FileAccess.open(CACHE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var fetched_at := int(parsed.get("fetched_at", 0))
	if Time.get_unix_time_from_system() - fetched_at > CACHE_TTL_SECONDS:
		return
	var body: Variant = parsed.get("config", null)
	if typeof(body) == TYPE_DICTIONARY:
		config = _merge(config, body)
		remote_status = "cached"


func _fetch_remote() -> void:
	var url := str(config.get("remote_config_url", ""))
	if url == "" or not url.begins_with("http"):
		remote_status = "bundled"
		config_ready.emit()
		return
	_http = HTTPRequest.new()
	_http.timeout = 8.0
	_http.use_threads = true
	add_child(_http)
	_http.request_completed.connect(_on_remote_done)
	var err := _http.request(url)
	if err != OK:
		remote_status = "bundled"
		config_ready.emit()


func _on_remote_done(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if code == 200:
		var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
		if typeof(parsed) == TYPE_DICTIONARY:
			config = _merge(config, parsed)
			remote_status = "remote"
			var f := FileAccess.open(CACHE_PATH, FileAccess.WRITE)
			if f != null:
				f.store_string(JSON.stringify({"fetched_at": int(Time.get_unix_time_from_system()),
					"config": parsed}))
				f.close()
	config_ready.emit()


func _merge(base: Dictionary, over: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	for k in over.keys():
		if typeof(over[k]) == TYPE_DICTIONARY and typeof(out.get(k, null)) == TYPE_DICTIONARY:
			out[k] = _merge(out[k], over[k])
		else:
			out[k] = over[k]
	return out


# --------------------------------------------------------------------------- #
# gates
# --------------------------------------------------------------------------- #
func ads_enabled() -> bool:
	if not bool(config.get("ads_enabled", false)):
		return false
	if GameManager.flag("adsRemoved"):
		return false
	return true


func test_mode() -> bool:
	return bool(config.get("test_ads_simulation", false))


func _unit_id(kind: String) -> String:
	var platform := "android" if OS.get_name() in ["Android", "Linux", "Windows", "macOS"] else "ios"
	if OS.get_name() == "iOS":
		platform = "ios"
	var ids: Dictionary = config.get(platform + "_ad_ids", {})
	return str(ids.get(kind + "_id", ""))


func _unit_ready(kind: String) -> bool:
	var id := _unit_id(kind)
	if id == "" or id.begins_with("REPLACE"):
		return false
	return true


func session_seconds() -> int:
	return int((Time.get_ticks_msec() - _session_started_ms) / 1000)


func can_show_interstitial(level_id: int) -> bool:
	if not ads_enabled():
		return false
	if test_mode():
		return true
	if not _unit_ready("interstitial"):
		return false
	if not consent_answered or not consent_grants_ads:
		return false
	if GameManager.stat("sessionCount") <= 1:
		return false                      # never in the first session
	if session_seconds() < FIRST_AD_DELAY_SECONDS:
		return false                      # never in the first 3 minutes
	var rules: Dictionary = config.get("ad_rules", {})
	if level_id < int(rules.get("interstitial_min_level", 6)):
		return false
	var cooldown := int(rules.get("interstitial_cooldown_seconds", 120))
	if (Time.get_ticks_msec() - _last_interstitial_ms) < cooldown * 1000:
		return false
	var today := int(Time.get_unix_time_from_system() / 86400)
	var last_day := int(GameManager.data["stats"].get("adDay", today))
	if last_day != today:
		GameManager.data["stats"]["adDay"] = today
		GameManager.data["stats"]["adImpressionsToday"] = 0
	if int(GameManager.stat("adImpressionsToday")) >= INTERSTITIAL_DAILY_CAP:
		return false
	return true


func can_show_rewarded() -> bool:
	if not ads_enabled():
		return false
	if test_mode():
		return true
	return _unit_ready("rewarded") and consent_answered and consent_grants_ads


# --------------------------------------------------------------------------- #
# playback
# --------------------------------------------------------------------------- #
func show_rewarded(placement: String, on_done: Callable) -> bool:
	if not can_show_rewarded():
		# ads are off by design right now: tell the caller honestly
		on_done.call(false)
		return false
	_pending_callback = on_done
	_pending_placement = placement
	if test_mode() or not _native_available():
		_simulate_rewarded(placement)
		return true
	var bridge := _native()
	bridge.call("showRewarded", _unit_id("rewarded"), placement)
	return true


func maybe_show_interstitial(level_id: int) -> void:
	if not can_show_interstitial(level_id):
		return
	_last_interstitial_ms = Time.get_ticks_msec()
	GameManager.add_stat("adImpressionsToday")
	GameManager.data["stats"]["lastAdTs"] = int(Time.get_unix_time_from_system())
	GameManager.save()
	if test_mode() or not _native_available():
		ad_finished.emit("interstitial", false)
		return
	_native().call("showInterstitial", _unit_id("interstitial"))


func _simulate_rewarded(placement: String) -> void:
	# A simulated rewarded ad still has to behave like one: the reward is
	# granted by the callback, never by the button that opened it.
	await get_tree().create_timer(0.4).timeout
	_finish_ad(placement, true)


func _finish_ad(placement: String, rewarded: bool) -> void:
	var cb := _pending_callback
	_pending_callback = Callable()
	_pending_placement = ""
	ad_finished.emit(placement, rewarded)
	if cb.is_valid():
		cb.call(rewarded)


# --------------------------------------------------------------------------- #
# consent (Google UMP on device, a local gate everywhere else)
# --------------------------------------------------------------------------- #
func request_consent_if_needed() -> void:
	if consent_answered:
		return
	if _native_available():
		var bridge := _native()
		if bridge.has_method("requestConsent"):
			bridge.call("requestConsent")
			return
	# No native UMP available: default to ads off until the player opts in.
	consent_required.emit()


func set_consent(granted: bool) -> void:
	consent_answered = true
	consent_grants_ads = granted


# --------------------------------------------------------------------------- #
# native bridge (Android AAR / iOS framework named ClassicBlastAds)
# --------------------------------------------------------------------------- #
func _native_available() -> bool:
	if not OS.has_feature("mobile"):
		return false
	return Engine.has_singleton("ClassicBlastAds")


func _native() -> Object:
	return Engine.get_singleton("ClassicBlastAds")


## Called from the native side when a rewarded ad closes.
func _on_native_rewarded(placement: String, rewarded: bool) -> void:
	_finish_ad(placement, rewarded)


func iap_enabled() -> bool:
	return bool(config.get("iap_enabled", true))


func sku(id: String) -> Dictionary:
	var skus: Dictionary = config.get("iap_skus", {})
	return skus.get(id, {})


func ad_rules() -> Dictionary:
	return config.get("ad_rules", {})
