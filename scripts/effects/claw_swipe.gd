class_name ClawSwipe
extends Node2D
## A monster's swipe: three curved claw marks (or one blade arc) sweeping
## across in front of it, fading out fast.

var _direction := Vector2.RIGHT
var _reach := 60.0
var _arc := 1.6
var _color := Color(1.0, 0.95, 0.85)
var _claws := 3
var _age := 0.0
const LIFE := 0.22


static func spawn(parent: Node, at: Vector2, direction: Vector2, reach: float, arc_degrees: float, color: Color, claws: int = 3) -> void:
	if parent == null:
		return
	var swipe := ClawSwipe.new()
	swipe.position = at + Vector2(0, -14)
	swipe._direction = direction.normalized()
	swipe._reach = reach
	swipe._arc = deg_to_rad(arc_degrees)
	swipe._color = color
	swipe._claws = claws
	swipe.z_index = 20
	parent.add_child(swipe)


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var t := _age / LIFE
	var sweep := minf(t * 1.6, 1.0)
	var fade := 1.0 - maxf(0.0, (t - 0.4) / 0.6)
	var base := _direction.angle()
	for claw in _claws:
		var radius := _reach * (0.55 + 0.18 * claw)
		var start := base - _arc / 2.0
		var finish := start + _arc * sweep
		var points := PackedVector2Array()
		var steps := 10
		for i in steps + 1:
			var a := lerpf(start, finish, float(i) / steps)
			points.append(Vector2.from_angle(a) * radius)
		var width := 3.0 if _claws > 1 else 5.0
		draw_polyline(points, Color(_color, 0.85 * fade), width)
		draw_polyline(points, Color(1, 1, 1, 0.6 * fade), 1.0)
