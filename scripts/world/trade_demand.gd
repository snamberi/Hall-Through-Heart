class_name TradeDemand
extends RefCounted
## What each village needs. Every two in-game days a village wants three
## goods (its merchant pays up to twice the price) and has plenty of two
## (paid, and sold, for less). Selling into a want slowly fills it, so the
## price eases back the more of it is sold there. A good trade is carrying
## what one village has plenty of to another that wants it.

const PERIOD_DAYS := 2
const WANTS := 3
const PLENTY := 2
## How many sold before a want's extra price has halved.
const FILL := 30.0
const GOODS: Array[String] = ["copper_ore", "iron_ore", "silver_ore", "gold_ore", "coal", "stone", "copper_ingot", "iron_ingot",
	"silver_ingot", "oak_wood", "pine_wood", "healing_herb", "mana_flower", "frost_lily", "bloodcap", "glowshroom", "wheat",
	"carrot", "potato", "pumpkin", "minnow", "perch", "trout", "salmon", "leather", "wool", "deer_hide", "fox_pelt", "milk"]

## The in-game day, kept up to date by Festivals (which watches the clock).
static var day := 1
## Sold this period: "village:period:item" -> count.
static var _sold: Dictionary = {}


static func period() -> int:
	return day / PERIOD_DAYS


## {"wants": {item: factor}, "plenty": {item: factor}} for a village now.
static func of(center: Vector2i) -> Dictionary:
	var random := RandomNumberGenerator.new()
	random.seed = hash([center, period(), "trade"])
	var pool: Array = GOODS.filter(func(id: String) -> bool: return ItemDB.ITEMS.has(id))
	var wants := {}
	var plenty := {}
	for index in WANTS + PLENTY:
		var pick: String = pool[random.randi_range(0, pool.size() - 1)]
		pool.erase(pick)
		if index < WANTS:
			wants[pick] = snappedf(random.randf_range(1.4, 2.2), 0.05)
		else:
			plenty[pick] = snappedf(random.randf_range(0.55, 0.75), 0.05)
	return {"wants": wants, "plenty": plenty}


## The price factor for an item in a village now (1.0 when it is neither
## wanted nor plentiful), after what has been sold there this period.
static func factor(center: Vector2i, item_id: String) -> float:
	var demand := of(center)
	if demand["plenty"].has(item_id):
		return demand["plenty"][item_id]
	if demand["wants"].has(item_id):
		var extra: float = float(demand["wants"][item_id]) - 1.0
		var sold := float(_sold.get(_key(center, item_id), 0))
		return 1.0 + extra / (1.0 + sold / FILL)
	return 1.0


static func note_sold(center: Vector2i, item_id: String, count: int) -> void:
	var key := _key(center, item_id)
	_sold[key] = int(_sold.get(key, 0)) + count


static func _key(center: Vector2i, item_id: String) -> String:
	return "%d,%d:%d:%s" % [center.x, center.y, period(), item_id]


## "+80%" or "-40%".
static func percent(factor_value: float) -> String:
	var change := roundi((factor_value - 1.0) * 100.0)
	return ("+%d%%" if change >= 0 else "%d%%") % change
