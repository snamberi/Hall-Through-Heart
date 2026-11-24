extends Node
## Professions: the trade a character lives by. Twelve to choose from; a
## character follows three, chosen when they are made: one main profession
## (up to level 15) and two side ones (up to level 10). Each levels up by
## doing its work (mining for a Miner, felling trees for a Woodcutter,
## keeping monsters down for a Guard...) and gives bonuses to that work and
## to the one who does it, growing with every level.
##
## These sit on top of the skills (Professions, levels 1-100), which every
## character has: a profession makes its skills faster to learn and
## better at what they do. (Loaded by path; the player holds it as `trades`.)

signal changed

const MAIN_MAX := 15
const SIDE_MAX := 10
const SIDES := 2

## id -> name, what it is, the item whose picture it shows, what earns it experience
## ("skills": the skills it practises; "earns": other deeds), and what each
## level gives: "mods" (stat modifiers per level), and work bonuses per
## level: "speed" and "double" (gathering its skills faster, and doubled),
## "potency" (food), "potion" (potion length), "sell"/"buy" (prices),
## "harvest" (extra crops), "loot" (extra drops from beasts).
const LIST := {
	"miner": {"name": "Miner", "icon": "worn_pickaxe", "text": "Breaks rock and ore faster, and digs up more of it.", "skills": ["mining"],
		"speed": 0.03, "double": 0.015, "mods": {"max_stamina": {"flat": 2.0}}},
	"woodcutter": {"name": "Woodcutter", "icon": "worn_hatchet", "text": "Fells trees faster for more timber; a strong swing.", "skills": ["woodcutting"],
		"speed": 0.03, "double": 0.015, "mods": {"physical_damage": {"percent": 0.005}}},
	"herbalist": {"name": "Herbalist", "icon": "healing_herb", "text": "Finds more herbs and heals faster.", "skills": ["herbalism"],
		"speed": 0.03, "double": 0.02, "mods": {"health_regen": {"flat": 0.12}}},
	"fisher": {"name": "Fisher", "icon": "fishing_rod", "text": "Patient: fish bite sooner, and luck follows.", "skills": ["fishing"],
		"speed": 0.03, "double": 0.015, "mods": {"magic_find": {"flat": 0.01}}},
	"cook": {"name": "Cook", "icon": "bread", "text": "Meals made and eaten do more and last longer.", "skills": ["cooking"],
		"potency": 0.03, "mods": {"max_health": {"percent": 0.004}}},
	"smith": {"name": "Smith", "icon": "iron_ingot", "text": "Learns the forge fast; tougher in armour.", "skills": ["blacksmithing"],
		"mods": {"armor": {"percent": 0.01}, "physical_damage": {"percent": 0.004}}},
	"craftsman": {"name": "Craftsman", "icon": "crafting_table", "text": "Builds and breaks down with skill; steady hands.", "skills": ["building", "salvaging"],
		"double": 0.015, "mods": {"max_stamina": {"flat": 1.5}, "dodge_efficiency": {"flat": 0.003}}},
	"alchemist": {"name": "Alchemist", "icon": "health_potion", "text": "Potions last longer; magic flows easier.", "skills": ["alchemy", "enchanting"],
		"potion": 0.04, "mods": {"max_mana": {"percent": 0.01}, "magic_power": {"percent": 0.004}}},
	"guard": {"name": "Guard", "icon": "shield", "text": "Keeps monsters down: harder to hurt, harder to kill.", "earns": "monsters",
		"mods": {"armor": {"percent": 0.015}, "max_health": {"percent": 0.008}, "damage_taken": {"percent": -0.004}}},
	"hunter": {"name": "Hunter", "icon": "bow", "text": "Tracks and takes beasts: quicker, keener, and more from each kill.", "earns": "beasts",
		"loot": 0.03, "mods": {"critical_chance": {"flat": 0.003}, "move_speed": {"percent": 0.004}}},
	"merchant": {"name": "Merchant", "icon": "gold_coins", "text": "Sells dearer, buys cheaper, and finds coin everywhere.", "earns": "trade",
		"sell": 0.02, "buy": 0.01, "mods": {"gold_find": {"flat": 0.02}}},
	"farmer": {"name": "Farmer", "icon": "wheat", "text": "Bigger harvests from every field; hardy as the soil.", "earns": "harvest",
		"harvest": 0.04, "mods": {"health_regen": {"flat": 0.1}, "max_health": {"flat": 2.0}}},
}

## The chosen professions: one main, two side.
var main := ""
var sides: Array[String] = []
var levels: Dictionary = {}
var xp: Dictionary = {}
var _player: Player


func setup(player: Player) -> void:
	_player = player
	Events.enemy_killed.connect(_on_kill)
	Events.codex_event.connect(func(stat: String, amount: int) -> void:
		if stat == "harvests":
			practice("farmer", 20.0 * amount)
	)
	if player.professions:
		player.professions.practised.connect(func(skill: String, amount: float) -> void:
			for id: String in chosen():
				if skill in LIST[id].get("skills", []):
					practice(id, amount)
		)
	if not has_chosen():
		var picked: Variant = SaveGame.get_section("meta").get("trades")
		if picked is Dictionary:
			choose(str(picked.get("main", "")), Array(picked.get("sides", []), TYPE_STRING, "", null))
	_apply()


func has_chosen() -> bool:
	return main != ""


func chosen() -> Array[String]:
	var all: Array[String] = []
	if main != "":
		all.append(main)
	all.append_array(sides)
	return all


## Picks the three professions (once; a new character's choice).
func choose(p_main: String, p_sides: Array[String]) -> bool:
	if not LIST.has(p_main) or p_sides.size() != SIDES or p_main in p_sides or p_sides[0] == p_sides[1]:
		return false
	for id in p_sides:
		if not LIST.has(id):
			return false
	main = p_main
	sides = p_sides.duplicate()
	for id: String in chosen():
		levels[id] = maxi(int(levels.get(id, 1)), 1)
		xp[id] = float(xp.get(id, 0.0))
	_apply()
	changed.emit()
	SaveGame.request_save()
	return true


func max_level(id: String) -> int:
	return MAIN_MAX if id == main else SIDE_MAX if id in sides else 0


## A profession's level (0 if not followed).
func level(id: String) -> int:
	return int(levels.get(id, 0)) if id in chosen() else 0


static func xp_required(from_level: int) -> float:
	return roundf(30.0 * pow(from_level, 1.5))


## Experience for doing a profession's work.
func practice(id: String, amount: float) -> void:
	if not id in chosen() or amount <= 0.0 or level(id) >= max_level(id):
		return
	xp[id] = float(xp.get(id, 0.0)) + amount
	var gained := false
	while level(id) < max_level(id) and float(xp[id]) >= xp_required(level(id)):
		xp[id] = float(xp[id]) - xp_required(level(id))
		levels[id] = level(id) + 1
		gained = true
	if level(id) >= max_level(id):
		xp[id] = 0.0
	if gained:
		_apply()
		Events.announcement.emit("%s %d" % [str(LIST[id]["name"]).to_upper(), level(id)], "Your profession grows" if level(id) < max_level(id) else "Mastered")
		Audio.play("level_up", -6.0)
	changed.emit()


## How much the chosen professions add to one kind of bonus ("potency",
## "sell", "loot"...): each one's per-level value times its level.
func bonus(key: String) -> float:
	var total := 0.0
	for id: String in chosen():
		total += float(LIST[id].get(key, 0.0)) * level(id)
	return total


## Gathering or crafting a skill: how much faster, and the extra chance of
## a double, from the professions that practise it.
func skill_bonus(skill: String, key: String) -> float:
	var total := 0.0
	for id: String in chosen():
		if skill in LIST[id].get("skills", []):
			total += float(LIST[id].get(key, 0.0)) * level(id)
	return total


## Skills a profession practises are learned faster: 4% a level.
func skill_learning(skill: String) -> float:
	var total := 0.0
	for id: String in chosen():
		if skill in LIST[id].get("skills", []):
			total += 0.04 * level(id)
	return total


## Every level's stat modifiers, added together, into the character's stats.
func _apply() -> void:
	if _player == null or _player.stats == null:
		return
	var mods := {}
	for id: String in chosen():
		var per: Dictionary = LIST[id].get("mods", {})
		for stat: String in per:
			if not mods.has(stat):
				mods[stat] = {}
			for kind: String in per[stat]:
				mods[stat][kind] = float(mods[stat].get(kind, 0.0)) + float(per[stat][kind]) * level(id)
	_player.stats.set_modifiers("professions", mods)


func _on_kill(info: Dictionary) -> void:
	var data: Dictionary = EnemyDB.ENEMIES.get(str(info.get("id", "")), {})
	var amount := float(info.get("xp", 5)) * 1.5
	if data.has("wild"):
		practice("hunter", amount)
	else:
		practice("guard", amount)


func save_data() -> Dictionary:
	return {"main": main, "sides": sides.duplicate(), "levels": levels.duplicate(), "xp": xp.duplicate()}


func load_data(data: Dictionary) -> void:
	main = str(data.get("main", ""))
	sides.clear()
	for id: Variant in data.get("sides", []):
		sides.append(str(id))
	levels = (data.get("levels", {}) as Dictionary).duplicate()
	xp = (data.get("xp", {}) as Dictionary).duplicate()
	_apply()
	changed.emit()


## A profession's picture (an item of its work).
static func icon(id: String) -> Texture2D:
	return Item.create(str(LIST[id]["icon"])).icon()
