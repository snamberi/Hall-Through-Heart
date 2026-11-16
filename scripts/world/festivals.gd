class_name Festivals
extends Node
## Seasonal festivals. The year runs YEAR_DAYS in-game days; twice a year a
## festival fills every village for three days: the Harvest Fair (bring
## crops) and the Frost Market (bring fish and pelts). The villages hang
## out their colours and a Festival Keeper takes the contest goods for
## Festival Tokens and sells the festival's own goods for them. On a blood
## moon night a hooded trader opens the Blood Moon Bazaar at the Sanctuary,
## trading for Blood Tokens that monsters drop while the moon is red.

signal changed

const YEAR_DAYS := 24
const FESTIVALS := {
	"harvest": {"name": "Harvest Fair", "start": 6, "days": 3, "color": Color(1.0, 0.72, 0.3), "token": "festival_token",
		"text": "The fields are in. Bring your crops to the Festival Keeper: the best harvest wins tokens.",
		"contest": {"wheat": 12, "carrot": 10, "potato": 10, "pumpkin": 4, "wild_berries": 15},
		"shop": [["harvest_pie", 1], ["sunroot_seeds", 2], ["scarecrow", 2], ["lucky_charm", 4], ["racing_saddle", 6]]},
	"frost": {"name": "Frost Market", "start": 18, "days": 3, "color": Color(0.65, 0.85, 1.0), "token": "festival_token",
		"text": "Braziers in the snow and warm cups for everyone. Bring fish and pelts to the Festival Keeper for tokens.",
		"contest": {"trout": 6, "salmon": 4, "pike": 5, "fox_pelt": 3, "frost_pelt": 3, "leather": 8},
		"shop": [["mulled_cider", 1], ["frost_tea", 1], ["lantern_post", 2], ["swift_charm", 5], ["fur_cloak", 6]]},
	"bazaar": {"name": "Blood Moon Bazaar", "color": Color(0.9, 0.3, 0.35), "token": "blood_token",
		"text": "Under the red moon a hooded trader sets out strange wares at the Sanctuary. Monsters drop Blood Tokens while the moon is red.",
		"contest": {},
		"shop": [["bloodcap_draught", 1], ["rune_blood", 2], ["rune_gloom", 2], ["treasure_map", 3], ["rift_shard", 3], ["heart_charm", 6], ["heartwood_saddle", 10]]},
}
## Chance a monster killed under a blood moon drops a Blood Token.
const BLOOD_TOKEN_CHANCE := 0.12
const BLOOD_TOKEN_ELITE := 0.5

var _player: Player
var _day_night: DayNight
var _last := ""
var _bazaar: Array = []


func setup(player: Player, day_night: DayNight) -> void:
	_player = player
	_day_night = day_night
	Events.enemy_killed.connect(_on_kill)
	_last = festival_on(day_night.day)


## The festival running on an in-game day, or "".
static func festival_on(day: int) -> String:
	var in_year := posmod(day, YEAR_DAYS)
	for id: String in ["harvest", "frost"]:
		var start: int = FESTIVALS[id]["start"]
		if in_year >= start and in_year < start + int(FESTIVALS[id]["days"]):
			return id
	return ""


func current() -> String:
	return festival_on(_day_night.day) if _day_night else ""


## The next festival and how many days until it starts.
func next_festival() -> Array:
	for ahead in range(1, YEAR_DAYS + 1):
		var id := festival_on(_day_night.day + ahead)
		if id != "" and id != current():
			return [id, ahead]
	return ["", 0]


func days_left() -> int:
	var id := current()
	if id == "":
		return 0
	var in_year := posmod(_day_night.day, YEAR_DAYS)
	return int(FESTIVALS[id]["start"]) + int(FESTIVALS[id]["days"]) - in_year


func _process(_delta: float) -> void:
	if _day_night == null:
		return
	TradeDemand.day = _day_night.day
	var now := current()
	if now != _last:
		_last = now
		if now != "":
			Events.announcement.emit(String(FESTIVALS[now]["name"]).to_upper(), "Every village is celebrating for %d days" % FESTIVALS[now]["days"])
		changed.emit()
	var bazaar_open := DayNight.blood_moon
	if bazaar_open and _bazaar.is_empty():
		_open_bazaar()
	elif not bazaar_open and not _bazaar.is_empty():
		for node: Variant in _bazaar:
			if is_instance_valid(node):
				node.queue_free()
		_bazaar.clear()


## The hooded trader's tent at the Sanctuary, while the moon is red.
func _open_bazaar() -> void:
	var world: World = _player.get_parent().get_node("World")
	var at := world.cell_to_world(Vector2i(-6, 6))
	var tent := Prop.create_decor(Prop.Decor.TENT, at + Vector2(-40, -10), 20.0)
	tent.sprite().modulate = Color(0.75, 0.3, 0.35)
	tent.add_light(0.8, 1.4, Color(1.0, 0.35, 0.35))
	var trader := Npc.create("festival", at + Vector2(10, 20))
	trader.offer = {"festival": "bazaar"}
	trader.title_text = "The Hooded Trader"
	trader.prompt_text = "Browse the Blood Moon Bazaar"
	trader.tint = Color(0.8, 0.45, 0.5)
	var structures := _player.get_parent().get_node("Structures")
	structures.add_child(tent)
	structures.add_child(trader)
	_bazaar = [tent, trader]
	Events.announcement.emit("BLOOD MOON BAZAAR", "A hooded trader waits at the Sanctuary")


func _on_kill(info: Dictionary) -> void:
	if not DayNight.blood_moon or _player == null:
		return
	var elite: bool = str(info.get("rank", "normal")) != "normal"
	if randf() < (BLOOD_TOKEN_ELITE if elite else BLOOD_TOKEN_CHANCE):
		if _player.inventory.add(Item.create("blood_token")):
			Events.pickup_noted.emit("Blood Token", 1, Color(1.0, 0.45, 0.45))


## What the contest pays: one token for each full lot handed in. Returns
## the tokens earned.
func hand_in(festival: String, item_id: String) -> int:
	var lot: int = int(FESTIVALS[festival]["contest"].get(item_id, 0))
	if lot <= 0:
		return 0
	var lots := _player.inventory.count_of(item_id) / lot
	if lots <= 0:
		return 0
	_player.inventory.take(item_id, lots * lot)
	_player.inventory.add(Item.create(FESTIVALS[festival]["token"], lots))
	Events.codex_event.emit("festival_tokens", lots)
	return lots


## Buys a festival ware for tokens. Returns "" or why not.
func buy(festival: String, index: int) -> String:
	var ware: Array = FESTIVALS[festival]["shop"][index]
	var token: String = FESTIVALS[festival]["token"]
	if _player.inventory.count_of(token) < int(ware[1]):
		return "Not enough %ss." % ItemDB.ITEMS[token]["name"]
	var item := Item.create(ware[0])
	if not _player.inventory.has_room_for(item):
		return "Your bag is full."
	_player.inventory.take(token, int(ware[1]))
	_player.inventory.add(item)
	return ""
