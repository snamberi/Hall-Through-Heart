class_name Transformations
extends Node
## Taking on the shape of a beast or a thing of legend, for a while.
##
## A meter fills over a minute, or faster in a fight (a dozen blows). When
## it is full, holding the transform key for four seconds changes the
## player into their chosen form: a new body, and great strength of that
## form's kind, until the time runs out. Forms unlock with level.

signal changed

const HOLD_SECONDS := 4.0
const CHARGE_SECONDS := 60.0
const CHARGE_HITS := 12
## "sheet" is a monster sheet in assets/sprites/enemies; "mods" are stat
## modifiers while transformed.
const FORMS := {
	"werewolf": {"name": "Werewolf", "level": 20, "sheet": "frost_wolf", "tint": Color(0.62, 0.52, 0.5), "scale": 1.45, "seconds": 30.0, "color": Color(0.85, 0.3, 0.25),
		"text": "A hunter on four legs: fast, savage, and fed by every wound it opens.",
		"mods": {"physical_damage": {"percent": 0.45}, "attack_speed": {"percent": 0.3}, "move_speed": {"percent": 0.25}, "life_steal": {"flat": 0.06}}},
	"golem": {"name": "Stone Golem", "level": 28, "sheet": "crag_golem", "tint": Color.WHITE, "scale": 1.35, "seconds": 35.0, "color": Color(0.7, 0.72, 0.8),
		"text": "Living rock. Blows that would fell a man barely chip it.",
		"mods": {"armor": {"percent": 1.2}, "max_health": {"percent": 0.5}, "damage_taken": {"percent": -0.3}, "physical_damage": {"percent": 0.2}, "move_speed": {"percent": -0.12}}},
	"harpy": {"name": "Storm Harpy", "level": 36, "sheet": "storm_harpy", "tint": Color.WHITE, "scale": 1.3, "seconds": 30.0, "color": Color(0.55, 0.8, 1.0),
		"text": "Wings and thunder: nothing on the ground can keep pace with it.",
		"mods": {"move_speed": {"percent": 0.5}, "attack_speed": {"percent": 0.35}, "dodge_efficiency": {"flat": 0.25}, "critical_chance": {"flat": 0.15}}},
	"wraith": {"name": "Ash Wraith", "level": 44, "sheet": "ash_wraith", "tint": Color.WHITE, "scale": 1.3, "seconds": 30.0, "color": Color(0.8, 0.85, 1.0),
		"text": "Half here and half elsewhere. Its touch is cold and its spells are terrible.",
		"mods": {"magic_power": {"percent": 0.7}, "shadow_damage": {"flat": 12.0}, "damage_taken": {"percent": -0.2}, "max_mana": {"percent": 0.5}}},
	"treant": {"name": "Elder Treant", "level": 52, "sheet": "treant", "tint": Color.WHITE, "scale": 1.5, "seconds": 40.0, "color": Color(0.5, 0.85, 0.4),
		"text": "Old as the forest and as hard to bring down. Its wounds close as you watch.",
		"mods": {"max_health": {"percent": 0.9}, "health_regen": {"flat": 12.0}, "armor": {"percent": 0.5}, "physical_damage": {"percent": 0.3}, "move_speed": {"percent": -0.15}}},
	"fiend": {"name": "Crimson Fiend", "level": 60, "sheet": "crimson_fiend", "tint": Color.WHITE, "scale": 1.4, "seconds": 30.0, "color": Color(1.0, 0.35, 0.25),
		"text": "Horned and burning. It feeds on what it kills.",
		"mods": {"physical_damage": {"percent": 0.6}, "fire_damage": {"flat": 18.0}, "life_steal": {"flat": 0.1}, "critical_damage": {"flat": 0.5}}},
	"troll": {"name": "Frost Troll", "level": 68, "sheet": "frost_troll", "tint": Color.WHITE, "scale": 1.45, "seconds": 35.0, "color": Color(0.6, 0.9, 1.0),
		"text": "A mountain of muscle and ice. Every blow lands like an avalanche.",
		"mods": {"physical_damage": {"percent": 0.8}, "max_health": {"percent": 0.6}, "frost_damage": {"flat": 20.0}, "attack_speed": {"percent": -0.1}}},
	"void": {"name": "Void Stalker", "level": 76, "sheet": "void_stalker", "tint": Color.WHITE, "scale": 1.4, "seconds": 30.0, "color": Color(0.75, 0.5, 1.0),
		"text": "A thing from between the stars. Fast, sharp, and never quite where it seems.",
		"mods": {"physical_damage": {"percent": 0.7}, "magic_power": {"percent": 0.7}, "attack_speed": {"percent": 0.3}, "move_speed": {"percent": 0.3}, "critical_chance": {"flat": 0.2}, "dodge_efficiency": {"flat": 0.3}}},
}

## The form the transform key takes; "" picks the strongest unlocked.
var chosen := ""
## 0 to 1: how full the meter is.
var charge := 0.0
## The form worn now, or "".
var active := ""
var time_left := 0.0
## Seconds the key has been held this time.
var hold := 0.0

var _player: Player
var _fx: TransformFX


func setup(player: Player) -> void:
	_player = player
	SaveGame.register("transformations", self)
	Events.damage_dealt.connect(func(_type: String, _amount: float) -> void:
		if active == "" and current() != "":
			charge = minf(charge + 1.0 / CHARGE_HITS, 1.0)
	)
	_player.died.connect(func(_xp: int) -> void:
		if active != "":
			revert()
		hold = 0.0
	)


func is_unlocked(id: String) -> bool:
	return _player.leveling.level >= int(FORMS[id]["level"])


## The form the key would take now: the chosen one, or the strongest
## unlocked; "" before any is unlocked.
func current() -> String:
	if chosen != "" and FORMS.has(chosen) and is_unlocked(chosen):
		return chosen
	var best := ""
	for id: String in FORMS:
		if is_unlocked(id):
			best = id
	return best


func choose(id: String) -> String:
	if not is_unlocked(id):
		return "Requires level %d." % FORMS[id]["level"]
	chosen = id
	changed.emit()
	SaveGame.request_save()
	return ""


## The level the first form unlocks at.
static func first_level() -> int:
	var lowest := 9999
	for id: String in FORMS:
		lowest = mini(lowest, int(FORMS[id]["level"]))
	return lowest


## True while the key is being held to transform: the player stands still.
func is_channeling() -> bool:
	return hold > 0.0 and active == ""


func can_transform() -> bool:
	return active == "" and charge >= 1.0 and current() != "" and not _player.is_dead() \
		and _player.state == Player.State.MOVE and not _player.swimming and not _player.boating and _player.mount_id == ""


func _physics_process(delta: float) -> void:
	if _player == null or _player.is_dead():
		return
	if active != "":
		time_left -= delta
		if time_left <= 0.0:
			revert()
		return
	if current() == "":
		return
	charge = minf(charge + delta / CHARGE_SECONDS, 1.0)
	if Input.is_action_pressed("transform") and can_transform() and not get_tree().paused:
		if hold == 0.0:
			_begin_channel()
		hold += delta
		_player.zoom_boost = 1.0 + 0.3 * ease(hold / HOLD_SECONDS, 0.6)
		if hold >= HOLD_SECONDS:
			transform(current())
	elif hold > 0.0:
		# Let go too soon: the gathering power drains away.
		hold = 0.0
		_player.zoom_boost = 1.0
		if is_instance_valid(_fx):
			_fx.cancel()
	if Input.is_action_just_pressed("transform") and not can_transform() and current() != "" and charge < 1.0:
		DamageNumber.spawn_text(_player.get_parent(), _player.global_position + Vector2(0, -50), "Not charged yet", UITheme.DIM, 12)


func _begin_channel() -> void:
	_fx = TransformFX.new()
	_fx.color = FORMS[current()]["color"]
	_fx.form = current()
	_fx.seconds = HOLD_SECONDS
	_player.add_child(_fx)
	Audio.play("transform", -4.0, 0.0)


## Changes shape at once (the key hold ends here).
func transform(id: String) -> void:
	var form: Dictionary = FORMS[id]
	active = id
	time_left = form["seconds"]
	charge = 0.0
	hold = 0.0
	_player.zoom_boost = 1.0
	if is_instance_valid(_fx):
		_fx.burst()
	_player.stats.set_modifiers("transformation", form["mods"])
	_player.health.heal(_player.health.max_health * 0.25)
	_player.set_form(id)
	# The change itself: a flash, a shockwave that throws back whatever is near.
	var world := _player.get_parent()
	RingBurst.spawn(world, _player.global_position, form["color"], 150.0)
	RingBurst.spawn(world, _player.global_position, Color.WHITE, 90.0)
	_player.shake_camera(12.0)
	_player.slow_motion(0.25, 0.35)
	var atmosphere: Atmosphere = world.get_node_or_null("Atmosphere")
	if atmosphere:
		atmosphere.flash(0.5)
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy and enemy.global_position.distance_to(_player.global_position) < 150.0 and not enemy.health.is_dead():
			enemy.take_damage(_player.stats.get_stat("physical_damage") * 1.5, _player.global_position.direction_to(enemy.global_position) * 420.0, false, "", "")
	Audio.play("level_up", -6.0, 0.0)
	Events.announcement.emit(str(form["name"]).to_upper(), "%d seconds" % roundi(form["seconds"]))
	Events.codex_event.emit("transformations", 1)
	changed.emit()


## Back to one's own shape.
func revert() -> void:
	if active == "":
		return
	var color: Color = FORMS[active]["color"]
	active = ""
	time_left = 0.0
	_player.stats.clear_modifiers("transformation")
	_player.set_form("")
	RingBurst.spawn(_player.get_parent(), _player.global_position, color, 70.0)
	Gore.spray(_player.get_parent(), _player.global_position, "_dust", Vector2.ZERO, 12, false)
	changed.emit()


func save_data() -> Dictionary:
	return {"chosen": chosen, "charge": charge}


func load_data(data: Dictionary) -> void:
	chosen = str(data.get("chosen", ""))
	if not FORMS.has(chosen):
		chosen = ""
	charge = clampf(float(data.get("charge", 0.0)), 0.0, 1.0)
