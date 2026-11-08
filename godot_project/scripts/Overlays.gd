class_name Overlays
extends RefCounted
## Modal overlays: store, daily spin, piggy bank, settings, out of lives.
## Overlays are not states - they stack above the current screen and the back
## button pops them before it changes state.

const W := 900.0


static func _modal(parent: Control, title_text: String) -> Dictionary:
	var root := Control.new()
	UI.full_rect(root)
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(root)
	root.add_child(UI.scrim())

	var panel := UI.popup(W)
	panel.position = Vector2((1080.0 - W) / 2.0, 420)
	root.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 24)
	panel.add_child(col)
	col.add_child(UI.title(title_text, 60))

	AudioManager.play("sfx_popup_open")
	panel.scale = Vector2(0.85, 0.85)
	panel.pivot_offset = Vector2(W / 2.0, 200)
	var tw := panel.create_tween()
	tw.tween_property(panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	return {"root": root, "panel": panel, "column": col}


static func _close(ctx: Dictionary) -> void:
	AudioManager.play("sfx_popup_close")
	(ctx["root"] as Node).queue_free()


static func _close_button(ctx: Dictionary, col: VBoxContainer) -> void:
	var b := UI.button("Close", false)
	b.pressed.connect(func() -> void: _close(ctx))
	col.add_child(b)


# --------------------------------------------------------------------------- #
# store
# --------------------------------------------------------------------------- #
static func show_store(parent: Control) -> void:
	var ctx := _modal(parent, "STORE")
	var col: VBoxContainer = ctx["column"]

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(W - 80, 760)
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 18)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	for row in StoreAndEconomy.skus():
		var id := str(row["id"])
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 18)
		var name_label := UI.label(StoreAndEconomy.sku_title(id), 40, UI.INK)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(name_label)
		var price := UI.label(str(row.get("price", "—")), 40, UI.ACCENT)
		line.add_child(price)
		var buy := UI.button("Buy", true, 34)
		buy.custom_minimum_size = Vector2(180, 100)
		buy.pressed.connect(func() -> void:
			StoreAndEconomy.purchase(id)
			_close(ctx))
		line.add_child(buy)
		list.add_child(line)

	var divider := UI.label("Boosters", 38, UI.MUTED)
	list.add_child(divider)
	for booster in ["swap", "laser", "extra_moves", "bomb", "rainbow"]:
		var line2 := HBoxContainer.new()
		line2.add_theme_constant_override("separation", 18)
		var nm := UI.label("%s  x%d" % [StoreAndEconomy.booster_label(booster),
			GameManager.booster_count(booster)], 38, UI.INK)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line2.add_child(nm)
		var cost := UI.label("%d" % StoreAndEconomy.price_of(booster), 38, UI.ACCENT)
		line2.add_child(cost)
		var buy2 := UI.button("Buy", false, 34)
		buy2.custom_minimum_size = Vector2(180, 100)
		buy2.pressed.connect(func() -> void:
			if StoreAndEconomy.buy_booster(booster):
				_close(ctx))
		line2.add_child(buy2)
		list.add_child(line2)

	_close_button(ctx, col)


# --------------------------------------------------------------------------- #
# daily spin
# --------------------------------------------------------------------------- #
static func show_spin(parent: Control) -> void:
	var ctx := _modal(parent, "DAILY SPIN")
	var col: VBoxContainer = ctx["column"]

	var wheel := TextureRect.new()
	wheel.texture = UI.icon("icon_spin", true)
	wheel.custom_minimum_size = Vector2(320, 320)
	wheel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wheel.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	col.add_child(wheel)

	var result_label := UI.label("", 42, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(result_label)

	var spin := UI.button("SPIN", true)
	col.add_child(spin)
	if not StoreAndEconomy.spin_ready():
		spin.disabled = true
		spin.text = "Come back in %d h" % (StoreAndEconomy.spin_wait_seconds() / 3600 + 1)

	spin.pressed.connect(func() -> void:
		var prize := StoreAndEconomy.do_spin()
		if prize.is_empty():
			return
		spin.disabled = true
		var tw := wheel.create_tween()
		tw.tween_property(wheel, "rotation", TAU * 3.0, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		match str(prize.get("kind", "")):
			"coins":
				result_label.text = "+%d coins" % int(prize["amount"])
			"booster":
				result_label.text = "+%d %s" % [int(prize["amount"]),
					StoreAndEconomy.booster_label(str(prize["booster"]))]
			"life":
				result_label.text = "+1 life"
		AudioManager.play("sfx_ad_reward"))

	_close_button(ctx, col)


# --------------------------------------------------------------------------- #
# piggy bank
# --------------------------------------------------------------------------- #
static func show_piggy(parent: Control) -> void:
	var ctx := _modal(parent, "PIGGY BANK")
	var col: VBoxContainer = ctx["column"]

	var icon := TextureRect.new()
	icon.texture = UI.icon("icon_piggy", true)
	icon.custom_minimum_size = Vector2(200, 200)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	col.add_child(icon)

	var bar := UI.progress(620, 40)
	bar.value = StoreAndEconomy.piggy_progress() * 100.0
	col.add_child(bar)
	col.add_child(UI.label("%d / %d coins saved" % [StoreAndEconomy.piggy_fill(),
		StoreAndEconomy.PIGGY_TARGET], 36, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))

	var unlock := UI.button("Unlock  %s" % str(RemoteConfigAndAds.sku("piggy_bank").get("price", "₹99")), true)
	unlock.pressed.connect(func() -> void:
		StoreAndEconomy.purchase("piggy_bank")
		_close(ctx))
	col.add_child(unlock)

	_close_button(ctx, col)


# --------------------------------------------------------------------------- #
# settings
# --------------------------------------------------------------------------- #
static func show_settings(parent: Control) -> void:
	var ctx := _modal(parent, "SETTINGS")
	var col: VBoxContainer = ctx["column"]

	var music := CheckButton.new()
	music.text = "Music"
	music.button_pressed = AudioManager.music_on
	music.add_theme_font_size_override("font_size", 42)
	music.toggled.connect(func(on: bool) -> void: AudioManager.set_music(on))
	col.add_child(music)

	var sfx := CheckButton.new()
	sfx.text = "Sound effects"
	sfx.button_pressed = AudioManager.sfx_on
	sfx.add_theme_font_size_override("font_size", 42)
	sfx.toggled.connect(func(on: bool) -> void: AudioManager.set_sfx(on))
	col.add_child(sfx)

	var haptics := CheckButton.new()
	haptics.text = "Haptics"
	haptics.button_pressed = AudioManager.haptics_on
	haptics.add_theme_font_size_override("font_size", 42)
	haptics.toggled.connect(func(on: bool) -> void: AudioManager.set_haptics(on))
	col.add_child(haptics)

	var privacy := UI.button("Privacy policy", false)
	privacy.pressed.connect(func() -> void: OS.shell_open("https://example.com/privacy"))
	col.add_child(privacy)

	var restore := UI.button("Restore purchases", false)
	restore.pressed.connect(func() -> void:
		if Engine.has_singleton("ClassicBlastBilling"):
			Engine.get_singleton("ClassicBlastBilling").call("restore"))
	col.add_child(restore)

	_close_button(ctx, col)


# --------------------------------------------------------------------------- #
# out of lives
# --------------------------------------------------------------------------- #
static func show_out_of_lives(parent: Control, on_close: Callable = Callable()) -> void:
	var ctx := _modal(parent, "NO LIVES LEFT")
	var col: VBoxContainer = ctx["column"]
	col.add_child(UI.label("One life every 30 minutes, up to 5.", 38, UI.MUTED,
		HORIZONTAL_ALIGNMENT_CENTER))

	var wait := UI.label(GameManager.lives_label(), 56, UI.INK, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(wait)

	var ad := UI.button("Watch ad for +1 life", true)
	ad.visible = RemoteConfigAndAds.ads_enabled()
	ad.pressed.connect(func() -> void:
		RemoteConfigAndAds.show_rewarded("extra_life", func(ok: bool) -> void:
			if ok:
				GameManager.add_life(1)
			if on_close.is_valid():
				on_close.call()))
	col.add_child(ad)

	var buy := UI.button("Get lives with coins (150)", false)
	buy.pressed.connect(func() -> void:
		if GameManager.spend_coins(150):
			GameManager.add_life(1)
			_close(ctx)
			if on_close.is_valid():
				on_close.call())
	col.add_child(buy)

	var close := UI.button("Close", false)
	close.pressed.connect(func() -> void:
		_close(ctx)
		if on_close.is_valid():
			on_close.call())
	col.add_child(close)
