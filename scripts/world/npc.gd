class_name Npc
extends Node2D
## Someone to talk to: a merchant who trades, or a warden who hands out work.

const REACH := 66.0
const KINDS := {
	"merchant": {"name": "Merchant", "prompt": "Trade with the Merchant", "sheet": "res://assets/sprites/npc_merchant.png"},
	"warden": {"name": "Warden", "prompt": "Ask the Warden for work", "sheet": "res://assets/sprites/npc_warden.png"},
	"villager": {"name": "Villager", "prompt": "Talk", "sheet": "res://assets/sprites/npc_merchant.png"},
	"settler": {"name": "Settler", "prompt": "Talk", "sheet": "res://assets/sprites/npc_merchant.png"},
	"recruit": {"name": "Wanderer", "prompt": "Talk", "sheet": "res://assets/sprites/npc_warden.png"},
}
## A merchant's wares change this often, in seconds.
const RESTOCK_SECONDS := 1200.0
## How many wares a merchant lays out at a time.
const SHELF := 5
## One-off wares already bought this period: shelf key -> {slot: true}.
static var _sold: Dictionary = {}
## Share of an item's value a merchant pays for it.
const SELL_SHARE := 0.25
var kind := "merchant"
## A wandering merchant sells rarer things.
var wandering := false
## Settlers and recruits: their trade, name, prompt, wares and colouring.
var role := ""
var title_text := ""
var prompt_text := ""
var stock_kind := "general"
var tint := Color.WHITE
## For recruits: the offer (see Settlers.offer_for).
var offer: Dictionary = {}
## What a merchant has for sale: [{"item": Item, "price": int, "endless": bool}].
var stock: Array[Dictionary] = []

var _stock_period := -1
## Villagers: what they might say, and where they wander from.
var lines: Array[String] = []
var home := Vector2.ZERO
var _sprite: AnimatedSprite2D
var _walk_to := Vector2.ZERO
var _think := 0.0


static func create(p_kind: String, at: Vector2) -> Npc:
	var npc := Npc.new()
	npc.kind = p_kind
	npc.position = at
	return npc


func _ready() -> void:
	add_to_group("npcs")
	var sprite := AnimatedSprite2D.new()
	_sprite = sprite
	sprite.sprite_frames = SheetAnimations.build(load(KINDS[kind]["sheet"]), 96, [{"name": "idle", "frames": 4, "fps": 5.0, "loop": true}])
	sprite.position = Vector2(0, -23)
	sprite.play("idle")
	add_child(sprite)
	SunShadow.follow(sprite)
	if kind == "villager":
		# Each villager dresses a little differently.
		sprite.modulate = Color.from_hsv(randf(), 0.25, 1.0).lerp(Color.WHITE, 0.4)
		_walk_to = position
	if tint != Color.WHITE:
		sprite.modulate = tint
	if kind == "settler":
		_walk_to = position

	var label := Label.new()
	label.text = title_text if title_text != "" else KINDS[kind]["name"]
	label.add_theme_font_override("font", UITheme.bold())
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", UITheme.GOLD)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.scale = Vector2.ONE / 2.0
	label.position = Vector2(-label.get_minimum_size().x / 4.0, -66.0)
	add_child(label)

	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 9.0
	shape.shape = circle
	body.add_child(shape)
	add_child(body)


func prompt() -> String:
	return prompt_text if prompt_text != "" else KINDS[kind]["prompt"]


## Fills the shelves if it is time: SHELF wares, picked afresh every
## RESTOCK_SECONDS. The pick depends only on who the merchant is and which
## twenty minutes it is, so walking away and back does not reroll it.
func restock_if_due(player: Player) -> void:
	var period := _period()
	if period == _stock_period and not (stock.is_empty() and _sold_here().is_empty()):
		return
	_stock_period = period
	stock.clear()
	var level := player.leveling.level
	var random := RandomNumberGenerator.new()
	random.seed = hash(_shelf_key())
	# Everything this kind of merchant might carry: [item id or "gear", weight].
	var pool: Array = []
	match stock_kind:
		"smith":
			pool = [["gear", 6.0], ["fine_gear", 2.0], ["copper_ingot", 1.0], ["iron_ingot", 1.0], ["silver_ingot", 0.7], ["bronze_pickaxe", 0.8], ["bronze_hatchet", 0.8]]
		"alchemy":
			pool = [["health_potion", 3.0], ["mana_potion", 2.5], ["stamina_tonic", 2.0], ["might_elixir", 1.5], ["bloodcap_draught", 1.2], ["aloe_salve", 1.5], ["gem", 1.5]]
		_:
			if wandering:
				pool = [["rare_gem", 2.0], ["treasure_map", 1.5], ["rowboat", 1.0], ["fine_gear", 3.0], ["set_piece", 1.2], ["horse_whistle", 0.8], ["taming_treat", 1.0]]
			else:
				pool = [["health_potion", 2.5], ["mana_potion", 1.5], ["stamina_tonic", 1.2], ["grilled_minnow", 1.2], ["copper_ingot", 1.0], ["oak_wood", 1.0],
					["wheat_seeds", 0.8], ["carrot_seeds", 0.8], ["potato_seeds", 0.8], ["farm_plot", 0.8], ["taming_treat", 0.8], ["torch", 1.5],
					["bronze_pickaxe", 0.8], ["bronze_hatchet", 0.8], ["pony_whistle", 0.6], ["gear", 3.0]]
	pool = pool.filter(func(entry: Array) -> bool: return entry[0] in SPECIAL or ItemDB.ITEMS.has(entry[0]))
	# The loot tables roll with the global dice; pin them for this shelf.
	seed(hash(_shelf_key()))
	var sold := _sold_here()
	for slot in SHELF:
		if pool.is_empty():
			break
		var total := 0.0
		for entry: Array in pool:
			total += entry[1]
		var roll := random.randf() * total
		var chosen: Array = pool[-1]
		for entry: Array in pool:
			roll -= entry[1]
			if roll <= 0.0:
				chosen = entry
				break
		var offer_entry := _make_offer(chosen[0], level, random)
		# Only arms and armour may come up twice on one shelf.
		if not chosen[0] in ["gear", "fine_gear"]:
			pool.erase(chosen)
		offer_entry["slot"] = slot
		if not sold.has(slot):
			stock.append(offer_entry)
	randomize()


const SPECIAL: Array[String] = ["gear", "fine_gear", "gem", "rare_gem", "set_piece"]


func _make_offer(what: String, level: int, random: RandomNumberGenerator) -> Dictionary:
	match what:
		"gear":
			var gear := LootGenerator.make_equipment(maxi(level + random.randi_range(-1, 2), 1), maxi(LootGenerator.roll_rarity(0.0, 2.0), 1))
			return {"item": gear, "price": gear.value(), "endless": false}
		"fine_gear":
			var fine := LootGenerator.make_equipment(maxi(level + random.randi_range(0, 2), 1), 3 if random.randf() < 0.75 else 4)
			return {"item": fine, "price": fine.value() * 2, "endless": false}
		"gem":
			var gem := Item.create(Gems.random_gem(level))
			return {"item": gem, "price": gem.value() * 2, "endless": false}
		"rare_gem":
			var rare := Item.create(Gems.random_gem(level + 15))
			return {"item": rare, "price": rare.value() * 2, "endless": false}
		"set_piece":
			var piece := LootGenerator.make_set_piece(level)
			return {"item": piece, "price": piece.value() * 3, "endless": false}
	var item := Item.create(what)
	var single: bool = item.definition().has("tool") or item.definition().has("mount") or what in ["treasure_map", "rowboat"]
	var price := item.value() * (2 if what.ends_with("_ingot") else 1)
	if what == "treasure_map":
		price = 150
	elif what == "rowboat":
		price = 300
	return {"item": item, "price": price, "endless": not single}


## Marks a one-off ware as gone until the shelves change.
func sold(entry: Dictionary) -> void:
	stock.erase(entry)
	if entry.has("slot"):
		if not _sold.has(_shelf_key()):
			# Old shelves no longer matter.
			_sold.clear()
			_sold[_shelf_key()] = {}
		_sold[_shelf_key()][entry["slot"]] = true


func _sold_here() -> Dictionary:
	return _sold.get(_shelf_key(), {})


func _period() -> int:
	return int(Time.get_unix_time_from_system() / RESTOCK_SECONDS)


func _shelf_key() -> String:
	var at := home if home != Vector2.ZERO else position
	return "%s:%s:%d:%d:%d" % [stock_kind, wandering, roundi(at.x / 44.0), roundi(at.y / 44.0), _period()]


## Seconds until the wares change.
func restock_in() -> float:
	return RESTOCK_SECONDS - fmod(Time.get_unix_time_from_system(), RESTOCK_SECONDS)


## Gold a merchant pays for one of an item.
static func sell_price(item: Item) -> int:
	return maxi(roundi(item.value() * SELL_SHARE), 1)


func _process(delta: float) -> void:
	if kind != "villager" and kind != "settler":
		return
	_think -= delta
	if _think <= 0.0:
		_think = randf_range(2.0, 6.0)
		_walk_to = home + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 160.0)
	var step := _walk_to - position
	if step.length() > 4.0:
		position += step.normalized() * 34.0 * delta
		_sprite.flip_h = step.x < 0.0


## A villager's passing remark.
func say_something() -> String:
	return lines.pick_random() if not lines.is_empty() else "..."
