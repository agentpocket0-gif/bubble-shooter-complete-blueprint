class_name LevelLibrary
extends RefCounted
## Reads levels/index.json and the per-level JSON files. A designer adds a file,
## re-runs tools/levelgen.py --reindex, and it shows up in the game: no code change.

const INDEX_PATH := "res://levels/index.json"

static var _index: Array = []
static var _cache: Dictionary = {}


static func index() -> Array:
	if not _index.is_empty():
		return _index
	var f := FileAccess.open(INDEX_PATH, FileAccess.READ)
	if f == null:
		push_error("LevelLibrary: missing %s" % INDEX_PATH)
		return []
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return []
	_index = parsed.get("levels", [])
	return _index


static func count() -> int:
	return index().size()


static func entry(level_id: int) -> Dictionary:
	for e in index():
		if int(e.get("id", -1)) == level_id:
			return e
	return {}


static func load_level(level_id: int) -> Dictionary:
	if _cache.has(level_id):
		return _cache[level_id]
	var e := entry(level_id)
	if e.is_empty():
		push_error("LevelLibrary: no index entry for level %d" % level_id)
		return {}
	var path := "res://levels/" + str(e.get("file", ""))
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("LevelLibrary: cannot open %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	_cache[level_id] = parsed
	return parsed


static func world_of(level_id: int) -> int:
	var e := entry(level_id)
	return int(e.get("world", 1))


static func name_of(level_id: int) -> String:
	var e := entry(level_id)
	return str(e.get("name", "Level %d" % level_id))
