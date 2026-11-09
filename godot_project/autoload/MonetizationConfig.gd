extends Node

const CONFIG_PATH := "res://config/live_monetization_config.json"
var ads_enabled := false
var iap_enabled := false
var review_mode := true

func _ready() -> void:
    _load_configuration()

func _load_configuration() -> void:
    ads_enabled = false
    iap_enabled = false
    review_mode = true
    if not FileAccess.file_exists(CONFIG_PATH):
        push_warning("Monetization config missing; ads and IAP remain disabled.")
        return
    var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
    if file == null:
        push_warning("Monetization config cannot be read; monetization remains disabled.")
        return
    var parsed = JSON.parse_string(file.get_as_text())
    file.close()
    if typeof(parsed) != TYPE_DICTIONARY:
        push_warning("Monetization config is invalid; monetization remains disabled.")
        return
    ads_enabled = bool(parsed.get("ads_enabled", false))
    iap_enabled = bool(parsed.get("iap_enabled", false))
    review_mode = bool(parsed.get("review_mode", true))
