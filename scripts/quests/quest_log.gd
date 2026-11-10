class_name QuestLog
extends Node
## The player's quests: what is active, how far along each is, what is done,
## and which kinds of terrain have been discovered.
##
## It listens to progression events, so nothing else needs to know about
## quests. Finishing a quest pays out at once.

signal changed

## Experience for the first step onto each new kind of terrain, times level.
const DISCOVERY_XP := 12

## Active quests, each with a "progress" count added.
var active: Array[Dictionary] = []
var completed: Array[String] = []
var discovered: Array[int] = []
## What the wardens are offering right now.
var offers: Array[Dictionary] = []

var _offers_at := -QuestDB.BOARD_SECONDS
var _check_left := 0.0
var _loaded := false

@onready var _player: Player = get_parent()


func _ready() -> void:
	SaveGame.register("quests", self)
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.resource_gathered.connect(func(info: Dictionary) -> void: _advance("collect", info["item"], info["count"]))
	Events.item_crafted.connect(func(recipe_id: String) -> void:
		var recipe := RecipeDB.find(recipe_id)
		if not recipe.is_empty():
			_advance("craft", recipe["profession"], 1)
	)
	if not _loaded:
		# A new character begins the story.
		_start(QuestDB.story(QuestDB.STORY_START))


func _physics_process(delta: float) -> void:
	_check_left -= delta
	if _check_left > 0.0 or _player.is_dead():
		return
	_check_left = 0.5
	var world: World = _player.get_parent().get_node_or_null("World")
	if world and world.generator:
		var tile := world.generator.tile_type_at(world.world_to_cell(_player.global_position))
		if not tile in discovered:
			discovered.append(tile)
			if discovered.size() > 1:
				var xp := DISCOVERY_XP * _player.leveling.level
				_player.leveling.add_xp(xp, "exploration")
				Events.biome_discovered.emit(TerrainTiles.display_name(tile), xp)
			_advance("explore", "", 1)
	if _player.class_id != "adventurer":
		_advance("class", "", 1)


func has_room() -> bool:
	return active.size() < QuestDB.MAX_ACTIVE


## Takes one of the wardens' offers. Returns "" or why it was refused.
func accept(quest: Dictionary) -> String:
	if not has_room():
		return "You can only hold %d quests at once." % QuestDB.MAX_ACTIVE
	offers.erase(quest)
	_start(quest)
	return ""


func abandon(quest: Dictionary) -> void:
	if quest.get("story", false):
		return
	active.erase(quest)
	changed.emit()
	SaveGame.request_save()


## Makes sure the wardens have fresh work to offer.
func refresh_offers() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _offers_at < QuestDB.BOARD_SECONDS and not offers.is_empty():
		return
	_offers_at = now
	offers.clear()
	for i in QuestDB.BOARD_SIZE:
		offers.append(QuestDB.generate(_player))
	changed.emit()


func offers_change_in() -> float:
	return maxf(QuestDB.BOARD_SECONDS - (Time.get_ticks_msec() / 1000.0 - _offers_at), 0.0)


func save_data() -> Dictionary:
	return {"active": active.duplicate(true), "completed": completed.duplicate(), "discovered": discovered.duplicate()}


func load_data(data: Dictionary) -> void:
	_loaded = true
	active.clear()
	completed.clear()
	discovered.clear()
	for id: Variant in data.get("completed", []):
		completed.append(str(id))
	for tile: Variant in data.get("discovered", []):
		discovered.append(int(tile))
	for saved: Variant in data.get("active", []):
		if not saved is Dictionary or not saved.has("objective"):
			continue
		var quest: Dictionary = saved
		# Story quests are rebuilt from the database so text fixes reach old saves.
		if quest.get("story", false):
			if not QuestDB.STORY.has(quest.get("id", "")):
				continue
			var fresh := QuestDB.story(quest["id"])
			fresh["progress"] = int(quest.get("progress", 0))
			quest = fresh
		else:
			quest["progress"] = int(quest.get("progress", 0))
			quest["objective"]["count"] = int(quest["objective"]["count"])
			if quest["rewards"].has("gear_rarity"):
				quest["rewards"]["gear_rarity"] = int(quest["rewards"]["gear_rarity"])
		active.append(quest)


func _start(quest: Dictionary) -> void:
	quest["progress"] = 0
	active.append(quest)
	changed.emit()
	SaveGame.request_save()


func _on_enemy_killed(info: Dictionary) -> void:
	if info.get("fragment", false):
		return
	_advance("kill", info["id"], 1)
	if info["rank"] != "normal":
		_advance("elite", "", 1)


## Adds progress to every active quest of a type whose target matches.
func _advance(type: String, target: String, amount: int) -> void:
	var finished: Array[Dictionary] = []
	var touched := false
	for quest in active:
		var objective: Dictionary = quest["objective"]
		if objective["type"] != type or quest["progress"] >= objective["count"]:
			continue
		if objective["target"] != "" and objective["target"] != target:
			continue
		quest["progress"] = mini(quest["progress"] + amount, objective["count"])
		touched = true
		if quest["progress"] >= objective["count"]:
			finished.append(quest)
	for quest in finished:
		_complete(quest)
	if touched:
		changed.emit()


func _complete(quest: Dictionary) -> void:
	active.erase(quest)
	if quest.get("story", false):
		completed.append(quest["id"])
	var rewards: Dictionary = quest["rewards"]
	_player.inventory.add_gold(int(rewards.get("gold", 0)))
	for entry: Array in rewards.get("items", []):
		_player.inventory.add(Item.create(entry[0], int(entry[1])))
	if rewards.has("gear_rarity"):
		_player.inventory.add(LootGenerator.make_equipment(_player.leveling.level, int(rewards["gear_rarity"]), "", 0.5))
	if rewards.has("profession"):
		_player.professions.add_xp(rewards["profession"][0], float(rewards["profession"][1]))
	Events.quest_completed.emit(quest["title"], ", ".join(QuestDB.describe_rewards(rewards)))
	_player.leveling.add_xp(int(rewards.get("xp", 0)), "quest")
	var next: String = quest.get("next", "")
	if next != "" and QuestDB.STORY.has(next):
		_start(QuestDB.story(next))
	changed.emit()
	SaveGame.request_save()
