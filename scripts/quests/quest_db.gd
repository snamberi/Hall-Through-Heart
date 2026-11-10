class_name QuestDB
extends RefCounted
## Quests: the hand-written story chain, and the generator for the work a
## warden offers.
##
## A quest is a Dictionary:
##   "id", "title", "text"
##   "objective": {"type", "target", "count"} where type is one of
##       kill     defeat enemies ("target" is an enemy id, or "" for any)
##       elite    defeat Elites or Champions
##       collect  gather a material from the world ("target" is the item id)
##       craft    craft things ("target" is a profession id, or "" for any)
##       explore  discover different kinds of terrain
##       class    choose a class
##   "rewards": {"xp", "gold", "items": [[item id, count]], "gear_rarity", "profession": [id, xp]}
##   "next": the story quest that follows (story quests only)

const STORY_START := "awakening"
const STORY := {
	"awakening": {
		"title": "Awakening", "text": "You woke in the Sanctuary with a sword and no memory. The husks beyond the stones will not leave you be.",
		"objective": {"type": "kill", "target": "husk", "count": 3},
		"rewards": {"xp": 30, "gold": 20, "items": [["health_potion", 2]]}, "next": "tools_of_the_trade",
	},
	"tools_of_the_trade": {
		"title": "Tools of the Trade", "text": "There is copper in the grey rocks. Stand beside a vein and press F to mine it.",
		"objective": {"type": "collect", "target": "copper_ore", "count": 3},
		"rewards": {"xp": 40, "gold": 15, "profession": ["mining", 30.0]}, "next": "first_forge",
	},
	"first_forge": {
		"title": "First Forge", "text": "Ore is no use raw. Open Professions (P) and smelt an ingot, or forge whatever you can.",
		"objective": {"type": "craft", "target": "blacksmithing", "count": 1},
		"rewards": {"xp": 50, "gold": 30, "items": [["copper_ingot", 3]]}, "next": "into_the_wild",
	},
	"into_the_wild": {
		"title": "Into the Wild", "text": "The land changes as you walk. See three different kinds of country.",
		"objective": {"type": "explore", "target": "", "count": 3},
		"rewards": {"xp": 90, "gold": 40}, "next": "the_hunt",
	},
	"the_hunt": {
		"title": "The Hunt", "text": "Some of the dead are stronger than the rest, and carry more. Bring one down.",
		"objective": {"type": "elite", "target": "", "count": 1},
		"rewards": {"xp": 160, "gold": 80, "gear_rarity": 2}, "next": "a_path_chosen",
	},
	"a_path_chosen": {
		"title": "A Path Chosen", "text": "At level 10 you can choose what you will become. Open the Class screen from the menu wheel.",
		"objective": {"type": "class", "target": "", "count": 1},
		"rewards": {"xp": 300, "gold": 200}, "next": "",
	},
}
## How many quests can be active at once.
const MAX_ACTIVE := 5
## How many a warden offers at a time, and how often the offers change.
const BOARD_SIZE := 3
const BOARD_SECONDS := 300.0


static func story(id: String) -> Dictionary:
	var quest: Dictionary = STORY[id].duplicate(true)
	quest["id"] = id
	quest["story"] = true
	return quest


## One line describing what a quest asks for.
static func describe_objective(objective: Dictionary) -> String:
	var count: int = objective["count"]
	var target: String = objective["target"]
	match objective["type"]:
		"kill":
			return "Defeat %d %s" % [count, _plural(EnemyDB.ENEMIES[target]["name"], count) if target != "" else "enemies"]
		"elite":
			return "Defeat %d Elite or Champion %s" % [count, "enemies" if count > 1 else "enemy"]
		"collect":
			return "Gather %d %s" % [count, ItemDB.ITEMS[target]["name"]]
		"craft":
			return "Craft %d %s with %s" % [count, "things" if count > 1 else "thing", Professions.NAMES[target]] if target != "" else "Craft %d things" % count
		"explore":
			return "Discover %d kinds of terrain" % count
		"class":
			return "Choose a class"
	return ""


## Lines describing a quest's rewards.
static func describe_rewards(rewards: Dictionary) -> PackedStringArray:
	var parts: PackedStringArray = []
	if rewards.get("xp", 0) > 0:
		parts.append("%d XP" % rewards["xp"])
	if rewards.get("gold", 0) > 0:
		parts.append("%d gold" % rewards["gold"])
	for entry: Array in rewards.get("items", []):
		parts.append("%s x%d" % [ItemDB.ITEMS[entry[0]]["name"], entry[1]])
	if rewards.has("gear_rarity"):
		parts.append("%s equipment" % ItemDB.RARITIES[rewards["gear_rarity"]]["name"])
	if rewards.has("profession"):
		parts.append("%d %s XP" % [roundi(rewards["profession"][1]), Professions.NAMES[rewards["profession"][0]]])
	return parts


## Makes up a job suited to the player: only enemies, materials, and crafts
## they can actually reach right now.
static func generate(player: Player) -> Dictionary:
	var level := player.leveling.level
	var kinds: Array[String] = ["kill", "kill", "kill", "collect", "collect", "craft"]
	if level >= 3:
		kinds.append("elite")
	var type: String = kinds.pick_random()
	var objective := {"type": type, "target": "", "count": 1}
	var rewards := {}
	var title := ""
	match type:
		"kill":
			var options: Array[String] = []
			for id: String in EnemyDB.ENEMIES:
				if EnemyDB.ENEMIES[id]["min_level"] <= maxi(floori(level * 0.7), 1):
					options.append(id)
			objective["target"] = options.pick_random()
			objective["count"] = randi_range(5, 10)
			title = "Cull: %s" % EnemyDB.ENEMIES[objective["target"]]["name"]
		"elite":
			objective["count"] = randi_range(1, 2)
			rewards["gear_rarity"] = 1
			title = "Bounty"
		"collect":
			var options: Array[String] = []
			for id: String in GatherDB.RESOURCES:
				var data: Dictionary = GatherDB.RESOURCES[id]
				var profession: String = GatherDB.KINDS[data["kind"]]["profession"]
				var tool: String = GatherDB.KINDS[data["kind"]]["tool"]
				var tier := 0 if tool == "" else 0 if player.inventory.best_tool(tool) == null else int(player.inventory.best_tool(tool).definition()["tool"]["tier"])
				if player.professions.level(profession) >= data["level"] and (tool == "" or tier >= data["tier"]):
					options.append(id)
			var resource: Dictionary = GatherDB.RESOURCES[options.pick_random()]
			objective["target"] = resource["item"]
			objective["count"] = randi_range(4, 8)
			rewards["profession"] = [GatherDB.KINDS[resource["kind"]]["profession"], 20.0 + resource["level"] * 4.0]
			title = "Supplies: %s" % ItemDB.ITEMS[resource["item"]]["name"]
		"craft":
			objective["target"] = ["blacksmithing", "alchemy", "cooking"].pick_random()
			objective["count"] = randi_range(2, 4)
			rewards["profession"] = [objective["target"], 30.0]
			title = "Commission: %s" % Professions.NAMES[objective["target"]]
	var effort: float = 0.2 + 0.02 * objective["count"] * (4.0 if type == "elite" else 1.0)
	rewards["xp"] = roundi(Leveling.xp_required(level) * effort)
	rewards["gold"] = 15 * level + objective["count"] * 6
	return {
		"id": "job_%d" % (randi() % 100000000), "title": title, "story": false,
		"text": "Work posted by the wardens. " + describe_objective(objective) + ".",
		"objective": objective, "rewards": rewards,
	}


static func _plural(name: String, count: int) -> String:
	if count == 1:
		return name
	return name + "es" if name.ends_with("s") else name + "s"
