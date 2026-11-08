class_name Rng32
extends RefCounted
## xorshift32, identical to the Python generator so a level's colour queue is
## reproducible from (level id, attempt index) in both languages.

var state: int = 0


func _init(seed_value: int = 1) -> void:
	state = seed_value & 0xFFFFFFFF
	if state == 0:
		state = 0x9E3779B9


func next() -> int:
	var x := state
	x ^= (x << 13) & 0xFFFFFFFF
	x ^= x >> 17
	x ^= (x << 5) & 0xFFFFFFFF
	state = x & 0xFFFFFFFF
	return state


func next_range(n: int) -> int:
	if n <= 0:
		return 0
	return next() % n


static func seed_for(level_id: int, attempt: int) -> int:
	return ((level_id * 2654435761) ^ (attempt * 40503) ^ 0x5EED) & 0x7FFFFFFF
