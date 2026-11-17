class_name Factions
extends Node
## The monsters' factions, and what each has learned about how the player
## fights.
##
## Monsters remember the blows they live through. One hurt by fire shouts a
## warning to its kin nearby, who scatter and brace against it; one shot at
## from afar tells the others to spread out; a group cut down up close
## raises shields. What a monster knows reaches its faction only if it gets
## away alive: a badly hurt monster may run for it, and one left behind
## when the player moves on counts as having escaped too.
##
## A faction that knows how the player fights sends its next ones ready:
##   up close   (swords, axes, fists...)  more of them come shielded
##   from afar  (bows)                    they come spread out and weaving
##   sorcery    (staves, spells)          they come warded against magic
##   an element (fire, frost...)          they come warded against it
## Each faction knows only what its own escaped. Knowledge fades when the
## player keeps away: each day without meeting them they forget a quarter.
##
## False Reputation: a faction knows only what it was shown. Fight one with
## a bow, let a few get away, and it comes ready for an archer; meet it up
## close instead and the first blow on each catches it off guard.

const LIST := {
	"hollow": {"name": "The Hollow Host", "color": Color(0.75, 0.68, 0.95),
		"members": ["husk", "bone_archer", "rot_cultist", "ash_wraith", "rotten_corpse", "ghost", "dune_mummy"]},
	"feral": {"name": "The Feral Packs", "color": Color(0.9, 0.45, 0.35),
		"members": ["rot_hound", "carrion_bat", "thorn_stalker", "giant_spider", "web_spider", "frost_wolf", "dire_boar", "sand_scorpion", "storm_harpy"]},
	"mire": {"name": "The Mire Brood", "color": Color(0.55, 0.85, 0.4),
		"members": ["bog_slime", "spore_shambler", "treant", "bog_lurker"]},
	"ember": {"name": "The Ember Court", "color": Color(1.0, 0.6, 0.3),
		"members": ["ember_wisp", "magma_slime", "cinder_imp", "crimson_fiend"]},
	"stone": {"name": "The Stone Kin", "color": Color(0.7, 0.8, 0.9),
		"members": ["crag_golem", "frost_troll"]},
	"void": {"name": "The Void Choir", "color": Color(0.7, 0.5, 1.0),
		"members": ["void_stalker", "void_eye"]},
	"heart": {"name": "The Heartsworn", "color": Color(0.95, 0.3, 0.4),
		"members": ["veinheart", "heartsworn_knight"]},
	"lull": {"name": "The Lull Court", "color": Color(0.96, 0.94, 0.9),
		"members": ["masked_noble", "matron"]},
}
const STYLES := ["melee", "ranged", "magic"]
const STYLE_NAMES := {"melee": "up close", "ranged": "from afar", "magic": "with sorcery"}
## What a faction makes of a player who mostly fights a given way.
const BELIEF := {"melee": "a blade-fighter", "ranged": "an archer", "magic": "a sorcerer"}
## Points of lessons for a faction to know a thing fully.
const FULL := 10.0
## Share of what it knows a faction keeps for each day it does not meet the player.
const KEEP_PER_DAY := 0.75
## How much harder a blow lands when it is not what the faction expected.
const SURPRISE := 1.35

## faction -> {"styles": {style: points}, "elements": {element: points}, "day": day last updated}
var known: Dictionary = {}
## Treaties: faction -> the day it was made. A faction at peace leaves you
## be (unless you strike one of them, which ends it) and sends gifts to your
## town. The Lull Court makes no treaties.
var treaties: Dictionary = {}
## Factions that broke with you: faction -> the day; no new treaty for a while.
var grudges: Dictionary = {}
const NO_TREATY: Array[String] = ["lull"]
const TREATY_BASE_COST := 300
const GRUDGE_DAYS := 5

var _day_night: DayNight


func _ready() -> void:
	add_to_group("factions")
	SaveGame.register("factions", self)


func setup(day_night: DayNight) -> void:
	_day_night = day_night


## The faction a kind of monster belongs to, or "".
static func of(enemy_id: String) -> String:
	for id: String in LIST:
		if enemy_id in LIST[id]["members"]:
			return id
	return ""


## How a blow with this weapon type looks to the monster it lands on.
static func style_of(weapon_type: String) -> String:
	match weapon_type:
		"":
			return ""
		"bows":
			return "ranged"
		"staves", "magic":
			return "magic"
	return "melee"


func _today() -> int:
	return _day_night.day if _day_night else 1


## A faction's memory, faded for the days since it last met the player.
func _memory(faction: String) -> Dictionary:
	var memory: Dictionary = known.get(faction, {"styles": {}, "elements": {}, "day": _today()})
	var away := _today() - int(memory.get("day", _today()))
	if away > 0:
		var keep := pow(KEEP_PER_DAY, away)
		for group: String in ["styles", "elements"]:
			var points: Dictionary = memory.get(group, {})
			for key: String in points.keys():
				points[key] = float(points[key]) * keep
				if points[key] < 0.2:
					points.erase(key)
			memory[group] = points
		memory["day"] = _today()
	return memory


## Escaped monsters tell their faction what they saw:
## lesson = {"styles": {style: count}, "elements": {element: count}}.
func report(faction: String, lesson: Dictionary) -> void:
	if faction == "" or not LIST.has(faction):
		return
	var memory := _memory(faction)
	for group: String in ["styles", "elements"]:
		var points: Dictionary = memory.get(group, {})
		var told: Dictionary = lesson.get(group, {})
		for key: String in told:
			points[key] = minf(float(points.get(key, 0.0)) + float(told[key]), FULL * 1.5)
		memory[group] = points
	memory["day"] = _today()
	known[faction] = memory
	SaveGame.request_save()


## How well a faction knows something about the player, 0 to 1.
func knows(faction: String, group: String, key: String) -> float:
	if not known.has(faction):
		return 0.0
	return clampf(float((_memory(faction).get(group, {}) as Dictionary).get(key, 0.0)) / FULL, 0.0, 1.0)


## The way a faction believes the player fights, or "" if it has no idea
## (it needs to know at least half as much as it could).
func belief(faction: String) -> String:
	var best := ""
	var most := 0.5
	for style: String in STYLES:
		var sure := knows(faction, "styles", style)
		if sure >= most:
			best = style
			most = sure
	return best


## The element a faction has learned to fear most, or "".
func feared_element(faction: String) -> String:
	if not known.has(faction):
		return ""
	var best := ""
	var most := 0.3
	for element: String in (_memory(faction).get("elements", {}) as Dictionary):
		var sure := knows(faction, "elements", element)
		if sure >= most:
			best = element
			most = sure
	return best


## A faction's view of the player in a sentence.
func describe(faction: String) -> String:
	var style := belief(faction)
	var element := feared_element(faction)
	if style == "" and element == "":
		return "They know nothing of you yet." if not known.has(faction) else "They have heard of you, but know little."
	var words := "They believe you are %s" % BELIEF[style] if style != "" else "They are unsure how you fight"
	if element != "":
		words += ", and they fear your %s" % element
	return words + "."


## Readies a newly come monster with what its faction knows (called before
## it enters the world).
func adapt(enemy: Enemy) -> void:
	var faction := of(enemy.enemy_id)
	enemy.faction = faction
	if faction == "" or enemy.boss_id != "" or not known.has(faction):
		return
	enemy.expected = belief(faction)
	if randf() < knows(faction, "styles", "melee") * 0.7:
		enemy.extra_modifiers.append("shielded")
	if randf() < knows(faction, "styles", "ranged") * 0.8:
		enemy.spread = true
	var magic := knows(faction, "styles", "magic")
	if magic > 0.0:
		enemy.wards["magic"] = 0.35 * magic
	for element: String in (_memory(faction).get("elements", {}) as Dictionary):
		enemy.wards[element] = 0.4 * knows(faction, "elements", element)


## What villagers have heard the monsters say of the player.
func rumours() -> Array[String]:
	var out: Array[String] = []
	for faction: String in known:
		var style := belief(faction)
		if style == "":
			continue
		var ready: String = {"melee": "they've been coming with shields up", "ranged": "they come spread out now, weaving as they run",
			"magic": "they've taken to wearing charms against sorcery"}[style]
		out.append("%s think you're %s. Since then %s." % [LIST[faction]["name"], BELIEF[style], ready])
	return out


# --- treaties

func at_peace(faction: String) -> bool:
	return faction != "" and treaties.has(faction)


func treaty_cost() -> int:
	return TREATY_BASE_COST * (treaties.size() + 1)


## Why a treaty with a faction cannot be made now, or "". One of their own
## kind, Named and living in your town, must speak for you.
func treaty_problem(faction: String, town: Node, player: Player) -> String:
	if faction in NO_TREATY:
		return "The Court does not make treaties with food."
	if treaties.has(faction):
		return "You are already at peace."
	if grudges.has(faction) and _today() - int(grudges[faction]) < GRUDGE_DAYS:
		return "They remember the last treaty you broke. (%d more days)" % (GRUDGE_DAYS - (_today() - int(grudges[faction])))
	if town == null or not town.has_speaker(faction):
		return "One of their kind, Named and living in your town, must speak for you."
	if player.inventory.gold < treaty_cost():
		return "The tribute is %d gold." % treaty_cost()
	return ""


func sign_treaty(faction: String, player: Player) -> void:
	player.inventory.add_gold(-treaty_cost())
	treaties[faction] = _today()
	known.erase(faction)
	Events.codex_event.emit("treaties", 1)
	Voices.heart(get_tree(), "A treaty is made with %s." % LIST[faction]["name"], "Their kind will leave you be, and send gifts to your town. Strike one of them and it ends.")
	SaveGame.request_save()


## A member of a faction at peace was struck: the treaty is over.
func break_treaty(faction: String) -> void:
	if not treaties.has(faction):
		return
	treaties.erase(faction)
	grudges[faction] = _today()
	report(faction, {"styles": {"melee": 3}})
	Voices.heart(get_tree(), "The treaty with %s is broken." % LIST[faction]["name"], "They will remember this.")
	SaveGame.request_save()


func save_data() -> Dictionary:
	return {"known": known, "treaties": treaties, "grudges": grudges}


func load_data(data: Dictionary) -> void:
	var saved: Variant = data.get("known", {})
	known = saved if saved is Dictionary else {}
	treaties = data.get("treaties", {}) if data.get("treaties") is Dictionary else {}
	grudges = data.get("grudges", {}) if data.get("grudges") is Dictionary else {}
