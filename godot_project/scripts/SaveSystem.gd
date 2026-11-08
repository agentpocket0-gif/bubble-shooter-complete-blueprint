class_name SaveSystem
extends RefCounted
## Atomic, versioned save file with tamper evidence.
##
## The payload is JSON; alongside it we store an HMAC-SHA256 of that payload
## keyed with a build constant mixed with a per-install salt. This is
## tamper *evidence*, not real security - a determined player with the APK can
## re-sign anything. It stops casual editing of coins and levels, which is what
## it is for. Anything that matters (purchases) is validated server-side.

const VERSION := 3
const BUILD_KEY := "classic-blast/save/v3"

static func salt_path() -> String:
	return "user://.install_salt"


static func _install_salt() -> String:
	if FileAccess.file_exists(salt_path()):
		var f := FileAccess.open(salt_path(), FileAccess.READ)
		if f != null:
			var s := f.get_as_text().strip_edges()
			f.close()
			if s.length() >= 16:
				return s
	var crypto := Crypto.new()
	var fresh := crypto.generate_random_bytes(24).hex_encode()
	var out := FileAccess.open(salt_path(), FileAccess.WRITE)
	if out != null:
		out.store_string(fresh)
		out.close()
	return fresh


static func hmac_hex(payload: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update((BUILD_KEY + _install_salt() + payload).to_utf8_buffer())
	return ctx.finish().hex_encode()


static func write_atomic(path: String, data: Dictionary) -> bool:
	# the signature is over the exact bytes we store, not a re-serialisation of
	# them: key order and float formatting must not change the hash
	var payload := JSON.stringify(data)
	var envelope := {
		"version": VERSION,
		"body": payload,
		"hmac": hmac_hex(payload),
	}
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("save: cannot open %s for write" % tmp)
		return false
	f.store_string(JSON.stringify(envelope))
	f.close()
	var dir := DirAccess.open(path.get_base_dir())
	if dir == null:
		return false
	# rename over the live file so a kill mid-write never leaves a truncated save
	if dir.file_exists(path):
		dir.remove(path)
	return dir.rename(tmp, path) == OK


static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_quarantine(path)
		return {}
	var env: Dictionary = parsed
	if not env.has("body") or not env.has("hmac"):
		_quarantine(path)
		return {}
	var payload_text := str(env["body"])
	if hmac_hex(payload_text) != str(env["hmac"]):
		push_warning("save: HMAC mismatch, keeping a backup and resetting")
		_quarantine(path)
		return {}
	var parsed_body: Variant = JSON.parse_string(payload_text)
	if typeof(parsed_body) != TYPE_DICTIONARY:
		_quarantine(path)
		return {}
	var payload: Dictionary = parsed_body
	var version := int(env.get("version", 0))
	if version > VERSION:
		# a newer build wrote this save; do not silently downgrade it
		_quarantine(path)
		return {}
	if version < VERSION:
		payload = _migrate(payload, version)
	return payload


static func _migrate(data: Dictionary, from_version: int) -> Dictionary:
	# forward migrations only, never backward
	if from_version < 2:
		if not data.has("boosters"):
			data["boosters"] = {"bomb": 1, "rainbow": 0, "swap": 2, "extra_moves": 3, "laser": 1}
	if from_version < 3:
		if not data.has("flags"):
			data["flags"] = {}
		data["flags"].merge({"tutorialDone": false, "adsRemoved": false}, true)
	return data


static func _quarantine(path: String) -> void:
	var backup := path + ".corrupt.%d" % Time.get_unix_time_from_system()
	var src := FileAccess.open(path, FileAccess.READ)
	if src == null:
		return
	var body := src.get_as_text()
	src.close()
	var dst := FileAccess.open(backup, FileAccess.WRITE)
	if dst != null:
		dst.store_string(body)
		dst.close()
	var dir := DirAccess.open(path.get_base_dir())
	if dir != null and dir.file_exists(path):
		dir.remove(path)
