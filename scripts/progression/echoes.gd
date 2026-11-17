class_name Echoes
extends Node
## The Maw: what is left of a fallen monster (its remnant, a dark wisp that
## lingers a few seconds where it fell) can be devoured. Devouring heals a
## little, and may copy one of the monster's Echoes: a gift of its kind
## (a wolf's quick feet, a golem's stone skin). Bigger prey gives more; a
## kind that has fed you before without an Echo is likelier next time.
##
## Echoes are worn in a few slots (more as you grow; a slime gets one more
## and devours better). Two Echoes may be fused into one stronger Echo,
## using both up. Rare Echoes and fusions are announced by the Heart.

## The gift of devouring is woken at this level.
const WAKE_LEVEL := 3
## How long a remnant lingers (bosses and their like for longer).
const REMNANT_SECONDS := 9.0
const REMNANT_BIG_SECONDS := 24.0
## Chance to copy an Echo, by the rank of what was devoured.
const LEARN_CHANCE: Array[float] = [0.2, 0.45, 0.6, 0.85, 1.0]
## Devours of a kind without an Echo before one is sure.
const SURE_AFTER := 3

## id -> {"name", "from": [monster ids], "text", "mods", "tier", "color"}.
## Tier 1 is copied from monsters; tier 2 only comes of fusing two.
const LIST := {
	"husk_grit": {"name": "Husk's Grit", "from": ["husk", "rotten_corpse", "dune_mummy"], "tier": 1, "color": Color("b8a888"),
		"text": "The dead keep walking. So do you.", "mods": {"max_health": {"percent": 0.06}}},
	"pack_howl": {"name": "Pack Howl", "from": ["rot_hound", "grey_wolf", "frost_wolf", "snow_fox"], "tier": 1, "color": Color("d88a6a"),
		"text": "The run of the pack, in your blood.", "mods": {"attack_speed": {"percent": 0.05}, "move_speed": {"percent": 0.04}}},
	"bone_aim": {"name": "Bone Aim", "from": ["bone_archer"], "tier": 1, "color": Color("ece0c4"),
		"text": "An eye that has stopped blinking.", "mods": {"critical_chance": {"flat": 0.04}}},
	"gel_body": {"name": "Gel Body", "from": ["bog_slime", "magma_slime"], "tier": 1, "color": Color("7ad0a0"),
		"text": "Blows sink in and lose their force.", "mods": {"damage_taken": {"percent": -0.06}}},
	"night_wings": {"name": "Night Wings", "from": ["carrion_bat", "storm_harpy", "pheasant"], "tier": 1, "color": Color("8a7aa8"),
		"text": "Light on your feet, and harder to catch.", "mods": {"move_speed": {"percent": 0.07}, "dodge_efficiency": {"flat": 0.05}}},
	"thorn_hide": {"name": "Thorn Hide", "from": ["thorn_stalker", "treant"], "tier": 1, "color": Color("6a8a44"),
		"text": "Bark and bramble under the skin.", "mods": {"armor": {"percent": 0.1}}},
	"spore_lungs": {"name": "Spore Lungs", "from": ["spore_shambler", "bog_lurker", "marsh_toad"], "tier": 1, "color": Color("a0b858"),
		"text": "You breathe what kills others.", "mods": {"poison_resist": {"flat": 0.3}, "poison_damage": {"flat": 2.0}}},
	"cult_whisper": {"name": "Cult Whisper", "from": ["rot_cultist"], "tier": 1, "color": Color("9a6ab8"),
		"text": "Words that were never meant for you.", "mods": {"magic_power": {"percent": 0.08}, "max_mana": {"flat": 10.0}}},
	"ember_heart": {"name": "Ember Heart", "from": ["ember_wisp", "cinder_imp", "magma_slime"], "tier": 1, "color": Color("f08a3a"),
		"text": "A coal that does not go out.", "mods": {"fire_damage": {"flat": 3.0}, "fire_resist": {"flat": 0.15}}},
	"ash_veil": {"name": "Ash Veil", "from": ["ash_wraith", "ghost"], "tier": 1, "color": Color("8a8a9a"),
		"text": "A little of the grey between worlds.", "mods": {"shadow_damage": {"flat": 3.0}, "shadow_resist": {"flat": 0.15}}},
	"stone_skin": {"name": "Stoneskin", "from": ["crag_golem", "frost_troll"], "tier": 1, "color": Color("9a968a"),
		"text": "Heavy and hard. A little slower.", "mods": {"armor": {"percent": 0.15}, "move_speed": {"percent": -0.03}}},
	"swift_hooves": {"name": "Swift Hooves", "from": ["deer", "mountain_goat", "wild_hare"], "tier": 1, "color": Color("c89a6a"),
		"text": "Legs made for running.", "mods": {"move_speed": {"percent": 0.06}, "max_stamina": {"flat": 10.0}}},
	"boar_charge": {"name": "Boar's Charge", "from": ["wild_pig", "dire_boar"], "tier": 1, "color": Color("a0705a"),
		"text": "Head down, straight through.", "mods": {"physical_damage": {"percent": 0.06}}},
	"bear_might": {"name": "Bear's Might", "from": ["bear"], "tier": 1, "color": Color("8a5a3a"),
		"text": "Bulk and a great deal of it.", "mods": {"max_health": {"percent": 0.08}, "physical_damage": {"percent": 0.04}}},
	"venom_fang": {"name": "Venom Fang", "from": ["giant_spider", "web_spider", "sand_scorpion", "desert_lizard"], "tier": 1, "color": Color("8ac048"),
		"text": "Every cut carries something extra.", "mods": {"poison_damage": {"flat": 3.0}, "critical_chance": {"flat": 0.02}}},
	"frost_blood": {"name": "Frost Blood", "from": ["frost_wolf", "frost_troll", "snow_fox"], "tier": 1, "color": Color("9ad8f0"),
		"text": "Cold runs in you and does not hurt.", "mods": {"frost_damage": {"flat": 3.0}, "frost_resist": {"flat": 0.15}}},
	"shell_guard": {"name": "Shell Guard", "from": ["shore_crab"], "tier": 1, "color": Color("f8906a"),
		"text": "A shell where it counts.", "mods": {"armor": {"percent": 0.08}, "elemental_resistance": {"flat": 0.04}}},
	"void_sight": {"name": "Void Sight", "from": ["void_stalker", "void_eye"], "tier": 1, "color": Color("9a6cf0"),
		"text": "You see where things are weakest.", "mods": {"critical_chance": {"flat": 0.05}, "critical_damage": {"flat": 0.1}}},
	"crimson_rage": {"name": "Crimson Rage", "from": ["crimson_fiend"], "tier": 1, "color": Color("d83a4c"),
		"text": "Hit harder; mind your guard less.", "mods": {"physical_damage": {"percent": 0.09}, "damage_taken": {"percent": 0.04}}},
	"heart_pulse": {"name": "Heart Pulse", "from": ["veinheart", "heartsworn_knight"], "tier": 1, "color": Color("e05a6a"),
		"text": "A second heartbeat under your own.", "mods": {"health_regen": {"flat": 1.2}, "life_steal": {"flat": 0.02}}},
	"hearth_calm": {"name": "Hearth Calm", "from": ["sheep", "cow", "chicken"], "tier": 1, "color": Color("f0e0b0"),
		"text": "Something gentle, that wants for little.", "mods": {"gold_find": {"flat": 0.08}, "health_regen": {"flat": 0.4}}},
	"court_poise": {"name": "Court Poise", "from": ["masked_noble"], "tier": 1, "color": Color("f4f0ea"),
		"text": "Tall, unhurried, and never where the blow falls.", "mods": {"dodge_efficiency": {"flat": 0.08}, "critical_damage": {"flat": 0.08}}},
	"keeper_vigil": {"name": "Keeper's Vigil", "from": ["matron"], "tier": 1, "color": Color("fff0c0"),
		"text": "She never slept. Neither, now, do you.", "mods": {"max_stamina": {"flat": 15.0}, "holy_damage": {"flat": 3.0}}},
	# --- fused
	"living_bulwark": {"name": "Living Bulwark", "tier": 2, "color": Color("b8d0a0"),
		"text": "Gel and stone together: blows land in you and stop.", "mods": {"armor": {"percent": 0.25}, "damage_taken": {"percent": -0.1}, "health_regen": {"flat": 1.0}}},
	"twin_tempest": {"name": "Twin Tempest", "tier": 2, "color": Color("c8a0f0"),
		"text": "Fire in one hand, frost in the other.", "mods": {"fire_damage": {"flat": 5.0}, "frost_damage": {"flat": 5.0}, "elemental_resistance": {"flat": 0.1}}},
	"hunters_rush": {"name": "Hunter's Rush", "tier": 2, "color": Color("e8a070"),
		"text": "The pack's run and the night's wings.", "mods": {"attack_speed": {"percent": 0.08}, "move_speed": {"percent": 0.1}, "dodge_efficiency": {"flat": 0.06}}},
	"plague_bearer": {"name": "Plague Bearer", "tier": 2, "color": Color("9ad048"),
		"text": "Poison is yours to give, and none of it to take.", "mods": {"poison_damage": {"flat": 7.0}, "poison_resist": {"flat": 0.5}}},
	"hollow_gaze": {"name": "Hollow Gaze", "tier": 2, "color": Color("7a5ab8"),
		"text": "The grey and the void, looking out through your eyes.", "mods": {"shadow_damage": {"flat": 6.0}, "critical_chance": {"flat": 0.07}}},
	"undying_heart": {"name": "Undying Heart", "tier": 2, "color": Color("e8707a"),
		"text": "The husk's grit and the heart's pulse. Very hard to stop.", "mods": {"max_health": {"percent": 0.14}, "health_regen": {"flat": 2.5}, "life_steal": {"flat": 0.02}}},
	"beastlord": {"name": "Beastlord's Strength", "tier": 2, "color": Color("b07a4a"),
		"text": "Bear and boar, both at once.", "mods": {"physical_damage": {"percent": 0.12}, "max_health": {"percent": 0.1}}},
	"pyre_litany": {"name": "Pyre Litany", "tier": 2, "color": Color("f06a4a"),
		"text": "The cult's words, spoken in flame.", "mods": {"magic_power": {"percent": 0.14}, "fire_damage": {"flat": 4.0}}},
	"promise_broken": {"name": "The Promise Broken", "tier": 2, "color": Color("f8e8c0"),
		"text": "The Court's poise and the Keeper's vigil, turned on them.", "mods": {"critical_damage": {"flat": 0.25}, "dodge_efficiency": {"flat": 0.1}, "xp_gain": {"flat": 0.05}}},
}
## [first, second, what they make].
const FUSIONS: Array[Array] = [
	["gel_body", "stone_skin", "living_bulwark"], ["ember_heart", "frost_blood", "twin_tempest"], ["pack_howl", "night_wings", "hunters_rush"],
	["venom_fang", "spore_lungs", "plague_bearer"], ["ash_veil", "void_sight", "hollow_gaze"], ["heart_pulse", "husk_grit", "undying_heart"],
	["bear_might", "boar_charge", "beastlord"], ["cult_whisper", "ember_heart", "pyre_litany"], ["court_poise", "keeper_vigil", "promise_broken"],
]

signal changed

var awake := false
var learned: Array = []
var worn: Array = []
## monster id -> devours of it that gave no Echo yet.
var hunger: Dictionary = {}
var devoured := 0

var _player: Player


func _ready() -> void:
	add_to_group("echoes")
	SaveGame.register("echoes", self)


func setup(player: Player) -> void:
	_player = player
	Events.enemy_killed.connect(_on_kill)
	Events.level_up.connect(_on_level_up)
	_on_level_up(player.leveling.level)
	_apply()


## The Echoes a monster carries.
static func of_monster(enemy_id: String) -> Array[String]:
	var out: Array[String] = []
	for id: String in LIST:
		if enemy_id in LIST[id].get("from", []):
			out.append(id)
	return out


## How many Echoes can be worn at once.
func slots() -> int:
	var count := 2 + mini(_player.leveling.level / 20, 4)
	# A slime is made for this: a slot more, and another once it has grown far.
	if _player.race() == "slime":
		count += 1 + (1 if _player.evolution_stage >= 3 else 0)
	return count


func _on_level_up(level: int) -> void:
	if awake or level < WAKE_LEVEL:
		return
	awake = true
	SaveGame.request_save()
	Voices.heart(get_tree(), "You have gained the gift: Devour.", "What falls near you leaves a remnant. Take it in, and take what it was.")
	Voices.inner(get_tree(), "Remnants linger where monsters fall. Interact with one to devour it.", "devour_wake")


## A monster fell: leave its remnant to be devoured.
func _on_kill(info: Dictionary) -> void:
	if not awake or not GameSettings.remnants or _player == null or _player.indoors and not Room.holds(info.get("position", Vector2.ZERO)):
		return
	var at: Vector2 = info.get("position", Vector2.INF)
	if at == Vector2.INF or at.distance_to(_player.global_position) > 900.0 or info.get("fragment", false):
		return
	var id := str(info.get("id", ""))
	if of_monster(id).is_empty():
		return
	var factions: Factions = get_tree().get_first_node_in_group("factions")
	if factions and factions.at_peace(Factions.of(id)):
		return
	var rank_index: int = maxi(["normal", "elite", "champion", "miniboss", "boss"].find(str(info.get("rank", "normal"))), 0)
	var remnant := Remnant.new()
	remnant.position = at
	remnant.setup(self, id, rank_index, str(info.get("name", id)), REMNANT_BIG_SECONDS if rank_index >= 3 else REMNANT_SECONDS)
	_player.get_parent().add_child(remnant)
	if devoured < 3:
		Voices.inner(get_tree(), "A remnant lingers. It can be devoured.", "remnant_%d" % devoured)


## Takes a remnant in: a little health back, and maybe one of its Echoes.
func devour(remnant: Remnant) -> void:
	if not is_instance_valid(remnant) or remnant.eaten:
		return
	remnant.eaten = true
	devoured += 1
	Events.codex_event.emit("devoured", 1)
	_player.health.heal(_player.health.max_health * (0.04 + 0.02 * remnant.rank_index))
	Audio.play_note("heartbeat", 0.7, -4.0)
	remnant.swallow(_player)
	var options := of_monster(remnant.monster).filter(func(id: String) -> bool: return not id in learned)
	if options.is_empty():
		DamageNumber.spawn_text(_player.get_parent(), _player.global_position + Vector2(0, -56), "Devoured", Color(0.75, 0.55, 0.9), 13)
		return
	var chance: float = LEARN_CHANCE[clampi(remnant.rank_index, 0, LEARN_CHANCE.size() - 1)]
	var sure_after := SURE_AFTER - (1 if _player.race() == "slime" else 0)
	if _player.race() == "slime":
		chance *= 1.8
	var tries := int(hunger.get(remnant.monster, 0))
	if randf() < chance or tries + 1 >= sure_after:
		hunger.erase(remnant.monster)
		learn(options.pick_random(), remnant.rank_index >= 3)
	else:
		hunger[remnant.monster] = tries + 1
		DamageNumber.spawn_text(_player.get_parent(), _player.global_position + Vector2(0, -56), "Devoured  (%d/%d)" % [tries + 1, sure_after], Color(0.75, 0.55, 0.9), 13)
		Voices.inner(get_tree(), "Not enough of it remained. Another %s, and its echo is yours." % remnant.title.to_lower(), "hunger_" + remnant.monster)
	SaveGame.request_save()


## Learns an Echo (worn at once if a slot is free).
func learn(id: String, announced: bool = false) -> void:
	if id in learned or not LIST.has(id):
		return
	learned.append(id)
	if worn.size() < slots():
		worn.append(id)
	_apply()
	var data: Dictionary = LIST[id]
	DamageNumber.spawn_text(_player.get_parent(), _player.global_position + Vector2(0, -60), "Echo: %s" % data["name"], data["color"], 15, true)
	RingBurst.spawn(_player.get_parent(), _player.global_position + Vector2(0, -16), data["color"], 70.0)
	Chronicle.say(get_tree(), "event", "", "Echo learned: %s. %s" % [data["name"], data["text"]])
	Events.codex_event.emit("echoes", 1)
	if announced or int(data["tier"]) >= 2:
		Voices.heart(get_tree(), "Echo acquired: %s." % data["name"], str(data["text"]))
	if not fusions_ready().is_empty():
		Voices.inner(get_tree(), "Two of your echoes could become one. Look to the Echoes screen.", "fusion_" + id)
	changed.emit()
	SaveGame.request_save()


## Puts an Echo on or takes it off. Returns "" or why not.
func toggle(id: String) -> String:
	if not id in learned:
		return "You have not learned that echo."
	if id in worn:
		worn.erase(id)
	elif worn.size() >= slots():
		return "Every echo slot is full (%d). Take one off first." % slots()
	else:
		worn.append(id)
	_apply()
	changed.emit()
	SaveGame.request_save()
	return ""


## The fusions open now: [[a, b, result], ...].
func fusions_ready() -> Array:
	return FUSIONS.filter(func(f: Array) -> bool: return f[0] in learned and f[1] in learned and not f[2] in learned)


## Fuses two Echoes into one, using both. Returns "" or why not.
func fuse(a: String, b: String) -> String:
	for fusion: Array in FUSIONS:
		if (fusion[0] == a and fusion[1] == b) or (fusion[0] == b and fusion[1] == a):
			if not (a in learned and b in learned):
				return "You need both echoes."
			if fusion[2] in learned:
				return "You already carry what they would make."
			learned.erase(a)
			learned.erase(b)
			var slot_freed := a in worn or b in worn
			worn.erase(a)
			worn.erase(b)
			Events.codex_event.emit("fusions", 1)
			learn(fusion[2], true)
			if slot_freed and not fusion[2] in worn and worn.size() < slots():
				worn.append(fusion[2])
				_apply()
			return ""
	return "Those two will not fuse."


## Every worn Echo's gifts, summed, on the player's stats.
func _apply() -> void:
	if _player == null:
		return
	while worn.size() > slots():
		worn.pop_back()
	var total := {}
	for id: String in worn:
		for stat: String in LIST[id]["mods"]:
			var into: Dictionary = total.get(stat, {})
			for kind: String in LIST[id]["mods"][stat]:
				into[kind] = float(into.get(kind, 0.0)) + float(LIST[id]["mods"][stat][kind])
			total[stat] = into
	_player.stats.set_modifiers("echoes", total)


func save_data() -> Dictionary:
	return {"awake": awake, "learned": learned, "worn": worn, "hunger": hunger, "devoured": devoured}


func load_data(data: Dictionary) -> void:
	awake = bool(data.get("awake", false))
	learned = (data.get("learned", []) as Array).filter(func(id: Variant) -> bool: return LIST.has(str(id))) if data.get("learned") is Array else []
	worn = (data.get("worn", []) as Array).filter(func(id: Variant) -> bool: return str(id) in learned) if data.get("worn") is Array else []
	hunger = data.get("hunger", {}) if data.get("hunger") is Dictionary else {}
	devoured = int(data.get("devoured", 0))
	_apply()


## What is left of a fallen monster for a few seconds: a dark pool with a
## wisp of violet motes turning up out of it, fading as its time runs out.
class Remnant:
	extends Prop

	var monster := ""
	var title := ""
	var rank_index := 0
	var eaten := false
	var _echoes: Echoes
	var _life := 9.0
	var _total := 9.0
	var _pulled := -1.0
	var _into: Node2D

	func setup(echoes: Echoes, monster_id: String, rank: int, monster_name: String, seconds: float) -> void:
		_echoes = echoes
		monster = monster_id
		rank_index = rank
		title = monster_name
		_life = seconds
		_total = seconds
		reach = 70.0
		prompt_text = "Devour the remnant of the %s" % monster_name
		on_interact = func(_p: Player) -> void: _echoes.devour(self)
		z_index = 0

	func swallow(into: Node2D) -> void:
		disarm()
		_into = into
		_pulled = 0.0

	func _process(delta: float) -> void:
		if _pulled >= 0.0:
			_pulled += delta * 2.2
			if _pulled >= 1.0 or not is_instance_valid(_into):
				queue_free()
		else:
			_life -= delta
			if _life <= 0.0:
				queue_free()
		queue_redraw()

	func _draw() -> void:
		var t := Time.get_ticks_msec() / 1000.0
		var fade := clampf(_life / 2.0, 0.0, 1.0) if _pulled < 0.0 else 1.0 - _pulled
		var big := 1.0 + 0.35 * rank_index
		# The pool: a dark, ragged ellipse, darker at its heart.
		for ring in 3:
			var rx := roundf((14.0 - ring * 4.0) * big)
			var ry := roundf(rx * 0.42)
			for y in range(-int(ry), int(ry) + 1):
				var half := floorf(rx * sqrt(maxf(1.0 - float(y * y) / maxf(ry * ry, 1.0), 0.0)))
				draw_rect(Rect2(-half, y, half * 2.0, 1.0), Color(0.12, 0.04, 0.16, (0.25 + ring * 0.2) * fade))
		# The wisp: motes turning upward in a spiral, violet to crimson.
		var count := int(10 * big)
		for k in count:
			var phase := fmod(t * 0.6 + float(k) / count, 1.0)
			var angle := k * 2.4 + t * 2.0
			var spot := Vector2(cos(angle) * (8.0 - phase * 5.0) * big, -phase * 34.0 * big + sin(angle) * 2.0)
			if _pulled >= 0.0 and is_instance_valid(_into):
				spot = spot.lerp(_into.global_position - global_position + Vector2(0, -20), _pulled)
			var colour := Color(0.62, 0.36, 0.95).lerp(Color(0.95, 0.3, 0.42), phase)
			draw_rect(Rect2(spot.round(), Vector2(2, 2)), Color(colour, (1.0 - phase) * fade))
			if k % 3 == 0:
				draw_rect(Rect2(spot.round() + Vector2(0, 2), Vector2(1, 1)), Color(colour.darkened(0.3), (1.0 - phase) * 0.6 * fade))
		# A faint eye of light at its heart, beating.
		var beat := 0.5 + 0.5 * maxf(sin(t * 6.0), 0.0)
		draw_rect(Rect2(-1, -3, 3, 2), Color(1.0, 0.75, 0.9, 0.5 * beat * fade))
