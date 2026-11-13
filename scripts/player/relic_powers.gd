class_name RelicPowers
extends RefCounted
## What each relic's ability does (see RelicDB). `power` grows with the
## relic's rarity. Each returns "" or why it could not be used.

const COLD := Color(0.6, 0.9, 1.0)
const FIRE := Color(1.0, 0.55, 0.2)
const HOLY := Color(1.0, 0.92, 0.6)
const VOID := Color(0.75, 0.5, 1.0)
const BLOOD := Color(0.95, 0.3, 0.35)


static func use(ability: String, player: Player, rarity: int) -> String:
	var power: float = RelicDB.RARITY_POWER[clampi(rarity, 0, 5)]
	var world := player.get_parent()
	var at := player.global_position
	match ability:
		"homeward":
			if player.state != Player.State.MOVE:
				return "Not now."
			RingBurst.spawn(world, at + Vector2(0, -14), HOLY, 70.0)
			world.call("send_home")
			RingBurst.spawn(world, player.global_position + Vector2(0, -14), HOLY, 70.0)
			Audio.play("level_up", -6.0, 0.1)
		"tidestride":
			player.buffs.add("tidestride", "Tidestride", 12.0, {"move_speed": {"percent": 0.1 * power}})
			player.surge(player.facing, 640.0, 0.3)
			Events.splash.emit(at)
		"flare":
			RingBurst.spawn(world, at + Vector2(0, -10), FIRE, 130.0)
			HitSpark.spawn(world, at + Vector2(0, -16), FIRE, true)
			var burned := player.strike_circle(at, 130.0, 2.6 * power, 340.0)
			for enemy in _enemies_near(player, at, 130.0):
				enemy.apply_status("burn", 4.0, player.stats.get_stat("physical_damage") * 0.35 * power)
			player.shake_camera(5.0)
			if burned == 0:
				Audio.play("swing", -6.0)
		"stillness":
			RingBurst.spawn(world, at + Vector2(0, -10), COLD, 210.0)
			for enemy in _enemies_near(player, at, 210.0):
				enemy.stun(2.4 + 0.4 * power)
				HitSpark.spawn(world, enemy.global_position + Vector2(0, -16), COLD)
		"transfusion":
			player.health.heal(player.health.max_health * minf(0.25 * power, 0.7))
			RingBurst.spawn(world, at + Vector2(0, -14), BLOOD, 60.0)
			DamageNumber.spawn_text(world, at + Vector2(0, -50), "Transfusion", BLOOD, 14)
		"gust":
			var direction := player.facing if player.facing != Vector2.ZERO else Vector2.RIGHT
			player.surge(direction, 820.0, 0.32)
			RingBurst.spawn(world, at + Vector2(0, -10), Color(0.85, 0.95, 1.0), 40.0)
		"bulwark":
			player.buffs.add("bulwark", "Bulwark", 6.0, {"damage_taken": {"percent": -minf(0.5 + 0.06 * power, 0.72)}})
			RingBurst.spawn(world, at + Vector2(0, -14), Color(0.8, 0.85, 0.95), 50.0)
		"blink":
			var target := player.get_global_mouse_position()
			var offset := (target - at).limit_length(260.0 + 30.0 * power)
			var landing := at + offset
			if not player.has_line_to(landing) or (player.indoors == false and _is_wall(player, landing)):
				return "Something is in the way."
			RingBurst.spawn(world, at + Vector2(0, -14), VOID, 40.0)
			player.global_position = landing
			RingBurst.spawn(world, landing + Vector2(0, -14), VOID, 40.0)
			Audio.play("swing", -4.0, 0.3)
		"fortune":
			player.buffs.add("fortune", "Fortune", 45.0, {"gold_find": {"flat": 0.8 + 0.2 * power}})
			HitSpark.spawn(world, at + Vector2(0, -30), HOLY, true)
		"thunder_call":
			var struck := 0
			for enemy in _enemies_near(player, at, 280.0):
				if struck >= 5:
					break
				struck += 1
				_bolt(world, enemy.global_position + Vector2(0, -14))
				player.hit_enemy(enemy, 2.2 * power, Vector2.ZERO)
			if struck == 0:
				return "Nothing to strike."
			player.shake_camera(4.0)
			Audio.play("thunder", -10.0, 0.1)
		"night_veil":
			player.buffs.add("night_veil", "Night Veil", 6.0, {"move_speed": {"percent": 0.15 + 0.05 * power}})
			for enemy in _enemies_near(player, at, 600.0):
				if enemy.rank < Enemy.Rank.BOSS:
					enemy.lose_track()
			RingBurst.spawn(world, at + Vector2(0, -14), Color(0.55, 0.55, 0.85), 60.0)
		"soul_harvest":
			var drained := 0
			for enemy in _enemies_near(player, at, 200.0):
				drained += 1
				player.hit_enemy(enemy, 1.2 * power, Vector2.ZERO)
				_bolt(world, enemy.global_position + Vector2(0, -14), at + Vector2(0, -14), Color(0.7, 0.45, 1.0))
			if drained == 0:
				return "No life to draw."
			player.health.heal(player.health.max_health * 0.05 * drained * power)
		_:
			return "Nothing happens."
	return ""


static func _enemies_near(player: Player, at: Vector2, radius: float) -> Array[Enemy]:
	var found: Array[Enemy] = []
	for node in player.get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy and enemy.state != Enemy.State.DEAD and enemy.global_position.distance_to(at) < radius:
			found.append(enemy)
	found.sort_custom(func(a: Enemy, b: Enemy) -> bool: return a.global_position.distance_squared_to(at) < b.global_position.distance_squared_to(at))
	return found


static func _is_wall(player: Player, at: Vector2) -> bool:
	var world: World = player.get_parent().get_node_or_null("World")
	return world != null and world.tile_type_at_position(at) == TerrainTiles.Type.WALL


## A jagged bolt of light, from the sky (or from `from`) to `to`.
static func _bolt(parent: Node, to: Vector2, from: Vector2 = Vector2.INF, color: Color = Color(1.0, 0.95, 0.6)) -> void:
	if from == Vector2.INF:
		from = to + Vector2(randf_range(-20, 20), -220)
	var line := Line2D.new()
	line.width = 4.0
	line.default_color = color
	line.z_index = 60
	line.add_point(from)
	for step in 5:
		var along := from.lerp(to, (step + 1) / 6.0)
		line.add_point(along + Vector2(randf_range(-10, 10), randf_range(-6, 6)))
	line.add_point(to)
	parent.add_child(line)
	var tween := line.create_tween()
	tween.tween_property(line, "width", 1.0, 0.25)
	tween.parallel().tween_property(line, "modulate:a", 0.0, 0.25)
	tween.tween_callback(line.queue_free)
	HitSpark.spawn(parent, to, color, true)
