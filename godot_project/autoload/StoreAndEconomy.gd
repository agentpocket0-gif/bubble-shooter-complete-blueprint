extends Node
## Coin store, boosters, daily spin and piggy bank.

signal purchase_finished(sku: String, ok: bool)
signal inventory_changed()

const BOOSTER_PRICES := {
	"swap": 60,
	"laser": 80,
	"extra_moves": 150,
	"continue": 250,
	"bomb": 300,
	"rainbow": 350,
}

const SPIN_PRIZES := [
	{"kind": "coins", "amount": 50, "weight": 34},
	{"kind": "coins", "amount": 100, "weight": 26},
	{"kind": "coins", "amount": 250, "weight": 16},
	{"kind": "booster", "booster": "swap", "amount": 1, "weight": 10},
	{"kind": "booster", "booster": "bomb", "amount": 1, "weight": 6},
	{"kind": "life", "amount": 1, "weight": 5},
	{"kind": "coins", "amount": 500, "weight": 3},
]

const PIGGY_TARGET := 5000
const SPIN_COOLDOWN := 24 * 60 * 60


func price_of(booster: String) -> int:
	return int(BOOSTER_PRICES.get(booster, 100))


func buy_booster(booster: String) -> bool:
	if booster == "continue":
		return false                     # offered only from the fail popup
	var price := price_of(booster)
	if not GameManager.spend_coins(price):
		return false
	GameManager.grant_booster(booster, 1)
	inventory_changed.emit()
	AudioManager.play("sfx_purchase_success")
	return true


func booster_label(booster: String) -> String:
	return {
		"swap": "Swap", "laser": "Aim Laser", "extra_moves": "+5 Moves",
		"continue": "Continue", "bomb": "Bomb", "rainbow": "Rainbow",
	}.get(booster, booster.capitalize())


# --------------------------------------------------------------------------- #
# daily spin
# --------------------------------------------------------------------------- #
func spin_ready() -> bool:
	var last := int(GameManager.data["stats"].get("lastSpinTs", 0))
	return int(Time.get_unix_time_from_system()) - last >= SPIN_COOLDOWN


func spin_wait_seconds() -> int:
	var last := int(GameManager.data["stats"].get("lastSpinTs", 0))
	return maxi(0, SPIN_COOLDOWN - (int(Time.get_unix_time_from_system()) - last))


func do_spin() -> Dictionary:
	if not spin_ready():
		return {}
	var total := 0
	for p in SPIN_PRIZES:
		total += int(p["weight"])
	var roll := randi() % total
	var picked: Dictionary = SPIN_PRIZES[0]
	for p in SPIN_PRIZES:
		roll -= int(p["weight"])
		if roll < 0:
			picked = p
			break
	GameManager.data["stats"]["lastSpinTs"] = int(Time.get_unix_time_from_system())
	GameManager.data["stats"]["spinStreak"] = int(GameManager.data["stats"].get("spinStreak", 0)) + 1
	_grant(picked)
	GameManager.save()
	return picked


func _grant(prize: Dictionary) -> void:
	match str(prize.get("kind", "")):
		"coins":
			GameManager.add_coins(int(prize.get("amount", 0)))
		"booster":
			GameManager.grant_booster(str(prize.get("booster", "swap")), int(prize.get("amount", 1)))
		"life":
			GameManager.add_life(int(prize.get("amount", 1)))
	inventory_changed.emit()


# --------------------------------------------------------------------------- #
# piggy bank
# --------------------------------------------------------------------------- #
func piggy_fill() -> int:
	return int(GameManager.data["stats"].get("piggyFill", 0))


func add_piggy_fill(n: int) -> void:
	GameManager.data["stats"]["piggyFill"] = mini(PIGGY_TARGET, piggy_fill() + n)
	GameManager.save()


func piggy_full() -> bool:
	return piggy_fill() >= PIGGY_TARGET


func piggy_progress() -> float:
	return clampf(float(piggy_fill()) / float(PIGGY_TARGET), 0.0, 1.0)


# --------------------------------------------------------------------------- #
# store
# --------------------------------------------------------------------------- #
func skus() -> Array:
	var order := ["coins_small", "coins_medium", "coins_large", "starter_pack",
		"remove_ads", "piggy_bank"]
	var out: Array = []
	for id in order:
		var s := RemoteConfigAndAds.sku(id)
		if not s.is_empty():
			var row := s.duplicate()
			row["id"] = id
			out.append(row)
	return out


func sku_title(id: String) -> String:
	return {
		"coins_small": "Pocket of Coins", "coins_medium": "Bag of Coins",
		"coins_large": "Chest of Coins", "starter_pack": "Starter Pack",
		"remove_ads": "Remove Ads", "piggy_bank": "Piggy Bank",
	}.get(id, id.capitalize())


## Purchase entry point. A paid item is granted only after the native
## billing bridge reports a verified store transaction. Editor/CI builds have
## no billing bridge, so they must fail closed instead of faking a purchase.
func purchase(id: String) -> void:
	if not RemoteConfigAndAds.iap_enabled():
		purchase_finished.emit(id, false)
		return

	var product := RemoteConfigAndAds.sku(id)
	var sku_id := str(product.get("sku", ""))
	if product.is_empty() or sku_id.is_empty():
		purchase_finished.emit(id, false)
		return

	if not Engine.has_singleton("ClassicBlastBilling"):
		purchase_finished.emit(id, false)
		return

	var bridge: Object = Engine.get_singleton("ClassicBlastBilling")
	if not bridge.has_method("purchase"):
		purchase_finished.emit(id, false)
		return

	# The native bridge must verify the purchase with the store/backend, then
	# call on_native_purchase(sku_id, true). This call alone grants nothing.
	bridge.call("purchase", sku_id)


func _grant_sku(id: String) -> void:
	var s := RemoteConfigAndAds.sku(id)
	if s.is_empty():
		return
	if int(s.get("coins", 0)) > 0:
		GameManager.add_coins(int(s["coins"]))
	if int(s.get("bombs", 0)) > 0:
		GameManager.grant_booster("bomb", int(s["bombs"]))
	if int(s.get("rainbows", 0)) > 0:
		GameManager.grant_booster("rainbow", int(s["rainbows"]))
	if id == "remove_ads":
		GameManager.set_flag("adsRemoved", true)
	GameManager.set_flag("firstPurchaseDone", true)
	GameManager.save()
	inventory_changed.emit()
	AudioManager.play("sfx_purchase_success")


## Called only after the native billing bridge has verified the receipt with
## the store/backend and de-duplicated the transaction.
func on_native_purchase(sku_id: String, ok: bool) -> void:
	if not ok:
		purchase_finished.emit(sku_id, false)
		return

	for row in skus():
		if str(row.get("sku", "")) == sku_id:
			_grant_sku(str(row["id"]))
			purchase_finished.emit(str(row["id"]), true)
			return

	push_warning("StoreAndEconomy: rejected an unknown purchase SKU: " + sku_id)
	purchase_finished.emit(sku_id, false)
