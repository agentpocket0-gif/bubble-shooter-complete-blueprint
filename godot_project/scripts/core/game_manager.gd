extends Node

signal app_state_changed(previous_state: int, next_state: int)
signal overlay_stack_changed(overlays: Array[StringName])

enum AppState {
	BOOT,
	SPLASH,
	PRELOAD,
	MAP,
	LEVEL,
	RESULT
}

var current_state: int = AppState.BOOT
var _overlay_stack: Array[StringName] = []


func change_state(next_state: int) -> void:
	if current_state == next_state:
		return

	var previous_state := current_state
	current_state = next_state
	app_state_changed.emit(previous_state, current_state)


func push_overlay(overlay_id: StringName) -> bool:
	if overlay_id == &"" or _overlay_stack.has(overlay_id):
		return false

	_overlay_stack.push_back(overlay_id)
	overlay_stack_changed.emit(_overlay_stack.duplicate())
	return true


func pop_overlay() -> StringName:
	if _overlay_stack.is_empty():
		return &""

	var removed: StringName = _overlay_stack.pop_back()
	overlay_stack_changed.emit(_overlay_stack.duplicate())
	return removed


func has_overlay(overlay_id: StringName) -> bool:
	return _overlay_stack.has(overlay_id)


func handle_back() -> bool:
	if _overlay_stack.is_empty():
		return false

	pop_overlay()
	return true


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		if handle_back():
			get_viewport().set_input_as_handled()
