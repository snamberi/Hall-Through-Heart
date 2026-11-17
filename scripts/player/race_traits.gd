class_name RaceTraits
extends Node
## What each race does that nobody else can: big gifts and real costs, and
## a way of playing of its own. The stat side is in Appearance.RACES (the
## race's "mods"); this holds the rest, read where it matters:
##   bag        more (or fewer) inventory slots: an orc carries more
##   water      speed multiplier while swimming: slimes and merfolk glide
##   cold       speed multiplier on snow and frost: cold-blooded lizardfolk
##   aim        projectiles fly this much faster and further: elves
##   mining     how much faster stone and ore come away: dwarves
##   yield      chance of one more of whatever is gathered: dwarves, goblins
##   learning   profession experience multiplier: humans
##   night/day  stat mods while it is night (or day) outside: vampires,
##              the undead, demonkin, beastkin
## Each has "lines": how it is shown on the race's card.

const TRAITS := {
	"human": {"learning": 1.3, "lines": ["Quick to learn: professions level 30% faster."]},
	"elf": {"aim": 1.35, "lines": ["Keen eyes: your arrows and bolts fly 35% faster and further."]},
	"dwarf": {"mining": 1.6, "yield": 0.4, "water": 0.7, "lines": ["Born miners: ore and stone come away 60% faster, 40% chance of one more.", "Sink like stones: 30% slower in water."]},
	"orc": {"bag": 15, "lines": ["Big and strong: 15 more bag slots, because they can carry more."]},
	"goblin": {"bag": 5, "yield": 0.2, "lines": ["Light fingers: 5 more bag slots and a 20% chance of one more of anything gathered."]},
	"slime": {"water": 1.7, "lines": ["Half water already: 70% faster while swimming."]},
	"undead": {"water": 1.2, "day": {"physical_damage": {"percent": -0.12}, "magic_power": {"percent": -0.12}},
		"night": {"physical_damage": {"percent": 0.08}, "move_speed": {"percent": 0.06}}, "lines": ["No need to breathe: 20% faster in water.", "Weak in the sun (-12% damage by day), strong in the dark."]},
	"demonkin": {"water": 0.75, "night": {"fire_damage": {"flat": 4.0}}, "lines": ["Hates water: 25% slower swimming.", "The fire burns hotter at night (+4 fire damage)."]},
	"beastkin": {"night": {"critical_chance": {"flat": 0.06}, "move_speed": {"percent": 0.06}}, "lines": ["A night hunter: +6% crit chance and speed after dark."]},
	"lizardfolk": {"water": 1.45, "cold": 0.75, "lines": ["Strong swimmers: 45% faster in water.", "Cold-blooded: 25% slower on snow and frost."]},
	"fairy": {"bag": -10, "water": 1.25, "lines": ["Tiny: 10 fewer bag slots.", "Skims the water on its wings: 25% faster swimming."]},
	"stoneborn": {"water": 0.5, "mining": 1.3, "lines": ["Made of stone: sinks, half speed in water.", "Knows the rock: mining 30% faster."]},
	"vampire": {"day": {"health_regen": {"flat": -1.5}, "move_speed": {"percent": -0.08}},
		"night": {"physical_damage": {"percent": 0.15}, "life_steal": {"flat": 0.03}, "move_speed": {"percent": 0.1}}, "lines": ["The sun burns: health drains and you slow by day.", "The night is yours: +15% damage, more life steal and speed."]},
	"merfolk": {"water": 2.0, "lines": ["Of the deep water: twice as fast swimming."]},
}

var _player: Player
var _day_night: DayNight
var _was_night := -1


static func of(race: String) -> Dictionary:
	return TRAITS.get(race, {})


static func value(race: String, key: String, fallback: Variant) -> Variant:
	return TRAITS.get(race, {}).get(key, fallback)


func setup(player: Player, day_night: DayNight) -> void:
	_player = player
	_day_night = day_night
	apply()


## Sets what does not change with the hour: the bag.
func apply() -> void:
	if _player == null:
		return
	_player.inventory.race_slots = int(value(_player.race(), "bag", 0))
	_player.inventory.changed.emit()
	_was_night = -1


func _process(_delta: float) -> void:
	if _player == null or _day_night == null or Engine.get_process_frames() % 30 != 0:
		return
	var night := 1 if _day_night.is_night_outside() else 0
	if night == _was_night:
		return
	_was_night = night
	var traits := of(_player.race())
	var mods: Dictionary = traits.get("night" if night == 1 else "day", {})
	_player.stats.set_modifiers("race_hour", mods)
