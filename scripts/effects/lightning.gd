class_name Lightning
extends Node2D
## A lightning strike: a warning ring on the ground, then the bolt, a flash,
## and harm to anyone standing in it.

const RADIUS := 60.0
const WARNING := 0.9

var _player: Player
var _atmosphere: Atmosphere
var _time := 0.0
var _struck := false
var _bolt: PackedVector2Array


static func strike(parent: Node, at: Vector2, player: Player, atmosphere: Atmosphere) -> void:
	var bolt := Lightning.new()
	bolt.position = at
	bolt._player = player
	bolt._atmosphere = atmosphere
	bolt.z_index = 45
	parent.add_child(bolt)


func _process(delta: float) -> void:
	_time += delta
	if not _struck and _time >= WARNING:
		_struck = true
		_bolt = PackedVector2Array([Vector2(randf_range(-80, 80), -520)])
		for k in range(1, 9):
			var t := k / 9.0
			_bolt.append(_bolt[0].lerp(Vector2.ZERO, t) + Vector2(randf_range(-22, 22), 0))
		_bolt.append(Vector2.ZERO)
		if is_instance_valid(_atmosphere):
			_atmosphere.flash(0.55)
		Audio.play("hit", 0.0, 0.0)
		RingBurst.spawn(get_parent(), global_position, Color(0.75, 0.88, 1.0), RADIUS + 20.0)
		if is_instance_valid(_player) and not _player.is_dead() and _player.global_position.distance_to(global_position) < RADIUS:
			_player.take_damage(_player.health.max_health * 0.12, global_position, 1, "storm")
			_player.shake_camera(8.0)
		for node in get_tree().get_nodes_in_group("enemies"):
			var enemy := node as Enemy
			if enemy and enemy.global_position.distance_to(global_position) < RADIUS:
				enemy.take_damage(enemy.health.max_health * 0.25, Vector2.ZERO, false, "", "storm")
	if _time > WARNING + 0.35:
		queue_free()
	queue_redraw()


func _draw() -> void:
	if not _struck:
		var share := _time / WARNING
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.6))
		draw_circle(Vector2.ZERO, RADIUS * share, Color(0.75, 0.88, 1.0, 0.2))
		draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 32, Color(0.8, 0.9, 1.0, 0.8), 2.0)
		draw_set_transform(Vector2.ZERO)
		return
	var fade := 1.0 - (_time - WARNING) / 0.35
	draw_polyline(_bolt, Color(0.6, 0.8, 1.0, 0.5 * fade), 7.0)
	draw_polyline(_bolt, Color(1, 1, 1, fade), 2.5)
