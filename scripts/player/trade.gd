class_name Trade
extends Node
## Your standing with the merchants of the land. Every gold piece you spend
## with a merchant counts toward it, and half of every piece you take from
## one; gold can also be put into a shop outright. Standing climbs through
## tiers (Stranger, Customer, Regular, Patron, Partner) and each tier lays
## more on the shelves, rolls rarer gear, takes a little off the price and
## pays more for what you sell.
##
## Merchants also pay extra for what they deal in: a smith for arms, armour,
## ore and ingots, an alchemist for potions, herbs and gems, a general store
## for food, wood, hides and seeds, and a wandering merchant for anything
## epic or better.

signal changed

## Each tier: name, standing needed, share of value paid when selling,
## shelf size, extra rarity rolled on gear, and the discount on wares.
const TIERS: Array[Dictionary] = [
	{"name": "Stranger", "at": 0, "share": 0.30, "shelf": 5, "rarity": 0.0, "discount": 0.0},
	{"name": "Customer", "at": 1500, "share": 0.33, "shelf": 6, "rarity": 0.3, "discount": 0.03},
	{"name": "Regular", "at": 8000, "share": 0.36, "shelf": 6, "rarity": 0.6, "discount": 0.06},
	{"name": "Patron", "at": 30000, "share": 0.40, "shelf": 7, "rarity": 1.0, "discount": 0.09},
	{"name": "Partner", "at": 100000, "share": 0.45, "shelf": 8, "rarity": 1.5, "discount": 0.12},
]
## What each kind of merchant pays extra for, by ItemText.type_name.
const SPECIALTIES := {
	"smith": ["Ore", "Ingot", "Pickaxe", "Hatchet", "Shield"],
	"alchemy": ["Potion", "Herb", "Gem", "Arcane material", "Monster part"],
	"general": ["Food", "Drink", "Treat", "Raw food", "Wood", "Hide", "Seed", "Crop"],
}
const SPECIALTY_BONUS := 0.25
## The most gold put into a shop at once, as a multiple of the player level.
const INVEST_STEP := 250

## Gold spent with merchants, gold taken from them, and gold put into shops.
var spent := 0
var earned := 0
var invested := 0
var _player: Player


func _ready() -> void:
	_player = get_parent()
	SaveGame.register("trade", self)


## Standing points: spent and invested count in full, earned counts half.
func standing() -> int:
	return spent + invested + earned / 2


func tier() -> int:
	var points := standing()
	var best := 0
	for index in TIERS.size():
		if points >= int(TIERS[index]["at"]):
			best = index
	return best


func tier_info() -> Dictionary:
	return TIERS[tier()]


## Standing still needed for the next tier, or 0 at the top.
func to_next() -> int:
	var next := tier() + 1
	return 0 if next >= TIERS.size() else int(TIERS[next]["at"]) - standing()


## How far through the current tier, 0..1 (1 at the top).
func progress() -> float:
	var current := tier()
	if current + 1 >= TIERS.size():
		return 1.0
	var low := int(TIERS[current]["at"])
	var high := int(TIERS[current + 1]["at"])
	return clampf(float(standing() - low) / float(high - low), 0.0, 1.0)


## Whether a merchant of this kind pays extra for an item.
static func is_specialty(item: Item, stock_kind: String, wandering: bool) -> bool:
	if wandering:
		return item.rarity >= 3
	var kind := ItemText.type_name(item)
	if stock_kind == "smith" and (item.definition().has("weapon") or (item.is_equipment() and item.slot() in ["helmet", "chest", "legs", "boots"])):
		return true
	return kind in SPECIALTIES.get(stock_kind, [])


## Gold a merchant of this kind pays for one of an item at this standing.
func sell_price(item: Item, stock_kind := "general", wandering := false) -> int:
	var share := float(tier_info()["share"])
	if is_specialty(item, stock_kind, wandering):
		share *= 1.0 + SPECIALTY_BONUS
	share *= 1.0 + _merchant("sell")
	return maxi(roundi(item.value() * share), 1)


## A ware's price after the standing discount.
func buy_price(base: int) -> int:
	return maxi(roundi(base * (1.0 - float(tier_info()["discount"]) - _merchant("buy"))), 1)


## A Merchant's better prices (see Trades).
func _merchant(key: String) -> float:
	var holder := get_parent() as Player
	return holder.trades.bonus(key) if holder and holder.trades else 0.0


## Notes gold spent with (or taken from) a merchant, and says so when the
## standing climbs to a new tier.
func note_spent(gold: int) -> void:
	var holder := get_parent() as Player
	if holder and holder.trades:
		holder.trades.practice("merchant", absf(gold) / 3.0)
	_add(func() -> void: spent += maxi(gold, 0))


## Negative when something sold is bought back, so selling and buying back
## gains nothing.
func note_earned(gold: int) -> void:
	_add(func() -> void: earned = maxi(earned + gold, 0))


## What putting gold into a shop costs at once, by player level.
func invest_step() -> int:
	return INVEST_STEP * maxi(1, ceili(_player.leveling.level / 10.0))


## Puts gold into the shop for standing: gone for good, counted in full.
func invest() -> bool:
	var amount := invest_step()
	if _player.inventory.gold < amount or tier() + 1 >= TIERS.size():
		return false
	_player.inventory.add_gold(-amount)
	_add(func() -> void: invested += amount)
	return true


func _add(change: Callable) -> void:
	var before := tier()
	change.call()
	if tier() > before:
		var info := tier_info()
		Events.announcement.emit("Merchants know you: %s" % info["name"], "%d wares on a shelf, %d%% off, and better prices for what you sell." % [
			int(info["shelf"]), roundi(float(info["discount"]) * 100.0)])
		DamageNumber.spawn_text(_player.get_parent(), _player.global_position + Vector2(0, -52), info["name"], UITheme.GOLD, 15)
	changed.emit()
	SaveGame.request_save()


func save_data() -> Dictionary:
	return {"spent": spent, "earned": earned, "invested": invested}


func load_data(data: Dictionary) -> void:
	spent = int(data.get("spent", 0))
	earned = int(data.get("earned", 0))
	invested = int(data.get("invested", 0))
	changed.emit()
