extends Node

signal asset_manifest_loaded(success: bool)

const MANIFEST_PATH := "res://assets/manifest.json"
const ASSET_ROOT := "res://assets/"

var manifest: Dictionary = {}
var manifest_ready := false
var _resource_cache: Dictionary = {}


func _ready() -> void:
	load_manifest()


func load_manifest() -> bool:
	manifest_ready = false
	manifest.clear()
	_resource_cache.clear()

	if not FileAccess.file_exists(MANIFEST_PATH):
		push_warning("AssetRegistry: asset manifest is missing.")
		asset_manifest_loaded.emit(false)
		return false

	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		push_warning("AssetRegistry: asset manifest could not be opened.")
		asset_manifest_loaded.emit(false)
		return false

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()

	if not (parsed is Dictionary):
		push_warning("AssetRegistry: manifest root must be an object.")
		asset_manifest_loaded.emit(false)
		return false

	var registered_assets: Variant = parsed.get("assets", {})
	if not (registered_assets is Dictionary):
		push_warning("AssetRegistry: manifest assets field must be an object.")
		asset_manifest_loaded.emit(false)
		return false

	manifest = parsed
	manifest_ready = true
	asset_manifest_loaded.emit(true)
	return true


func get_registered_asset_count() -> int:
	var assets: Dictionary = manifest.get("assets", {})
	return assets.size()


func get_asset_path(asset_key: StringName) -> String:
	if not manifest_ready:
		return ""

	var assets: Dictionary = manifest.get("assets", {})
	var record: Variant = assets.get(String(asset_key))
	if not (record is Dictionary):
		return ""

	var relative_path := String(record.get("path", ""))
	if relative_path.is_empty() or relative_path.contains(".."):
		return ""

	var full_path := ASSET_ROOT.path_join(relative_path.trim_prefix("/"))
	if not full_path.begins_with(ASSET_ROOT):
		return ""

	return full_path


func has_asset(asset_key: StringName) -> bool:
	var path := get_asset_path(asset_key)
	return not path.is_empty() and ResourceLoader.exists(path)


func get_texture(asset_key: StringName) -> Texture2D:
	var resource := _load_resource(asset_key)
	return resource as Texture2D


func get_audio(asset_key: StringName) -> AudioStream:
	var resource := _load_resource(asset_key)
	return resource as AudioStream


func _load_resource(asset_key: StringName) -> Resource:
	var cache_key := String(asset_key)
	if _resource_cache.has(cache_key):
		return _resource_cache[cache_key] as Resource

	var path := get_asset_path(asset_key)
	if path.is_empty() or not ResourceLoader.exists(path):
		return null

	var resource := load(path)
	if resource == null:
		push_warning("AssetRegistry: failed to load asset key: " + cache_key)
		return null

	_resource_cache[cache_key] = resource
	return resource
