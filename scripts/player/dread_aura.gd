class_name DreadAura
extends Node2D
## Your presence, let loose (the release_aura key, once the gift has woken
## at level WAKE_LEVEL): weaker monsters near you cower and back away, and
## will not strike while it lasts; wild animals bolt. Elites only cower if
## you far outclass them, and nothing great is moved by it. It burns mana
## while held, and drops when the mana is gone.
##
## Drawn round your feet: rings of dark pressure pulsing outward, pixel by
## pixel, and motes of shadow rising off you.

const WAKE_LEVEL := 10
const RADIUS := 290.0
## Mana a second it costs, and a little more as you grow.
const COST := 6.0
const COST_PER_LEVEL := 0.04

var active := false
var _player: Player
var _woken := false
var _t := 0.0
var _scared: Dictionary = {}


func _ready() -> void:
	z_index = -1
	SaveGame.register("dread_aura", self)


func setup(player: Player) -> void:
	_player = player
	Events.level_up.connect(_on_level_up)
	_on_level_up(player.leveling.level)


func _on_level_up(level: int) -> void:
	if _woken or level < WAKE_LEVEL:
		return
	_woken = true
	SaveGame.request_save()
	Voices.heart(get_tree(), "You have gained the gift: Dread Aura.", "Press %s to let your presence loose. Weaker things will not come near." % GameSettings.describe("release_aura"))


func woken() -> bool:
	return _woken


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("release_aura") or _player == null or _player.is_dead():
		return
	var menus: Node = _player.get_parent().get_node_or_null("Menus")
	if menus and menus.is_open():
		return
	get_viewport().set_input_as_handled()
	toggle()


func toggle() -> void:
	if not _woken:
		Voices.inner(get_tree(), "Your presence is not yet strong enough to frighten anything. (Level %d)" % WAKE_LEVEL, "aura_asleep")
		return
	if not active and _player.mana.current < 10.0:
		DamageNumber.spawn_text(_player.get_parent(), _player.global_position + Vector2(0, -60), "Not enough mana", UITheme.BAD, 13)
		return
	active = not active
	if active:
		RingBurst.spawn(_player.get_parent(), _player.global_position + Vector2(0, -10), Color(0.55, 0.2, 0.4), RADIUS * 0.6)
		_player.shake_camera(4.0)
		Audio.play_note("heartbeat", 0.6, -2.0)
		Events.codex_event.emit("auras", 1)
		Voices.inner(get_tree(), "Weaker things will not come near while your aura is out. It drains your mana.", "aura_first")
	queue_redraw()


func _physics_process(delta: float) -> void:
	_t += delta
	if not active or _player == null:
		if not _scared.is_empty():
			_scared.clear()
		return
	var cost := (COST + COST_PER_LEVEL * _player.leveling.level) * delta
	if _player.mana.current < cost or _player.is_dead():
		active = false
		DamageNumber.spawn_text(_player.get_parent(), _player.global_position + Vector2(0, -60), "Your aura fades", Color(0.8, 0.6, 0.9), 13)
		return
	_player.mana.current -= cost
	var level := _player.leveling.level
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.state == Enemy.State.DEAD or enemy.global_position.distance_to(_player.global_position) > RADIUS:
			continue
		if not _cowers(enemy, level):
			continue
		enemy.cowed = 0.6
		var key := enemy.get_instance_id()
		if not _scared.has(key):
			_scared[key] = true
			DamageNumber.spawn_text(enemy.get_parent(), enemy.global_position + Vector2(0, -30), "Cowers", Color(0.85, 0.7, 0.95), 12)
	queue_redraw()


## Whether a monster is weak enough to cower.
static func _cowers(enemy: Enemy, level: int) -> bool:
	if enemy.rank >= Enemy.Rank.MINIBOSS or enemy.boss_id != "" or enemy.named_id != "":
		return false
	if enemy.is_wild():
		return true
	match enemy.rank:
		Enemy.Rank.NORMAL:
			return enemy.level <= level
		Enemy.Rank.ELITE:
			return enemy.level <= level - 5
	return enemy.level <= level - 10


func _draw() -> void:
	if not active:
		return
	# Rings of pressure going out over the ground, one after another.
	draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.5))
	for k in 3:
		var phase := fmod(_t * 0.7 + k / 3.0, 1.0)
		var radius := roundf(24.0 + phase * (RADIUS - 24.0))
		var alpha := 0.32 * (1.0 - phase)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(0.45, 0.12, 0.32, alpha), 2.0)
		draw_arc(Vector2.ZERO, radius - 3.0, 0.0, TAU, 64, Color(0.08, 0.02, 0.06, alpha * 0.8), 1.0)
	draw_circle(Vector2.ZERO, 26.0, Color(0.1, 0.02, 0.08, 0.25))
	draw_set_transform(Vector2.ZERO)
	# Motes of shadow rising off you.
	for k in 14:
		var phase := fmod(_t * 0.45 + k / 14.0, 1.0)
		var spot := Vector2(roundf(sin(k * 2.3 + _t * 0.8) * (10.0 + k % 4 * 3.0)), roundf(-6.0 - phase * 56.0))
		var colour := Color(0.62, 0.18, 0.42).lerp(Color(0.12, 0.04, 0.1), phase)
		draw_rect(Rect2(spot, Vector2(2, 2) if k % 3 == 0 else Vector2(1, 2)), Color(colour, 0.85 * (1.0 - phase)))


func save_data() -> Dictionary:
	return {"woken": _woken}


func load_data(data: Dictionary) -> void:
	_woken = bool(data.get("woken", false))
