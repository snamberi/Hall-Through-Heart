class_name Pets
extends Node2D
## Tamed companions. Critters (rabbits, birds, butterflies, frogs) bring a
## small gift and fetch loot; monsters tamed when nearly beaten fight at
## your side. Pets grow with every monster you defeat.

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


func describe(pet: Dictionary) -> String:
	if pet["kind"] == "critter":
		return "Fetches loot. %s." % CRITTER_GIFTS.get(pet["species"], {}).get("text", "A loyal friend")
	return "Fights beside you for %d damage. Fetches loot." % roundi(damage(pet))


func _on_kill(info: Dictionary) -> void:
	var pet := current()
	if pet.is_empty() or int(pet["level"]) >= MAX_LEVEL:
		return
	pet["xp"] = int(pet["xp"]) + maxi(roundi(info.get("xp", 0) * 0.15), 1)
	while int(pet["xp"]) >= xp_to_next(pet) and int(pet["level"]) < MAX_LEVEL:
		pet["xp"] = int(pet["xp"]) - xp_to_next(pet)
		pet["level"] = int(pet["level"]) + 1
		DamageNumber.spawn_text(get_parent(), global_position + Vector2(0, -40), "%s reached level %d" % [pet["name"], pet["level"]], Color(0.6, 1.0, 0.6), 12)
	changed.emit()


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
		_critter.frame = Critter.KINDS.find(pet["species"]) * Critter.FRAMES
		_player.stats.set_modifiers("pet", CRITTER_GIFTS.get(pet["species"], {}).get("mods", {}))
	else:
		_critter.visible = false
		_sprite.visible = true
		_sprite.sprite_frames = SheetAnimations.build(EnemyDB.sheet(pet["species"]), 96, EnemyAnimator.ROWS)
		_sprite.scale = Vector2(0.6, 0.6)
		_sprite.position = Vector2(0, -14)
		_sprite.modulate = Color(0.85, 1.0, 0.85)
		_sprite.play("idle")


func _physics_process(delta: float) -> void:
	if _player == null or not visible:
		return
	if _player.is_dead():
		return
	var pet := current()
	# Follow a little behind and to the side.
	var spot := _player.global_position + Vector2(-34.0 * signf(_player.facing.x if _player.facing.x != 0.0 else 1.0), 10.0)
	if global_position.distance_to(_player.global_position) > 600.0:
		global_position = spot
	if _lunge == null or not _lunge.is_running():
		global_position = global_position.lerp(spot, clampf(4.0 * delta, 0.0, 1.0))
	var moving := global_position.distance_to(spot) > 6.0
	if pet["kind"] == "critter":
		_critter.frame = Critter.KINDS.find(pet["species"]) * Critter.FRAMES + (2 + int(Time.get_ticks_msec() / 160.0) % 2 if moving else 0)
		_critter.flip_h = spot.x < global_position.x
	else:
		var wanted := "walk" if moving else "idle"
		if _sprite.animation != wanted and (_lunge == null or not _lunge.is_running()):
			_sprite.play(wanted)
		_sprite.flip_h = spot.x < global_position.x
	_fetch()
	if pet["kind"] == "monster":
		_fight(pet, delta)


## Loot near the pet is carried to the player.
func _fetch() -> void:
	for node in get_tree().get_nodes_in_group("pickups"):
		if node is Node2D and node.global_position.distance_to(global_position) < FETCH_REACH:
			node.global_position = node.global_position.move_toward(_player.global_position, 8.0)


func _fight(pet: Dictionary, delta: float) -> void:
	_attack_left -= delta
	if _attack_left > 0.0:
		return
	var target: Enemy = null
	var best := 240.0
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy and not enemy.health.is_dead() and enemy.global_position.distance_to(_player.global_position) < best:
			best = enemy.global_position.distance_to(_player.global_position)
			target = enemy
	if target == null:
		return
	_attack_left = 1.3
	_sprite.play("lunge")
	var home := global_position
	_lunge = create_tween()
	_lunge.tween_property(self, "global_position", target.global_position + Vector2(0, 4), 0.14)
	_lunge.tween_callback(func() -> void:
		if is_instance_valid(target) and not target.health.is_dead():
			target.take_damage(damage(pet), (target.global_position - home).normalized() * 160.0)
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
