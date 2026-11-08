class_name LevelLibrary
extends RefCounted
## Generates every level locally from the player's persistent campaign seed.
## The bundled 120-level JSON set is retained as historical reference content,
## but progression is not capped and no fixed level file is required to play.

const PREVIEW_LEVELS := 120
const PROCEDURAL = preload("res://scripts/ProceduralLevelGenerator.gd")
const INDEX_PATH := "res://levels/index.json"

static var _index: Array = []
static var _cache: Dictionary = {}


static func index() -> Array:
	# Legacy catalogue for tools and QA only. Runtime levels are not read from it.
	if not _index.is_empty():
		return _index
	var f := FileAccess.open(INDEX_PATH, FileAccess.READ)
	if f == null:
		return []
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		_index = parsed.get("levels", [])
	return _index


static func count() -> int:
	# Show the campaign plus a short unlocked preview, so the saga map can grow
	# forever without building an infinite number of buttons at once.
	var available := PREVIEW_LEVELS
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		var manager := tree.root.get_node_or_null("GameManager")
		if manager != null:
			available = maxi(available, int(manager.call("max_level")) + 20)
	return available


static func entry(level_id: int) -> Dictionary:
	if level_id < 1:
		return {}
	return {
		"id": level_id,
		"world": world_of(level_id),
		"file": "",
		"name": name_of(level_id)
	}


static func load_level(level_id: int) -> Dictionary:
	if level_id < 1:
		push_error("LevelLibrary: level id must be positive")
		return {}
	if _cache.has(level_id):
		return _cache[level_id]
	var generated: Dictionary = PROCEDURAL.generate(level_id, GameManager.campaign_seed())
	if generated.is_empty() or not _is_valid_generated_level(generated):
		push_error("LevelLibrary: procedural generation failed for level %d" % level_id)
		return {}
	_cache[level_id] = generated
	return generated


static func _is_valid_generated_level(level: Dictionary) -> bool:
	var cols := int(level.get("grid", {}).get("cols", 0))
	var rows := int(level.get("grid", {}).get("rows", 0))
	var layout: Array = level.get("layout", [])
	if cols < 9 or rows < 10 or layout.size() != rows:
		return false
	if level.get("palette", []).size() < 3 or level.get("objectives", []).is_empty():
		return false
	for r in range(layout.size()):
		var max_len := cols if r % 2 == 0 else cols - 1
		if str(layout[r]).length() != max_len:
			return false
	return int(level.get("shots", 0)) >= 5


static func world_of(level_id: int) -> int:
	return int(floor(float(maxi(1, level_id) - 1) / 20.0)) + 1


static func name_of(level_id: int) -> String:
	if level_id < 1:
		return "Level"
	var generated: Dictionary = PROCEDURAL.generate(level_id, GameManager.campaign_seed())
	return str(generated.get("name", "Level %d" % level_id))
