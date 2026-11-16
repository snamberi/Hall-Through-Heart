class_name HeartRift
extends Node
## Heart Rifts: timed runs through a wound in the world, entered from the
## rift at the Sanctuary. Each week the rift turns over: three affixes (two
## that strengthen every monster inside, one that weakens you) and the boss
## waiting at the end. Clear it before the clock runs out to go a depth
## deeper next time; the deeper, the stronger the monsters and the richer
## the hoard, and every clear pays in Rift Shards.
##
## This node keeps your rift record (depth, best time this week); the run
## itself is a RiftRun inside the rift's rooms (see Instances.enter_rift).

signal changed

const WEEK := 7 * 86400
## The Unix epoch fell on a Thursday; weeks turn over on Monday.
const WEEK_OFFSET := 4 * 86400
## Affixes on the monsters: ids from Enemy.MODIFIERS.
const MONSTER_AFFIXES: Array[String] = ["swift", "vampiric", "armored", "explosive", "regenerating", "shielded", "thorns", "burning",
	"poisonous", "bloodletter", "teleporting", "molten"]
## Affixes on you.
const PLAYER_AFFIXES := {
	"fragile": {"name": "Fragile", "text": "You take 20% more damage.", "mods": {"damage_taken": {"percent": 0.2}}},
	"starved": {"name": "Starved", "text": "Your health returns half as fast.", "mods": {"health_regen": {"percent": -0.5}}},
	"glass": {"name": "Glass Edge", "text": "You deal 20% more damage, and take 20% more.", "mods": {"physical_damage": {"percent": 0.2}, "magic_power": {"percent": 0.2}, "damage_taken": {"percent": 0.2}}},
	"weary": {"name": "Weary", "text": "Stamina returns 40% slower.", "mods": {"stamina_regen": {"percent": -0.4}}},
	"drained": {"name": "Drained", "text": "Mana returns half as fast.", "mods": {"mana_regen": {"percent": -0.5}}},
}
## What each monster affix does, for the rift's page.
const MONSTER_TEXT := {
	"swift": "Monsters move and wind up faster.", "vampiric": "Monsters heal from their blows.", "armored": "Monsters shrug off part of every hit.",
	"explosive": "Monsters burst when they die.", "regenerating": "Monsters heal over time.", "shielded": "Monsters carry a barrier that returns.",
	"thorns": "Hitting monsters hurts you a little.", "burning": "Monsters' blows set you alight.", "poisonous": "Monsters' blows poison.",
	"bloodletter": "Monsters' blows make you bleed.", "teleporting": "Monsters blink about.", "molten": "Monsters leave fire where they walk.",
}
## Bosses that may wait at the end (not the Sword Keeper, whose fight is
## its own story).
const BOSSES: Array[String] = ["weeping_shade", "hollow_king", "rot_mother", "cinderlord", "frostwarden", "pale_matron", "sunless_prophet",
	"briar_queen", "dune_tyrant", "rime_colossus", "molten_heart", "mire_leviathan", "elder_grove", "unblinking_eye"]
## Monster levels added per depth.
const LEVELS_PER_DEPTH := 2

var depth := 1
## Week number -> best time that week.
var best: Dictionary = {}
var clears := 0
var timed_clears := 0


func _ready() -> void:
	SaveGame.register("rifts", self)


static func week(at: float = -1.0) -> int:
	var now := at if at >= 0.0 else Time.get_unix_time_from_system()
	return int(floor((now - WEEK_OFFSET) / WEEK))


static func seconds_left_in_week() -> float:
	var now := Time.get_unix_time_from_system()
	return WEEK - fposmod(now - WEEK_OFFSET, WEEK)


## This week's affixes: [monster, monster, player].
static func affixes(for_week: int) -> Array[String]:
	var random := RandomNumberGenerator.new()
	random.seed = hash(["heart_rift", for_week])
	var pool := MONSTER_AFFIXES.duplicate()
	var result: Array[String] = []
	for index in 2:
		var pick: String = pool[random.randi_range(0, pool.size() - 1)]
		pool.erase(pick)
		result.append(pick)
	var players: Array = PLAYER_AFFIXES.keys()
	result.append(players[random.randi_range(0, players.size() - 1)])
	return result


static func boss(for_week: int) -> String:
	var random := RandomNumberGenerator.new()
	random.seed = hash(["heart_rift_boss", for_week])
	return BOSSES[random.randi_range(0, BOSSES.size() - 1)]


static func affix_name(id: String) -> String:
	if PLAYER_AFFIXES.has(id):
		return PLAYER_AFFIXES[id]["name"]
	return Enemy.MODIFIERS[id]["name"]


static func affix_text(id: String) -> String:
	if PLAYER_AFFIXES.has(id):
		return PLAYER_AFFIXES[id]["text"]
	return MONSTER_TEXT.get(id, "")


## Seconds allowed for a rift of this many rooms.
static func time_limit(rooms: int) -> float:
	return 120.0 + 55.0 * rooms


func level_for(player: Player) -> int:
	return maxi(player.leveling.level, 5) + (depth - 1) * LEVELS_PER_DEPTH


func best_this_week() -> float:
	return float(best.get(str(week()), -1.0))


## Notes a cleared rift: deeper if timed. Returns the shards earned.
func record(seconds: float, timed: bool) -> int:
	clears += 1
	var key := str(week())
	if not best.has(key) or seconds < float(best[key]):
		best[key] = seconds
	var shards := 1 + depth / 3
	if timed:
		timed_clears += 1
		shards += 2 + depth / 2
		depth += 1
	changed.emit()
	SaveGame.request_save()
	return shards


## A rift left unfinished, or not timed, costs a depth (never below 1).
func fall_back() -> void:
	depth = maxi(depth - 1, 1)
	changed.emit()
	SaveGame.request_save()


func save_data() -> Dictionary:
	return {"depth": depth, "best": best.duplicate(), "clears": clears, "timed": timed_clears}


func load_data(data: Dictionary) -> void:
	depth = maxi(int(data.get("depth", 1)), 1)
	best = data.get("best", {}).duplicate()
	clears = int(data.get("clears", 0))
	timed_clears = int(data.get("timed", 0))
