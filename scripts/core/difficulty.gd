class_name Difficulty
extends RefCounted
## The difficulty chosen when a world is made. Every number here multiplies
## the Normal value. `current` is set when a game loads.

const LEVELS: Array[String] = ["peaceful", "easy", "normal", "hard", "insane"]
const DATA := {
	"peaceful": {"name": "Peaceful", "text": "Monsters keep to themselves unless you strike first, and barely hurt. Dying costs nothing.",
		"damage": 0.25, "health": 0.5, "speed": 0.9, "elites": 0.4, "xp": 0.75, "loot": 1.0, "death_loss": 0.0, "passive": true},
	"easy": {"name": "Easy", "text": "Gentler monsters and a light penalty for dying.",
		"damage": 0.6, "health": 0.75, "speed": 0.95, "elites": 0.7, "xp": 0.9, "loot": 1.0, "death_loss": 0.1, "passive": false},
	"normal": {"name": "Normal", "text": "The world as it was meant to be.",
		"damage": 1.0, "health": 1.0, "speed": 1.0, "elites": 1.0, "xp": 1.0, "loot": 1.0, "death_loss": 0.25, "passive": false},
	"hard": {"name": "Hard", "text": "Monsters hit harder, last longer, and lead more Elites. Better rewards.",
		"damage": 1.45, "health": 1.45, "speed": 1.06, "elites": 1.6, "xp": 1.25, "loot": 1.2, "death_loss": 0.35, "passive": false},
	"insane": {"name": "Insane", "text": "Everything wants you dead, quickly. Dying costs half your progress. Rich rewards for those who last.",
		"damage": 2.1, "health": 2.1, "speed": 1.15, "elites": 3.0, "xp": 1.6, "loot": 1.5, "death_loss": 0.5, "passive": false},
}

static var current := "normal"


static func value(key: String) -> Variant:
	return DATA.get(current, DATA["normal"])[key]


static func display_name(level: String = current) -> String:
	return DATA.get(level, DATA["normal"])["name"]


static func damage_to_player() -> float:
	return value("damage")


## On Peaceful, monsters only fight once provoked.
static func monsters_passive() -> bool:
	return value("passive")
