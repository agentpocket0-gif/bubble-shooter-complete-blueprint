extends Control
## Result screen - a state, not a popup, so the win/lose side effects happen
## exactly once even if the app is killed straight after.

var _doubled := false
var _coins_granted := 0


func _ready() -> void:
	GameManager.state = GameManager.State.RESULT_WIN if bool(GameManager.last_result.get("won", false)) \
		else GameManager.State.RESULT_LOSE
	_build()


func _build() -> void:
	var r := GameManager.last_result
	var won := bool(r.get("won", false))
	var stars := int(r.get("stars", 0))
	_coins_granted = int(r.get("coins", 0))

	var bg := ColorRect.new()
	bg.color = Color("#12121A")
	UI.full_rect(bg)
	add_child(bg)

	var panel := UI.popup(920)
	panel.position = Vector2(80, 420)
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 26)
	panel.add_child(col)

	col.add_child(UI.title("LEVEL COMPLETE" if won else "OUT OF SHOTS", 62))

	var star_row := UI.star_row(stars, 110)
	col.add_child(star_row)
	star_row.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(star_row, "modulate:a", 1.0, 0.3)
	tw.tween_callback(func() -> void: AudioManager.play("sfx_level_win") if won else AudioManager.play("sfx_level_fail"))

	col.add_child(UI.label("Score  %d" % int(r.get("score", 0)), 44, UI.INK, HORIZONTAL_ALIGNMENT_CENTER))
	if won:
		col.add_child(UI.label("+%d coins" % _coins_granted, 44, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	else:
		col.add_child(UI.label(str(r.get("reason", "")), 34, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))

	# rewarded double reward: opt-in, never automatic, only when ads are live
	if won and RemoteConfigAndAds.can_show_rewarded():
		var dbl := UI.button("Watch ad  ->  double reward", false)
		dbl.pressed.connect(_on_double_pressed.bind(dbl))
		col.add_child(dbl)

	var next_id := int(r.get("level", 1)) + 1
	if won and next_id <= GameManager.LEVEL_COUNT:
		var next := UI.button("Next level", true)
		next.pressed.connect(func() -> void:
			RemoteConfigAndAds.maybe_show_interstitial(int(r.get("level", 1)))
			GameManager.start_level(next_id))
		col.add_child(next)

	var retry := UI.button("Retry", not won)
	retry.pressed.connect(func() -> void: GameManager.retry_level())
	col.add_child(retry)

	var map := UI.button("Map", false)
	map.pressed.connect(func() -> void: GameManager.open_map())
	col.add_child(map)

	var stats := UI.label("%d bubbles popped  ·  %d stars total" % [
		int(r.get("popped", 0)), GameManager.total_stars()], 32, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(stats)


func _on_double_pressed(dbl: Button) -> void:
	RemoteConfigAndAds.show_rewarded("double_reward", _on_double_result.bind(dbl))


func _on_double_result(ok: bool, dbl: Button) -> void:
	if ok and not _doubled:
		_doubled = true
		GameManager.add_coins(_coins_granted)
		dbl.text = "Doubled!"
	elif not ok:
		dbl.text = "Ads are off right now"
