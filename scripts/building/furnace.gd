class_name Furnace
extends Node2D
## A furnace at work: one ore at a time becomes one ingot of the same
## rarity, taking longer for the finer metals. Each lump of coal smelts
## BURNS_PER_COAL ores. Ingots wait inside until taken. While the player is
## away it keeps going at half pace.
##
## The record keeps: "ore" {"id", "rarity", "count"}, "coal" (lumps
## waiting), "burns" (ores left on the burning lump), "progress", "items"
## (the ingots made), "last" (when it was last looked at).

const BURNS_PER_COAL := 8
const AWAY_PACE := 0.5
## ore id -> ingot id.
const SMELTS := {"copper_ore": "copper_ingot", "iron_ore": "iron_ingot", "silver_ore": "silver_ingot", "gold_ore": "gold_ingot",
	"mithril_ore": "mithril_ingot", "obsidian_ore": "obsidian_ingot", "adamantite_ore": "adamantite_ingot", "void_crystal": "void_ingot",
	"heartstone": "heartstone_ingot"}

var record: Dictionary
var _flicker := 0.0
var _spark := 0.0


static func smelt_seconds(ore_id: String) -> float:
	return 5.0 + 1.5 * float(SMELTS.keys().find(ore_id))


static func ore_in(record: Dictionary) -> Dictionary:
	if not record.has("ore"):
		record["ore"] = {"id": "", "rarity": 0, "count": 0}
	return record["ore"]


## Whether it is burning: ore inside and fuel to burn.
static func working(record: Dictionary) -> bool:
	return int(ore_in(record)["count"]) > 0 and (int(record.get("burns", 0)) > 0 or int(record.get("coal", 0)) > 0)


func _ready() -> void:
	# It keeps burning while its screen is open (menus pause the game).
	process_mode = Node.PROCESS_MODE_ALWAYS
	var now := Time.get_unix_time_from_system()
	var last := float(record.get("last", now))
	record["last"] = now
	var away := maxf(now - last, 0.0) * AWAY_PACE
	var ore := ore_in(record)
	while away > 0.0 and working(record):
		var need: float = smelt_seconds(ore["id"]) - float(record.get("progress", 0.0))
		if away < need:
			record["progress"] = float(record.get("progress", 0.0)) + away
			break
		away -= need
		_finish_one()


func _process(delta: float) -> void:
	record["last"] = Time.get_unix_time_from_system()
	var prop := get_parent() as Prop
	if not working(record):
		if prop and prop.sprite():
			prop.sprite().modulate = Color.WHITE
		return
	var ore := ore_in(record)
	record["progress"] = float(record.get("progress", 0.0)) + delta
	if float(record["progress"]) >= smelt_seconds(ore["id"]):
		_finish_one()
	# The mouth glows and throws the odd spark while it burns.
	_flicker += delta
	if prop and prop.sprite():
		prop.sprite().modulate = Color(1.0 + 0.12 * sin(_flicker * 9.0), 0.95, 0.9)
	_spark -= delta
	if _spark <= 0.0:
		_spark = randf_range(0.4, 1.0)
		HitSpark.spawn(get_parent().get_parent(), global_position + Vector2(randf_range(-6, 6), -14), Color(1.0, 0.7, 0.3))


func _finish_one() -> void:
	var ore := ore_in(record)
	var ore_id: String = ore["id"]
	record["progress"] = 0.0
	ore["count"] = int(ore["count"]) - 1
	# A fresh lump goes on when the last one is spent.
	if int(record.get("burns", 0)) <= 0:
		record["coal"] = int(record.get("coal", 0)) - 1
		record["burns"] = BURNS_PER_COAL
	record["burns"] = int(record["burns"]) - 1
	var ingot: String = SMELTS.get(ore["id"], "")
	if ingot != "":
		var items: Array = record["items"]
		var stacked := false
		for saved: Dictionary in items:
			if saved["id"] == ingot and int(saved.get("rarity", ItemDB.ITEMS[ingot].get("material_rarity", 0))) == int(ore["rarity"]):
				saved["count"] = int(saved["count"]) + 1
				stacked = true
				break
		if not stacked:
			var made := Item.create(ingot)
			made.rarity = int(ore["rarity"])
			items.append(made.to_dict())
	if int(ore["count"]) <= 0:
		ore["id"] = ""
		ore["count"] = 0
	var player := get_tree().get_first_node_in_group("player") as Player if is_inside_tree() else null
	if player:
		player.professions.add_xp("blacksmithing", 6.0 + 1.5 * SMELTS.keys().find(ore_id))
		Events.item_crafted.emit("smelt_" + ingot)
	SaveGame.request_save()

