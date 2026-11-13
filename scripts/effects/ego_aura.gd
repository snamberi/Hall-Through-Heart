class_name EgoAura
extends Node2D
## Pride made visible: once Ego climbs past Proud, a crown of cold flame
## flickers over the player's head and a faint haze clings to them,
## violet at first, turning angry red as ego grows.

var _player: Player
var _time := 0.0


func setup(player: Player) -> void:
	_player = player
	z_index = 5
	position = Vector2(0, -47)


func _process(delta: float) -> void:
	_time += delta
	var showing := _player.ego != null and _player.ego.value >= Ego.FREE + 20.0 and not _player.is_dead()
	visible = showing
	if showing:
		queue_redraw()


func _draw() -> void:
	var heat := clampf((_player.ego.value - Ego.FREE) / (Ego.MAX - Ego.FREE), 0.0, 1.0)
	var color := Color(0.65, 0.45, 1.0).lerp(Color(1.0, 0.3, 0.35), heat)
	var strength := 0.35 + 0.65 * heat
	draw_circle(Vector2(0, 34), 26.0, Color(color, 0.06 * strength))
	# Five tongues of flame in a ring, each flickering on its own.
	for k in 5:
		var x := (k - 2) * 5.0
		var flicker := sin(_time * 9.0 + k * 1.7) * 0.5 + 0.5
		var tall := (6.0 + 5.0 * flicker) * (0.7 + 0.6 * strength) * (1.2 if k == 2 else 1.0)
		var sway := sin(_time * 4.0 + k) * 1.5
		draw_colored_polygon(PackedVector2Array([Vector2(x - 2.5, 0), Vector2(x + sway, -tall), Vector2(x + 2.5, 0)]), Color(color, 0.55 * strength))
		draw_colored_polygon(PackedVector2Array([Vector2(x - 1.2, 0), Vector2(x + sway * 0.6, -tall * 0.6), Vector2(x + 1.2, 0)]), Color(color.lightened(0.5), 0.8 * strength))
	draw_rect(Rect2(-12, 0, 24, 2), Color(color.darkened(0.2), 0.7 * strength))
