class_name Settlers
extends Node
## Villagers who have moved to the player's home. Each brings a trade:
## a blacksmith and an alchemist sell their wares, a trader buys and sells,
## a farmer waters your plots each morning and gathers what is ripe, and a
## guard shoots at monsters that come near.

const ROLES := {
	"blacksmith": {"title": "Blacksmith", "text": "Sells weapons and armour forged for your level.", "tint": Color(0.75, 0.75, 0.85), "stock": "smith"},
	"alchemist": {"title": "Alchemist", "text": "Sells potions, elixirs and the odd gem.", "tint": Color(0.75, 1.0, 0.75), "stock": "alchemy"},
	"trader": {"title": "Trader", "text": "Buys and sells like any village merchant, right at your door.", "tint": Color(1.0, 0.9, 0.65), "stock": "general"},
	"farmer": {"title": "Farmer", "text": "Waters your plots every morning and gathers ripe crops into a basket for you.", "tint": Color(0.9, 0.8, 0.55), "stock": ""},
	"guard": {"title": "Guard", "text": "Watches over your home and shoots at any monster that comes close.", "tint": Color(0.7, 0.8, 1.0), "stock": ""},
}
const NAMES: Array[String] = ["Edda", "Bram", "Wil", "Senna", "Oswin", "Mara", "Tobin", "Hild", "Corin", "Ysolde", "Garr", "Petra"]
const BASE_COST := 150
const GUARD_REACH := 280.0
const SPAWN_DISTANCE := 1500.0

## [{"id", "role", "name"}]
var settlers: Array = []
## The farmer's basket: saved item dicts.
var basket: Array = []

var _player: Player
var _buildings: Buildings
var _npcs: Dictionary = {}
var _check_left := 0.0


func _ready() -> void:
	SaveGame.register("settlers", self)


func setup(player: Player, buildings: Buildings) -> void:
	_player = player
	_buildings = buildings


## Where the settlers live: by the player's home bed, or their first house.
func home_point() -> Variant:
	if not _buildings.home.is_empty():
		return Vector2(_buildings.home["position"][0], _buildings.home["position"][1])
	for record in _buildings.records:
		if record["kind"] == "house" and record["where"] == "world":
			return Vector2(record["x"], record["y"]) + Vector2(0, 90)
	return null


func beds() -> int:
	return _buildings.records.filter(func(r: Dictionary) -> bool: return r["kind"] == "bed").size()


func cost() -> int:
	return BASE_COST * (settlers.size() + 1)


func has_settler(id: String) -> bool:
	return settlers.any(func(s: Dictionary) -> bool: return s["id"] == id)


## Why this person cannot come yet, or "".
func recruit_problem(id: String) -> String:
	if has_settler(id):
		return "Already living with you."
	if home_point() == null:
		return "You need a home first: build a house, or sleep in a bed."
	if beds() < settlers.size() + 2:
		return "You need a bed for yourself and one for each settler: %d needed, %d built." % [settlers.size() + 2, beds()]
	if _player.inventory.gold < cost():
		return "Moving costs %d gold." % cost()
	return ""


func recruit(offer: Dictionary) -> String:
	var problem := recruit_problem(offer["id"])
	if problem != "":
		return problem
	_player.inventory.gold -= cost()
	_player.inventory.changed.emit()
	settlers.append(offer.duplicate())
	Events.announcement.emit("%s IS MOVING IN" % (offer["name"] as String).to_upper(), "Your new %s will wait at your home" % ROLES[offer["role"]]["title"].to_lower())
	SaveGame.request_save()
	return ""


## The settler a village offers, if any (one per village, by its seed).
static func offer_for(village: Vector2i, world_seed: int) -> Dictionary:
	var random := RandomNumberGenerator.new()
	random.seed = hash(Vector3i(village.x, village.y, world_seed + 515))
	var roles: Array = ROLES.keys()
	return {"id": "%d,%d" % [village.x, village.y], "role": roles[random.randi_range(0, roles.size() - 1)], "name": NAMES[random.randi_range(0, NAMES.size() - 1)]}


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	_check_left -= delta
	if _check_left > 0.0:
		return
	_check_left = 1.0
	var home: Variant = home_point()
	var near := home != null and not _player.indoors and (home as Vector2).distance_to(_player.global_position) < SPAWN_DISTANCE
	for index in settlers.size():
		var info: Dictionary = settlers[index]
		var npc: Variant = _npcs.get(info["id"])
		if near and not is_instance_valid(npc):
			var spot: Vector2 = home + Vector2.from_angle(TAU * index / maxf(settlers.size(), 1.0) + 0.6) * 70.0
			npc = make_npc(info, spot)
			_player.get_parent().add_child(npc)
			_npcs[info["id"]] = npc
		elif not near and is_instance_valid(npc):
			npc.queue_free()
			_npcs.erase(info["id"])
	if near:
		_guard(home)


## Builds the person as an Npc.
func make_npc(info: Dictionary, at: Vector2) -> Npc:
	var npc := Npc.create("settler", at)
	npc.role = info["role"]
	npc.title_text = "%s the %s" % [info["name"], ROLES[info["role"]]["title"]]
	npc.prompt_text = "Talk to %s" % info["name"]
	npc.stock_kind = ROLES[info["role"]]["stock"]
	npc.tint = ROLES[info["role"]]["tint"]
	npc.home = at
	return npc


func _guard(_home: Vector2) -> void:
	for info: Dictionary in settlers:
		if info["role"] != "guard":
			continue
		var npc: Variant = _npcs.get(info["id"])
		if not is_instance_valid(npc):
			continue
		var target: Enemy = null
		var best := GUARD_REACH
		for node in get_tree().get_nodes_in_group("enemies"):
			var enemy := node as Enemy
			if enemy and not enemy.health.is_dead() and enemy.global_position.distance_to(npc.global_position) < best:
				best = enemy.global_position.distance_to(npc.global_position)
				target = enemy
		if target:
			Uniques._bolt(_player, npc.global_position + Vector2(0, -10), target.global_position, Color(0.8, 0.9, 1.0))
			target.take_damage(10.0 + _player.leveling.level * 3.0, (target.global_position - npc.global_position).normalized() * 160.0)


## Morning chores: the farmer waters every plot and gathers ripe crops.
func morning() -> void:
	if not settlers.any(func(s: Dictionary) -> bool: return s["role"] == "farmer"):
		return
	for record in _buildings.records:
		if record["kind"] != "plot" or record.get("crop", "") == "":
			continue
		if float(record.get("growth", 0.0)) >= 1.0:
			var data: Dictionary = Crops.CROPS[record["crop"]]
			basket.append(Item.create(data["item"], randi_range(data["yield"][0], data["yield"][1])).to_dict())
			basket.append(Item.create(data["seed"], 1).to_dict())
			record["crop"] = ""
			record["growth"] = 0.0
		else:
			record["watered"] = true
	SaveGame.request_save()


func talk(npc: Npc) -> void:
	match npc.role:
		"farmer":
			Events.loot_opened.emit({"items": basket, "title": "%s's basket" % npc.title_text.get_slice(" ", 0), "take_only": true})
		"guard":
			Events.announcement.emit("", "\"All quiet. I'll shout if anything comes.\"")


func save_data() -> Dictionary:
	return {"settlers": settlers.duplicate(true), "basket": basket.duplicate(true)}


func load_data(data: Dictionary) -> void:
	settlers.clear()
	for saved: Variant in data.get("settlers", []):
		if saved is Dictionary and ROLES.has(str(saved.get("role", ""))):
			settlers.append(saved)
	var saved_basket: Variant = data.get("basket", [])
	basket = saved_basket if saved_basket is Array else []
