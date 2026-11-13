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
	"master": {"name": "Master", "prompt": "Speak with the master", "sheet": "res://assets/sprites/npc_warden.png"},
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
## Villagers: who they are (see VillagerLife.make), the door they sleep
## behind, and the village square.
var villager_name := ""
var job := ""
var villager_key := ""
var look: Dictionary = {}
var door := Vector2.ZERO
var square := Vector2.ZERO
## Whether the villager is out and about (false when gone indoors).
var about := true
var _sprite: AnimatedSprite2D
var _figure: PersonFigure
var _walk_to := Vector2.ZERO
var _think := 0.0
var _bubble: Label
var _bubble_left := 0.0
var _remark_in := 4.0
var _fleeing := 0.0
var _talking := 0.0


static func create(p_kind: String, at: Vector2) -> Npc:
	var npc := Npc.new()
	npc.kind = p_kind
	npc.position = at
	return npc


func _ready() -> void:
	add_to_group("npcs")
	var top := -66.0
	if not look.is_empty():
		# A person dressed like anyone else, with the tools of their trade.
		_figure = PersonFigure.new()
		_figure.dress(look, 0.72 if VillagerLife.JOBS.get(job, {}).get("small", false) else 1.0)
		var carry: String = VillagerLife.JOBS.get(job, {}).get("carry", "")
		if carry != "" and ItemDB.ITEMS.has(carry):
			var item := Item.create(carry)
			_figure.hold(item.icon(), item.icon_tint())
		add_child(_figure)
		top = -_figure.head_height() - 18.0
		_walk_to = position
		if title_text == "" and villager_name != "":
			title_text = "%s the %s" % [villager_name, VillagerLife.JOBS[job]["title"]]
		if prompt_text == "" and villager_name != "":
			prompt_text = "Talk to %s" % villager_name
	else:
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
	label.position = Vector2(-label.get_minimum_size().x / 4.0, top)
	add_child(label)
	if _figure:
		# Words said aloud float over the head for a moment.
		_bubble = Label.new()
		_bubble.add_theme_font_override("font", UITheme.get_theme().default_font)
		_bubble.add_theme_font_size_override("font_size", 14)
		_bubble.add_theme_color_override("font_color", Color(0.12, 0.1, 0.14))
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.96, 0.93, 0.85)
		box.border_color = Color(0.3, 0.24, 0.2)
		box.set_border_width_all(2)
		box.set_corner_radius_all(6)
		box.content_margin_left = 8
		box.content_margin_right = 8
		box.content_margin_top = 3
		box.content_margin_bottom = 3
		_bubble.add_theme_stylebox_override("normal", box)
		_bubble.scale = Vector2.ONE / 2.0
		_bubble.z_index = 20
		_bubble.visible = false
		_bubble.position.y = top - 20.0
		add_child(_bubble)

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
	if _figure:
		_live(delta)
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


## Says something aloud: a speech bubble over the head for a few seconds.
func say(text: String, seconds: float = 3.5) -> void:
	if _bubble == null:
		return
	_bubble.text = text
	_bubble.reset_size()
	_bubble.position.x = -_bubble.get_minimum_size().x / 4.0
	_bubble.visible = true
	_bubble_left = seconds


## Turns to face someone and stops for a while (while being spoken to).
func attend(to: Vector2) -> void:
	_talking = 6.0
	_walk_to = position
	if _figure:
		_figure.face(to.x - position.x)


## A villager's day: out working and wandering by day, home behind their
## door at night (the guard keeps watch instead), running for home when
## monsters come close, and a word for anyone passing.
func _live(delta: float) -> void:
	if _bubble_left > 0.0:
		_bubble_left -= delta
		if _bubble_left <= 0.0:
			_bubble.visible = false
	var data: Dictionary = VillagerLife.JOBS.get(job, {})
	var player: Player = get_tree().get_first_node_in_group("player")
	var night: DayNight = player.get_parent().get_node_or_null("DayNight") if player else null
	var dark := night != null and night.is_night() and not player.indoors
	_talking = maxf(_talking - delta, 0.0)
	_think -= delta
	if _think <= 0.0:
		_think = randf_range(2.5, 6.0)
		_choose_way(data, dark, player)
	if not about:
		# Indoors: come back out with the morning.
		if not dark:
			about = true
			visible = true
			add_to_group("npcs")
		return
	if _talking > 0.0:
		_figure.pose("idle")
		return
	var speed := 34.0
	if data.get("slow", false):
		speed = 22.0
	if data.get("small", false):
		speed = 52.0
	if _fleeing > 0.0:
		_fleeing -= delta
		speed = 95.0
	var step := _walk_to - position
	if step.length() > 4.0:
		position += step.normalized() * speed * delta
		_figure.face(step.x)
		_figure.pose("run" if speed > 60.0 else "walk", speed / 40.0 if speed <= 60.0 else 1.0)
	else:
		_figure.pose("idle")
		if dark and not data.get("night_watch", false) and door != Vector2.ZERO and position.distance_to(door) < 10.0:
			# In through the door for the night.
			about = false
			visible = false
			remove_from_group("npcs")
			return
	# A word for the player passing by.
	_remark_in -= delta
	if player and _remark_in <= 0.0 and position.distance_to(player.global_position) < 120.0 and _bubble_left <= 0.0:
		_remark_in = randf_range(9.0, 18.0)
		var errands: Errands = player.get_parent().get_node_or_null("Errands")
		var friend := errands != null and int(errands.helped.get(villager_key, 0)) > 0
		say(VillagerLife.passing_remark(job, villager_name, friend))


func _choose_way(data: Dictionary, dark: bool, player: Player) -> void:
	# Monsters close by: run for the door.
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy and not enemy.is_wild() and enemy.state != Enemy.State.DEAD and enemy.global_position.distance_to(position) < 170.0:
			if data.get("night_watch", false):
				_walk_to = position
				say("To arms!", 2.0)
				return
			_fleeing = 4.0
			_walk_to = door if door != Vector2.ZERO else home
			if _bubble_left <= 0.0:
				say(["Monster!", "Help!", "Run!"].pick_random(), 2.0)
			return
	if dark and not data.get("night_watch", false) and door != Vector2.ZERO:
		_walk_to = door
		return
	if dark:
		# On watch: walk the lanterns round the square.
		_walk_to = square + Vector2.from_angle(randf() * TAU) * randf_range(60.0, 200.0)
		return
	if job == "elder":
		_walk_to = square + Vector2(randf_range(-50.0, 90.0), randf_range(40.0, 110.0))
	elif job == "child" and player and randf() < 0.3 and player.global_position.distance_to(position) < 200.0:
		# Children tag along after an adventurer.
		_walk_to = player.global_position + Vector2.from_angle(randf() * TAU) * 40.0
	else:
		_walk_to = home + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 150.0)
