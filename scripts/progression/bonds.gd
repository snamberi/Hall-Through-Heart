extends Node
## Bonds: bonuses that wake when the game's systems meet. A meal and a good
## night's sleep, a shrine's blessing and the standing stones', fine steel
## and the hand that has learned it, walking among your own people, every
## chapter of the world's story you have uncovered... Each bond is a lasting
## buff on the HUD that says why it is there, and goes when its reason
## does. (Loaded by path.)

const LORE_BOOK := preload("res://scripts/progression/lore.gd")
const VILLAGES := preload("res://scripts/world/villages.gd")

## id -> name, what wakes it (shown on the buff), and what it gives. Some
## bonds grow with a count (see _check); "per" is what one step gives.
const BONDS := {
	"hearth": {"name": "Hearth and Home", "why": "A hot meal and a night's rest.",
		"mods": {"health_regen": {"flat": 2.0}, "max_health": {"percent": 0.05}}},
	"full_table": {"name": "A Full Table", "why": "A meal, a drink and a treat at once.",
		"mods": {"physical_damage": {"percent": 0.06}, "magic_power": {"percent": 0.06}, "move_speed": {"percent": 0.04}}},
	"pilgrim": {"name": "Pilgrim's Grace", "why": "Blessed by a shrine and by the standing stones together.",
		"mods": {"critical_damage": {"flat": 0.2}, "elemental_resistance": {"flat": 0.08}}},
	"kin": {"name": "Among Kin", "why": "Walking among your own people.",
		"mods": {"gold_find": {"flat": 0.15}, "health_regen": {"flat": 1.0}}},
	"worthy_steel": {"name": "Worthy Steel", "why": "A weapon grown fine in a hand that has earned it.",
		"per": {"critical_chance": {"flat": 0.015}}},
	"torch_dark": {"name": "Torch in the Dark", "why": "Carrying light through the night.",
		"mods": {"critical_damage": {"flat": 0.15}, "damage_taken": {"percent": -0.05}}},
	"telling": {"name": "Keeper of the Telling", "why": "Every chapter of the world's story you have uncovered.",
		"per": {"xp_gain": {"flat": 0.01}}},
	"friend": {"name": "Friend of the Villages", "why": "Every errand done for villagers.",
		"per": {"gold_find": {"flat": 0.01}}, "most": 10},
	"goblin_wisdom": {"name": "Goblin Wisdom", "why": "Every lesson a goblin sage has taught you.",
		"per": {"magic_find": {"flat": 0.03}, "xp_gain": {"flat": 0.02}}},
	"kit_complete": {"name": "Kit Complete", "why": "A matched set of armour and a trinket worn with it.",
		"mods": {"armor": {"percent": 0.08}, "dodge_efficiency": {"flat": 0.04}}},
	"heart_in_tune": {"name": "Heart in Tune", "why": "A steady heart at full health.",
		"mods": {"physical_damage": {"percent": 0.05}, "attack_speed": {"percent": 0.04}}},
	"momentum": {"name": "Momentum", "why": "Three foes down in quick succession.",
		"mods": {"attack_speed": {"percent": 0.12}, "move_speed": {"percent": 0.06}}},
	"storm_sorcery": {"name": "Storm-fed Sorcery", "why": "Casting magic under a storm.",
		"mods": {"magic_power": {"percent": 0.1}, "max_mana": {"percent": 0.08}}},
}
## How long Momentum lasts after the third quick kill, and how quick.
const MOMENTUM_SECONDS := 8.0
const QUICK_KILLS := 8.0

var _player: Player
var _check_left := 0.0
var _kills: Array[float] = []
var _momentum_left := 0.0
## Bonds already woken once (each is announced the first time).
var known: Dictionary = {}


func setup(player: Player) -> void:
	_player = player
	Events.enemy_killed.connect(func(_info: Dictionary) -> void: note_kill())


## A foe down: three in quick succession wake Momentum.
func note_kill() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	_kills.append(now)
	_kills = _kills.filter(func(t: float) -> bool: return now - t < QUICK_KILLS)
	if _kills.size() >= 3:
		_momentum_left = MOMENTUM_SECONDS
		_check_left = 0.0


func _process(delta: float) -> void:
	_momentum_left = maxf(_momentum_left - delta, 0.0)
	_check_left -= delta
	if _check_left > 0.0 or _player == null or _player.is_dead():
		return
	_check_left = 1.0
	_check()


## How much of each bond holds now: 0 for none, 1 for an ordinary bond,
## the count for one that grows.
func strengths() -> Dictionary:
	var buffs := _player.buffs
	var main := _player.get_parent()
	var result := {}
	result["hearth"] = 1 if buffs.has("well_rested") and buffs.has("food_meal") else 0
	result["full_table"] = 1 if buffs.has("food_meal") and buffs.has("food_drink") and buffs.has("food_treat") else 0
	result["pilgrim"] = 1 if buffs.has("blessing") and buffs.has("henge") else 0
	result["kin"] = 1 if _among_kin(main) else 0
	var held: Item = _player.equipment.weapon() if _player.equipment else null
	result["worthy_steel"] = PlayerAnimator.weapon_grade(held) if held else 0
	var night: DayNight = main.get_node_or_null("DayNight")
	result["torch_dark"] = 1 if buffs.has("torchlight") and night and night.is_night() else 0
	var codex: Codex = main.get_node_or_null("Codex")
	result["telling"] = LORE_BOOK.open_chapters(codex.stats).size() if codex else 0
	var errands: Node = main.get_node_or_null("Errands")
	var helped := 0
	if errands:
		for count: Variant in (errands.get("helped") as Dictionary).values():
			helped += int(count)
	result["friend"] = mini(helped, int(BONDS["friend"]["most"]))
	var structures: Structures = main.get_node_or_null("Structures")
	var lessons := 0
	if structures:
		for key: String in structures.used:
			if key.begins_with("hermit:"):
				lessons += 1
	result["goblin_wisdom"] = lessons
	var worn: Dictionary = _player.trinkets.call("worn") if _player.trinkets and _player.trinkets.has_method("worn") else {}
	result["kit_complete"] = 1 if _player.equipment and not _player.equipment.set_bonus().is_empty() and not worn.is_empty() else 0
	var heart: Dictionary = buffs.active.get("heart", {})
	result["heart_in_tune"] = 1 if str(heart.get("name", "")).begins_with("Steady") and _player.health.current >= _player.health.max_health - 0.5 else 0
	result["momentum"] = 1 if _momentum_left > 0.0 else 0
	result["storm_sorcery"] = 1 if Atmosphere.weather == "wet" and _player.magic_school != "" else 0
	return result


func _check() -> void:
	var strength := strengths()
	for id: String in BONDS:
		var bond: Dictionary = BONDS[id]
		var amount: int = strength.get(id, 0)
		if amount <= 0:
			_player.buffs.remove("bond_" + id)
			continue
		var mods: Dictionary = bond.get("mods", {})
		if bond.has("per"):
			mods = {}
			for stat: String in bond["per"]:
				mods[stat] = {}
				for kind: String in bond["per"][stat]:
					mods[stat][kind] = float(bond["per"][stat][kind]) * amount
		var title: String = bond["name"] if not bond.has("per") else "%s %s" % [bond["name"], _roman(amount)]
		_player.buffs.bind("bond_" + id, title, mods, bond["why"], Buffs.icon_for("blessing"))
		if not known.has(id):
			known[id] = true
			Events.announcement.emit("BOND: %s" % str(bond["name"]).to_upper(), bond["why"])


## Whether the player stands in a village (or camp) of their own people.
func _among_kin(main: Node) -> bool:
	var world: World = main.get_node_or_null("World")
	if world == null or _player.indoors:
		return false
	var cell := world.world_to_cell(_player.global_position)
	var race := _player.race()
	var village: Variant = world.generator.village_near(cell)
	if village != null:
		return world.generator.village_culture(village) == race
	if race == "goblin":
		var camps: Node = main.get_node_or_null("GoblinCamps")
		if camps:
			var camp: Variant = camps.camp_center(Vector2i((Vector2(cell) / camps.CAMP_REGION).floor()))
			return camp != null and Vector2(cell - (camp as Vector2i)).length() < 12.0
	return false


static func _roman(n: int) -> String:
	return ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"][clampi(n, 0, 10)] if n <= 10 else str(n)


func save_data() -> Dictionary:
	return {"known": known.keys()}


func load_data(data: Dictionary) -> void:
	known.clear()
	for id: Variant in data.get("known", []):
		known[str(id)] = true
