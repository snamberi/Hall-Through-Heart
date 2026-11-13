class_name StyleBook
extends Node
## The combat styles the player knows, and the one they fight with from
## the first hotbar slot. Everyone knows Brawler's Fists.

signal changed

var learned: Array[String] = ["fist"]
var equipped := "fist"
var _player: Player


func _ready() -> void:
	_player = get_parent()
	SaveGame.register("styles", self)


func data() -> Dictionary:
	return CombatStyles.STYLES.get(equipped, CombatStyles.STYLES["fist"])


func equip(style: String) -> String:
	if not style in learned:
		return "You have not learned %s." % CombatStyles.STYLES[style]["name"]
	equipped = style
	changed.emit()
	SaveGame.request_save()
	return ""


## Why a master cannot teach this style now, or "".
func teach_problem(style: String) -> String:
	if style in learned:
		return "You already know %s." % CombatStyles.STYLES[style]["name"]
	var info: Dictionary = CombatStyles.STYLES[style]
	if _player.leveling.level < int(info.get("level", 1)):
		return "Come back at level %d." % info["level"]
	var cost: Dictionary = info.get("cost", {})
	for key: String in cost:
		if key == "gold":
			if _player.inventory.gold < int(cost[key]):
				return "The lesson costs %d gold." % cost[key]
		elif _player.inventory.count_of(key) < int(cost[key]):
			return "Bring %d %s." % [cost[key], ItemDB.ITEMS[key]["name"]]
	return ""


## A master teaches a style for its price. Returns "" or why not.
func learn(style: String) -> String:
	var problem := teach_problem(style)
	if problem != "":
		return problem
	var cost: Dictionary = CombatStyles.STYLES[style].get("cost", {})
	for key: String in cost:
		if key == "gold":
			_player.inventory.add_gold(-int(cost[key]))
		else:
			_player.inventory.take(key, int(cost[key]))
	learned.append(style)
	equipped = style
	Events.announcement.emit("STYLE LEARNED", "%s  -  equip styles in the Abilities screen; use it from slot 1" % CombatStyles.STYLES[style]["name"])
	Events.codex_event.emit("styles_learned", 1)
	Audio.play("level_up", -4.0)
	changed.emit()
	SaveGame.request_save()
	return ""


func save_data() -> Dictionary:
	return {"learned": learned.duplicate(), "equipped": equipped}


func load_data(data: Dictionary) -> void:
	learned = ["fist"]
	for style: Variant in data.get("learned", []):
		if CombatStyles.STYLES.has(str(style)) and not str(style) in learned:
			learned.append(str(style))
	equipped = str(data.get("equipped", "fist"))
	if not equipped in learned:
		equipped = "fist"
	changed.emit()
