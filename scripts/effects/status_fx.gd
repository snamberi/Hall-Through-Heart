class_name StatusFX
extends Node2D
## Little particles around a creature for each status it suffers: flames for
## burn, bubbles for poison, drips for bleed, frost for chill, and a row of
## small badges above its head.

## Returns the ids of the statuses on the owner right now.
var source: Callable
## How tall the owner is, for where the badges go.
var height := 44.0
var width := 14.0

var _particles: Array[Dictionary] = []
var _spawn := 0.0
var _ids: Array = []


static func attach(owner: Node2D, statuses: Callable, p_height: float, p_width: float) -> StatusFX:
	var fx := StatusFX.new()
	fx.source = statuses
	fx.height = p_height
	fx.width = p_width
	fx.z_index = 2
	owner.add_child(fx)
	return fx


func _process(delta: float) -> void:
	_ids = source.call() if source.is_valid() else []
	_spawn -= delta
	if _spawn <= 0.0 and not _ids.is_empty():
		_spawn = 0.07
		for id: String in _ids:
			if randf() < 0.75:
				_particles.append(_new_particle(id))
	for particle in _particles:
		particle["life"] -= delta
		particle["pos"] += particle["vel"] * delta
		if particle["id"] == "bleed":
			particle["vel"].y += 160.0 * delta
	_particles = _particles.filter(func(p: Dictionary) -> bool: return p["life"] > 0.0)
	visible = not _particles.is_empty() or not _ids.is_empty()
	queue_redraw()


func _new_particle(id: String) -> Dictionary:
	var x := randf_range(-width, width)
	match id:
		"burn":
			return {"id": id, "pos": Vector2(x, randf_range(-height * 0.6, 0)), "vel": Vector2(randf_range(-6, 6), randf_range(-55, -35)), "life": 0.55, "max": 0.55}
		"poison":
			return {"id": id, "pos": Vector2(x, randf_range(-height * 0.7, -4)), "vel": Vector2(randf_range(-4, 4), randf_range(-26, -14)), "life": 0.9, "max": 0.9}
		"bleed":
			return {"id": id, "pos": Vector2(x * 0.7, randf_range(-height * 0.7, -height * 0.3)), "vel": Vector2(randf_range(-10, 10), -20), "life": 0.5, "max": 0.5}
	return {"id": id, "pos": Vector2(x * 1.2, randf_range(-height, -height * 0.2)), "vel": Vector2(randf_range(-6, 6), randf_range(8, 18)), "life": 1.0, "max": 1.0}


func _draw() -> void:
	# Chill also rims the feet with frost.
	if "chill" in _ids:
		draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.4))
		draw_arc(Vector2.ZERO, width + 6.0, 0.0, TAU, 24, Color(0.7, 0.9, 1.0, 0.7), 2.0)
		draw_set_transform(Vector2.ZERO)
	if "poison" in _ids:
		draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.4))
		draw_circle(Vector2.ZERO, width + 4.0, Color(0.4, 0.8, 0.25, 0.18))
		draw_set_transform(Vector2.ZERO)
	for particle in _particles:
		var share: float = particle["life"] / particle["max"]
		var pos: Vector2 = particle["pos"]
		match particle["id"]:
			"burn":
				var color := Color(1.0, 0.85, 0.3).lerp(Color(0.9, 0.2, 0.05), 1.0 - share)
				draw_circle(pos, 1.0 + 2.6 * share, Color(color, 0.9))
			"poison":
				draw_arc(pos, 1.5 + 2.0 * (1.0 - share), 0.0, TAU, 8, Color(0.55, 0.95, 0.4, share), 1.0)
			"bleed":
				draw_rect(Rect2(pos, Vector2(2, 3)), Color(0.75, 0.05, 0.08, share))
			_:
				var c := Color(0.85, 0.95, 1.0, share)
				draw_line(pos + Vector2(-2, 0), pos + Vector2(2, 0), c, 1.0)
				draw_line(pos + Vector2(0, -2), pos + Vector2(0, 2), c, 1.0)
	# Badges: one coloured diamond per status above the head.
	var start := -(_ids.size() - 1) * 6.0
	for index in _ids.size():
		var center := Vector2(start + index * 12.0, -height - 10.0)
		var color: Color = ItemDB.STATUSES[_ids[index]]["color"]
		var points := PackedVector2Array([center + Vector2(0, -5), center + Vector2(5, 0), center + Vector2(0, 5), center + Vector2(-5, 0)])
		draw_colored_polygon(points, Color(0.05, 0.05, 0.08))
		draw_colored_polygon(PackedVector2Array([center + Vector2(0, -3.5), center + Vector2(3.5, 0), center + Vector2(0, 3.5), center + Vector2(-3.5, 0)]), color)
