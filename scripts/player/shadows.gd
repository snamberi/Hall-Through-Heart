class_name Shadows
extends Node2D
## A Shade Sovereign's shadows (see ThePact). Where a monster has just
## fallen, the raise key (E) calls it back up as a shadow soldier: its own
## shape, black as a hole in the light, with violet eyes and dark smoke
## coming off it. The greater the monster, the harder it is to raise (three
## tries, then it will not rise). Shadows march with you and fall on what
## comes near; they cannot die, but a hard blow sends one back into your
## shadow for a while. The swap key (Y) trades places with the shadow
## nearest the pointer.

## Chance to raise, by rank.
const RAISE_CHANCE: Array[float] = [0.6, 0.45, 0.4, 0.3, 0.15]
## How much harder each rank hits.
const RANK_POWER: Array[float] = [1.0, 1.8, 2.4, 4.0, 6.0]
const RAISE_REACH := 150.0
const RAISE_SECONDS := 8.0
const SWAP_COOLDOWN := 6.0
const LEASH := 520.0

signal changed

## [{"id", "species", "rank", "name"}]
var soldiers: Array = []
var out := true
var raised := 0
var _next_id := 1
var _player: Player
var _pact: ThePact
## Fresh kills: [time, position, id, rank index, name, tries]
var _recent: Array = []
var _nodes: Dictionary = {}
var _swap_left := 0.0


func _ready() -> void:
	add_to_group("shadows")
	SaveGame.register("shadows", self)


func setup(player: Player, pact: ThePact) -> void:
	_player = player
	_pact = pact
	Events.enemy_killed.connect(_on_kill)


func can_raise() -> bool:
	return _pact != null and _pact.job == "shade_sovereign"


func capacity() -> int:
	return mini(3 + _player.leveling.level / 15, 16)


func _on_kill(info: Dictionary) -> void:
	if not can_raise() or info.get("fragment", false):
		return
	var id := str(info.get("id", ""))
	if not EnemyDB.ENEMIES.has(id) or EnemyDB.ENEMIES[id].has("wild"):
		return
	var rank_index: int = maxi(["normal", "elite", "champion", "miniboss", "boss"].find(str(info.get("rank", "normal"))), 0)
	_recent.append([Time.get_ticks_msec() / 1000.0, info.get("position", Vector2.ZERO), id, rank_index, str(info.get("name", id)), 0])
	while _recent.size() > 12:
		_recent.pop_front()
	if raised == 0:
		Voices.inner(get_tree(), "It can still rise. Press %s by its body." % GameSettings.describe("raise_shadow"), "arise_hint")


func _unhandled_input(event: InputEvent) -> void:
	if _player == null or _player.is_dead():
		return
	var menus: Node = _player.get_parent().get_node_or_null("Menus")
	if menus and menus.is_open():
		return
	if event.is_action_pressed("raise_shadow") and can_raise():
		get_viewport().set_input_as_handled()
		raise_nearest()
	elif event.is_action_pressed("shadow_swap") and can_raise():
		get_viewport().set_input_as_handled()
		swap()


## Calls the nearest fresh fallen up as a shadow. Returns "" or why not.
func raise_nearest() -> String:
	var now := Time.get_ticks_msec() / 1000.0
	_recent = _recent.filter(func(r: Array) -> bool: return now - float(r[0]) < RAISE_SECONDS and int(r[5]) < 3)
	var best: Array = []
	var best_distance := RAISE_REACH
	for record: Array in _recent:
		var distance := (record[1] as Vector2).distance_to(_player.global_position)
		if distance < best_distance:
			best_distance = distance
			best = record
	if best.is_empty():
		return "Nothing fallen near enough to raise."
	if soldiers.size() >= capacity():
		DamageNumber.spawn_text(_player.get_parent(), _player.global_position + Vector2(0, -60), "Your shadow is full (%d)" % capacity(), UITheme.BAD, 13)
		return "full"
	var at: Vector2 = best[1]
	if randf() < RAISE_CHANCE[clampi(int(best[3]), 0, 4)]:
		_recent.erase(best)
		var soldier := {"id": _next_id, "species": best[2], "rank": best[3], "name": "Shadow %s" % best[4]}
		_next_id += 1
		soldiers.append(soldier)
		raised += 1
		Events.codex_event.emit("shadows", 1)
		DamageNumber.spawn_text(_player.get_parent(), at + Vector2(0, -50), "ARISE", Color(0.75, 0.55, 1.0), 20, true)
		RingBurst.spawn(_player.get_parent(), at, Color(0.45, 0.25, 0.75), 90.0)
		LightPillar.spawn(_player.get_parent(), at, Color(0.4, 0.2, 0.7))
		_player.shake_camera(5.0)
		if int(best[3]) >= 3:
			Voices.heart(get_tree(), "%s rises for you." % soldier["name"], "A great shadow.")
		_spawn_node(soldier, at)
		changed.emit()
		SaveGame.request_save()
		return ""
	best[5] = int(best[5]) + 1
	DamageNumber.spawn_text(_player.get_parent(), at + Vector2(0, -40), "It resists (%d/3)" % best[5] if int(best[5]) < 3 else "It will not rise", Color(0.7, 0.6, 0.85), 13)
	return "resisted"


func dismiss(index: int) -> void:
	if index < 0 or index >= soldiers.size():
		return
	var key := int(soldiers[index]["id"])
	if is_instance_valid(_nodes.get(key)):
		(_nodes[key] as Node).queue_free()
	_nodes.erase(key)
	soldiers.remove_at(index)
	changed.emit()
	SaveGame.request_save()


func set_out(value: bool) -> void:
	out = value
	if not out:
		for node: Variant in _nodes.values():
			if is_instance_valid(node):
				(node as Node).queue_free()
		_nodes.clear()
	changed.emit()
	SaveGame.request_save()


## Trades places with the shadow nearest the pointer.
func swap() -> String:
	if _swap_left > 0.0:
		return "Not yet."
	var pointer := _player.get_global_mouse_position()
	var best: ShadowSoldier = null
	var best_distance := INF
	for node: Variant in _nodes.values():
		if is_instance_valid(node) and (node as ShadowSoldier).down <= 0.0:
			var distance := (node as Node2D).global_position.distance_to(pointer)
			if distance < best_distance:
				best_distance = distance
				best = node
	if best == null:
		return "No shadow to swap with."
	var mine := _player.global_position
	RingBurst.spawn(_player.get_parent(), mine, Color(0.45, 0.25, 0.75), 60.0)
	RingBurst.spawn(_player.get_parent(), best.global_position, Color(0.45, 0.25, 0.75), 60.0)
	_player.global_position = best.global_position
	best.global_position = mine
	_player.camera.reset_smoothing()
	_swap_left = SWAP_COOLDOWN
	Events.codex_event.emit("swaps", 1)
	return ""


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	_swap_left = maxf(_swap_left - delta, 0.0)
	if not out or not can_raise():
		return
	# Shadows follow you; those far behind (a door, a gate) catch up.
	for index in soldiers.size():
		var soldier: Dictionary = soldiers[index]
		var key := int(soldier["id"])
		var node: Variant = _nodes.get(key)
		if not is_instance_valid(node):
			_spawn_node(soldier, _player.global_position + Vector2.from_angle(TAU * index / maxf(soldiers.size(), 1.0)) * 50.0)
		elif (node as Node2D).global_position.distance_to(_player.global_position) > 1400.0:
			(node as Node2D).global_position = _player.global_position + Vector2.from_angle(randf() * TAU) * 60.0


func _spawn_node(soldier: Dictionary, at: Vector2) -> void:
	if not out:
		return
	var node := ShadowSoldier.new()
	node.setup(self, soldier, soldiers.find(soldier))
	node.position = at
	_player.get_parent().add_child(node)
	_nodes[int(soldier["id"])] = node


func damage_of(soldier: Dictionary) -> float:
	return (8.0 + 3.0 * _player.leveling.level) * RANK_POWER[clampi(int(soldier["rank"]), 0, 4)]


func save_data() -> Dictionary:
	return {"soldiers": soldiers.duplicate(true), "out": out, "raised": raised, "next_id": _next_id}


func load_data(data: Dictionary) -> void:
	soldiers.clear()
	for saved: Variant in data.get("soldiers", []):
		if saved is Dictionary and EnemyDB.ENEMIES.has(str(saved.get("species", ""))):
			soldiers.append(saved)
	out = bool(data.get("out", true))
	raised = int(data.get("raised", 0))
	_next_id = int(data.get("next_id", soldiers.size() + 1))
	for node: Variant in _nodes.values():
		if is_instance_valid(node):
			(node as Node).queue_free()
	_nodes.clear()


## A shadow soldier: the monster's own figure gone black, violet eyes, dark
## smoke rising off it. It keeps a place in a ring round you, and runs at
## whatever comes near to strike it.
class ShadowSoldier:
	extends Node2D

	var data: Dictionary
	var down := 0.0
	var _shadows: Shadows
	var _place := 0
	var _sprite: AnimatedSprite2D
	var _strike_left := 0.0
	var _target: Enemy = null
	var _hits_taken := 0

	func setup(shadows: Shadows, soldier: Dictionary, place: int) -> void:
		_shadows = shadows
		data = soldier
		_place = place

	func _ready() -> void:
		_sprite = AnimatedSprite2D.new()
		_sprite.sprite_frames = SheetAnimations.build(EnemyDB.sheet(str(data["species"])), 96, EnemyAnimator.ROWS)
		_sprite.position = Vector2(0, -23)
		_sprite.modulate = Color(0.16, 0.12, 0.24)
		_sprite.play("idle")
		add_child(_sprite)
		RingBurst.spawn(get_parent(), global_position, Color(0.45, 0.25, 0.75), 40.0)

	func _physics_process(delta: float) -> void:
		var player := _shadows._player
		if player == null:
			return
		down = maxf(down - delta, 0.0)
		visible = down <= 0.0
		if down > 0.0:
			global_position = player.global_position
			return
		_strike_left -= delta
		# Find something to fight near the player.
		if _target == null or not is_instance_valid(_target) or _target.state == Enemy.State.DEAD or _target.global_position.distance_to(player.global_position) > Shadows.LEASH:
			_target = null
			var best := 380.0
			for node in get_tree().get_nodes_in_group("enemies"):
				var enemy := node as Enemy
				if enemy == null or enemy.state == Enemy.State.DEAD or enemy.is_wild():
					continue
				var distance := enemy.global_position.distance_to(player.global_position)
				if distance < best:
					best = distance
					_target = enemy
		var goal := player.global_position + Vector2.from_angle(TAU * _place / maxf(_shadows.soldiers.size(), 1.0) + 0.4) * (46.0 + 10.0 * (_place % 3))
		if _target:
			goal = _target.global_position + (global_position - _target.global_position).normalized() * (_target.body_radius + 14.0)
		var way := goal - global_position
		var speed := 230.0 if _target else 200.0
		if way.length() > 6.0:
			global_position += way.normalized() * minf(way.length(), speed * delta)
			_sprite.flip_h = way.x < 0.0
			if _sprite.animation != "walk" and _sprite.sprite_frames.has_animation("walk"):
				_sprite.play("walk")
		elif _sprite.animation != "idle":
			_sprite.play("idle")
		if _target and _strike_left <= 0.0 and global_position.distance_to(_target.global_position) < _target.body_radius + 30.0:
			_strike_left = 1.1
			var dealt := _target.take_damage(_shadows.damage_of(data), (_target.global_position - global_position).normalized() * 140.0)
			HitSpark.spawn(get_parent(), _target.global_position + Vector2(0, -16), Color(0.6, 0.4, 0.95), false)
			if dealt > 0.0 and _target.state != Enemy.State.DEAD and randf() < 0.12:
				# Struck back hard: back into your shadow for a while.
				_hits_taken += 1
				if _hits_taken >= 3:
					_hits_taken = 0
					down = 12.0
					RingBurst.spawn(get_parent(), global_position, Color(0.3, 0.15, 0.5), 40.0)
		queue_redraw()

	func _draw() -> void:
		if down > 0.0:
			return
		var t := Time.get_ticks_msec() / 1000.0
		draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, 14.0, Color(0.1, 0.02, 0.18, 0.45))
		draw_set_transform(Vector2.ZERO)
		# Smoke rising off it.
		for k in 8:
			var phase := fmod(t * 0.6 + k / 8.0, 1.0)
			var spot := Vector2(roundf(sin(k * 2.7 + t) * 10.0), roundf(-8.0 - phase * 50.0))
			draw_rect(Rect2(spot, Vector2(2, 2)), Color(0.22, 0.1, 0.34, 0.7 * (1.0 - phase)))
		# Violet eyes where its head is.
		var head := Vector2(-3 if _sprite.flip_h else 3, -38)
		var glow := 0.75 + 0.25 * sin(t * 4.0)
		draw_rect(Rect2(head + Vector2(-2, 0), Vector2(2, 1)), Color(0.8, 0.55, 1.0, glow))
		draw_rect(Rect2(head + Vector2(2, 0), Vector2(2, 1)), Color(0.8, 0.55, 1.0, glow))
