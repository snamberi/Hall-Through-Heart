class_name Pets
extends Node2D
## Tamed companions. Critters (rabbits, birds, butterflies, frogs) bring a
## gift that grows as they do; monsters tamed when nearly beaten fight at
## your side. A pet trots at its own pace beside you, noses about when you
## stand still, runs to fetch what falls, and can be fed to grow faster.
## Pets grow with every monster you defeat.

const CRITTER_GIFTS := {
	"rabbit": {"text": "+6% movement speed", "mods": {"move_speed": {"percent": 0.06}}},
	"bird": {"text": "+8% magic find", "mods": {"magic_find": {"flat": 0.08}}},
	"butterfly": {"text": "+20% mana regeneration", "mods": {"mana_regen": {"percent": 0.2}}},
	"frog": {"text": "+0.6 health per second", "mods": {"health_regen": {"flat": 0.6}}},
}
const MAX_PETS := 8
const MAX_LEVEL := 50
## A monster this hurt (share of health) can be tamed.
const TAME_HEALTH := 0.3
const FETCH_REACH := 180.0
## How much stronger a critter's gift is at the top level.
const GIFT_GROWTH := 1.5

signal changed

## [{"id", "species", "kind": "critter"|"monster", "name", "level", "xp"}]
var pets: Array = []
var active := -1

var _player: Player
var _sprite: AnimatedSprite2D
var _critter: Sprite2D
var _next_id := 1
var _attack_left := 1.0
var _lunge: Tween
var _velocity := Vector2.ZERO
## Where the pet is pottering to while the player stands still.
var _wander := Vector2.ZERO
var _wander_left := 0.0
var _hearts: Array = []
var _bob := 0.0


func _ready() -> void:
	SaveGame.register("pets", self)
	z_index = 0


func setup(player: Player) -> void:
	_player = player
	_sprite = AnimatedSprite2D.new()
	add_child(_sprite)
	_critter = Sprite2D.new()
	_critter.texture = Critter.SHEET
	_critter.hframes = Critter.KINDS.size() * Critter.FRAMES
	add_child(_critter)
	Events.enemy_killed.connect(_on_kill)
	_refresh_look()


func current() -> Dictionary:
	return pets[active] if active >= 0 and active < pets.size() else {}


## Tries to tame something near the player with a treat. Returns "" or why not.
func tame(player: Player) -> String:
	if pets.size() >= MAX_PETS:
		return "You have as many pets as you can keep."
	for node in get_tree().get_nodes_in_group("critters"):
		if node.global_position.distance_to(player.global_position) < 90.0:
			var species: String = node.kind
			node.queue_free()
			return _adopt(species, "critter", species.capitalize())
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy and enemy.rank == Enemy.Rank.NORMAL and not enemy.health.is_dead() and enemy.boss_id == "" \
				and enemy.global_position.distance_to(player.global_position) < 100.0 and enemy.health.current <= enemy.health.max_health * TAME_HEALTH:
			var species := enemy.enemy_id
			RingBurst.spawn(enemy.get_parent(), enemy.global_position + Vector2(0, -14), Color(0.6, 1.0, 0.6), 50.0)
			enemy.remove_from_group("enemies")
			enemy.queue_free()
			return _adopt(species, "monster", EnemyDB.ENEMIES[species]["name"])
	return "Hold out the treat beside a small creature, or a monster beaten to its last legs."


func _adopt(species: String, kind: String, name: Variant) -> String:
	var pet := {"id": _next_id, "species": species, "kind": kind, "name": str(name), "level": 1, "xp": 0}
	_next_id += 1
	pets.append(pet)
	active = pets.size() - 1
	Events.announcement.emit("TAMED", "%s will follow you now" % pet["name"])
	Events.codex_event.emit("pets", 1)
	_refresh_look()
	changed.emit()
	SaveGame.request_save()
	return ""


func set_active(index: int) -> void:
	active = index if index >= 0 and index < pets.size() else -1
	_refresh_look()
	changed.emit()
	SaveGame.request_save()


func rename(index: int, new_name: String) -> void:
	if index >= 0 and index < pets.size() and new_name.strip_edges() != "":
		pets[index]["name"] = new_name.strip_edges().left(20)
		changed.emit()
		SaveGame.request_save()


func release(index: int) -> void:
	if index < 0 or index >= pets.size():
		return
	pets.remove_at(index)
	if active >= pets.size():
		active = pets.size() - 1
	_refresh_look()
	changed.emit()
	SaveGame.request_save()


func damage(pet: Dictionary) -> float:
	return (6.0 + 2.5 * int(pet["level"])) * (1.0 + 0.04 * _player.leveling.level)


func xp_to_next(pet: Dictionary) -> int:
	return 40 * int(pet["level"]) + 20


## How much a critter's gift is multiplied by at its level.
func gift_scale(pet: Dictionary) -> float:
	return 1.0 + GIFT_GROWTH * (int(pet["level"]) - 1) / float(MAX_LEVEL - 1)


## A critter's gift as stat modifiers, grown with its level.
func gift_mods(pet: Dictionary) -> Dictionary:
	var result := {}
	var base: Dictionary = CRITTER_GIFTS.get(pet["species"], {}).get("mods", {})
	for stat: String in base:
		result[stat] = {}
		for kind: String in base[stat]:
			result[stat][kind] = base[stat][kind] * gift_scale(pet)
	return result


func describe(pet: Dictionary) -> String:
	if pet["kind"] == "critter":
		var parts: PackedStringArray = []
		var mods := gift_mods(pet)
		for stat: String in mods:
			for kind: String in mods[stat]:
				parts.append(ItemDB.describe_modifier({"stat": stat, "kind": kind, "value": mods[stat][kind]}))
		return "Fetches loot. %s (grows with its level)." % ", ".join(parts)
	return "Fights beside you for %d damage, with a chance to strike twice as hard. Fetches loot." % roundi(damage(pet))


## Feeds a pet the plainest food in the bag, for experience. Returns "" or why not.
func feed(index: int) -> String:
	if index < 0 or index >= pets.size():
		return ""
	var pet: Dictionary = pets[index]
	if int(pet["level"]) >= MAX_LEVEL:
		return "%s is fully grown." % pet["name"]
	var meal: Item = null
	for item in _player.inventory.items:
		var use: Dictionary = item.definition().get("use", {})
		if use.get("buff", "") == "food" or item.id.begins_with("raw_") or item.id == "taming_treat":
			if meal == null or item.value() < meal.value():
				meal = item
	if meal == null:
		return "Nothing in the bag a pet would eat. Cooked food and raw meat will do."
	var worth := 20 + meal.value() * 2
	_player.inventory.take(meal.id, 1)
	_gain(pet, worth)
	if index == active:
		_hearts.append([Vector2(randf_range(-6, 6), -26), 0.0])
		_hearts.append([Vector2(randf_range(-10, 10), -20), -0.2])
	Audio.play("pickup", -8.0, 0.2)
	changed.emit()
	SaveGame.request_save()
	return ""


func _on_kill(info: Dictionary) -> void:
	var pet := current()
	if pet.is_empty() or int(pet["level"]) >= MAX_LEVEL:
		return
	_gain(pet, maxi(roundi(info.get("xp", 0) * 0.15), 1))
	changed.emit()


func _gain(pet: Dictionary, amount: int) -> void:
	pet["xp"] = int(pet["xp"]) + amount
	var grew := false
	while int(pet["xp"]) >= xp_to_next(pet) and int(pet["level"]) < MAX_LEVEL:
		pet["xp"] = int(pet["xp"]) - xp_to_next(pet)
		pet["level"] = int(pet["level"]) + 1
		grew = true
	if grew:
		if pet == current():
			DamageNumber.spawn_text(get_parent(), global_position + Vector2(0, -40), "%s reached level %d" % [pet["name"], pet["level"]], Color(0.6, 1.0, 0.6), 12)
			RingBurst.spawn(get_parent(), global_position, Color(0.6, 1.0, 0.6), 44.0)
			_hearts.append([Vector2(0, -28), 0.0])
		_refresh_look()


func _refresh_look() -> void:
	if _player == null:
		return
	var pet := current()
	visible = not pet.is_empty()
	_player.stats.clear_modifiers("pet")
	if pet.is_empty():
		return
	if pet["kind"] == "critter":
		_sprite.visible = false
		_critter.visible = true
		_critter.scale = Vector2(1.35, 1.35)
		_critter.frame = Critter.KINDS.find(pet["species"]) * Critter.FRAMES
		_player.stats.set_modifiers("pet", gift_mods(pet))
	else:
		_critter.visible = false
		_sprite.visible = true
		_sprite.sprite_frames = SheetAnimations.build(EnemyDB.sheet(pet["species"]), 96, EnemyAnimator.ROWS)
		# A tamed monster is smaller than its wild kin, and grows a little with level.
		var size := (0.58 + 0.14 * int(pet["level"]) / float(MAX_LEVEL)) * float(EnemyDB.ENEMIES[pet["species"]].get("size", 1.0))
		_sprite.scale = Vector2(size, size)
		_sprite.position = Vector2(0, -23.0 * size)
		_sprite.modulate = Color.WHITE
		_sprite.play("idle")
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	_bob += delta
	for heart: Array in _hearts:
		heart[1] += delta
	_hearts = _hearts.filter(func(h: Array) -> bool: return h[1] < 1.1)
	queue_redraw()


## The marks of a friend: a soft ring underfoot so it is never mistaken for
## a wild thing, its name and level, and hearts when it is happy.
func _draw() -> void:
	var pet := current()
	if pet.is_empty():
		return
	draw_set_transform(Vector2(0, 1), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 13.0, Color(0, 0, 0, 0.22))
	draw_arc(Vector2.ZERO, 15.0, 0.0, TAU, 28, Color(0.55, 1.0, 0.6, 0.55 + 0.15 * sin(_bob * 3.0)), 1.5)
	draw_set_transform(Vector2.ZERO)
	var font := UITheme.get_theme().default_font
	var top := -34.0 if pet["kind"] == "critter" else -52.0 * _sprite.scale.y - 8.0
	var label := "%s  %d" % [pet["name"], pet["level"]]
	draw_string_outline(font, Vector2(-60, top), label, HORIZONTAL_ALIGNMENT_CENTER, 120.0, 13, 3, Color(0, 0, 0, 0.8))
	draw_string(font, Vector2(-60, top), label, HORIZONTAL_ALIGNMENT_CENTER, 120.0, 13, Color(0.7, 1.0, 0.72))
	for heart: Array in _hearts:
		if heart[1] < 0.0:
			continue
		var share: float = heart[1] / 1.1
		var at: Vector2 = heart[0] + Vector2(sin(share * 6.0) * 3.0, -share * 22.0)
		var color := Color(1.0, 0.45, 0.55, 1.0 - share)
		draw_circle(at + Vector2(-2, 0), 2.6, color)
		draw_circle(at + Vector2(2, 0), 2.6, color)
		draw_colored_polygon(PackedVector2Array([at + Vector2(-4.4, 1), at + Vector2(4.4, 1), at + Vector2(0, 6)]), color)


func _physics_process(delta: float) -> void:
	if _player == null or not visible:
		return
	if _player.is_dead():
		return
	var pet := current()
	var lunging := _lunge != null and _lunge.is_running()
	var away := global_position.distance_to(_player.global_position)
	if away > 600.0:
		# Left far behind (a waystone, a cave mouth): catch up at once.
		global_position = _player.global_position + Vector2(-30, 10)
		_velocity = Vector2.ZERO
	# Where to be: by the player's side when they move; pottering about
	# when they stand; at the nearest thing dropped, to bring it back.
	var resting := _player.velocity.length() < 10.0
	var goal := _player.global_position + Vector2(-34.0 * signf(_player.facing.x if _player.facing.x != 0.0 else 1.0), 12.0)
	var fetching := _fetch_goal()
	if fetching != Vector2.INF:
		goal = fetching
	elif resting:
		_wander_left -= delta
		if _wander_left <= 0.0:
			_wander_left = randf_range(1.5, 4.0)
			_wander = Vector2.from_angle(randf() * TAU) * randf_range(20.0, 70.0) if randf() < 0.7 else Vector2(-30, 12)
			# Now and then, a happy thought.
			if randf() < 0.15:
				_hearts.append([Vector2(0, -26), 0.0])
		goal = _player.global_position + _wander
	if not lunging:
		var to_goal := goal - global_position
		var distance := to_goal.length()
		# Its own legs: faster the further behind, never snapping to the spot.
		var top_speed := 150.0 + minf(distance, 300.0) * 1.3
		var wanted := to_goal.normalized() * minf(top_speed, distance * 5.0) if distance > 5.0 else Vector2.ZERO
		_velocity = _velocity.move_toward(wanted, 900.0 * delta)
		global_position += _velocity * delta
	var moving := _velocity.length() > 14.0 and not lunging
	if pet["kind"] == "critter":
		var base := Critter.KINDS.find(pet["species"]) * Critter.FRAMES
		var hop := sin(_bob * 11.0)
		if moving:
			_critter.frame = base + (2 if cos(_bob * 11.0) * signf(hop) > 0.0 else 3)
			_critter.position.y = -10.0 - absf(hop) * 5.0
		else:
			_critter.frame = base + (1 if fmod(_bob, 2.6) < 0.35 else 0)
			_critter.position.y = -10.0
		if absf(_velocity.x) > 4.0:
			_critter.flip_h = _velocity.x < 0.0
	else:
		var wanted := "walk" if moving else "idle"
		if _sprite.animation != wanted and not lunging:
			_sprite.play(wanted)
		if absf(_velocity.x) > 4.0 and not lunging:
			_sprite.flip_h = _velocity.x < 0.0
	_fetch()
	if pet["kind"] == "monster":
		_fight(pet, delta)


## Where the nearest dropped thing lies, if the pet should run to it.
func _fetch_goal() -> Vector2:
	var best := Vector2.INF
	var best_distance := FETCH_REACH
	for node in get_tree().get_nodes_in_group("pickups"):
		if node is Node2D:
			var distance: float = node.global_position.distance_to(_player.global_position)
			if distance < best_distance and distance > 30.0:
				best_distance = distance
				best = node.global_position
	return best


## Loot the pet reaches is carried back to the player.
func _fetch() -> void:
	for node in get_tree().get_nodes_in_group("pickups"):
		if node is Node2D and node.global_position.distance_to(global_position) < 46.0:
			node.global_position = node.global_position.move_toward(_player.global_position, 9.0)


func _fight(pet: Dictionary, delta: float) -> void:
	_attack_left -= delta
	if _attack_left > 0.0:
		return
	var target: Enemy = null
	var best := 240.0
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy and not enemy.health.is_dead() and not enemy.is_wild() and enemy.global_position.distance_to(_player.global_position) < best:
			best = enemy.global_position.distance_to(_player.global_position)
			target = enemy
	if target == null:
		return
	# Older pets strike faster.
	_attack_left = 1.3 - 0.5 * int(pet["level"]) / float(MAX_LEVEL)
	_sprite.play("lunge")
	_sprite.flip_h = target.global_position.x < global_position.x
	var home := global_position
	_lunge = create_tween()
	_lunge.tween_property(self, "global_position", target.global_position + Vector2(0, 4), 0.14)
	_lunge.tween_callback(func() -> void:
		if is_instance_valid(target) and not target.health.is_dead():
			var savage := randf() < 0.15
			target.take_damage(damage(pet) * (2.0 if savage else 1.0), (target.global_position - home).normalized() * 160.0, savage)
	)
	_lunge.tween_property(self, "global_position", home, 0.18)


func save_data() -> Dictionary:
	return {"pets": pets.duplicate(true), "active": active, "next_id": _next_id}


func load_data(data: Dictionary) -> void:
	pets.clear()
	for saved: Variant in data.get("pets", []):
		if saved is Dictionary and (Critter.KINDS.has(saved.get("species", "")) or EnemyDB.ENEMIES.has(saved.get("species", ""))):
			pets.append(saved)
	active = clampi(int(data.get("active", -1)), -1, pets.size() - 1)
	_next_id = int(data.get("next_id", pets.size() + 1))
	_refresh_look()
