class_name PortalFX
extends Node2D
## The turning of a portal: rings that wheel, motes drawn in, a slow pulse.

var color := Color(0.75, 0.5, 1.0)
var _phase := randf() * 10.0


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0 + _phase
	var pulse := 0.5 + 0.5 * sin(t * 2.4)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(0.72, 1.0))
	draw_circle(Vector2.ZERO, 15.0 + pulse * 2.0, Color(color, 0.14 + 0.1 * pulse))
	for ring in 3:
		var start := t * (1.6 + ring * 0.7) * (1.0 if ring % 2 == 0 else -1.0)
		draw_arc(Vector2.ZERO, 9.0 + ring * 5.0, start, start + PI * 1.2, 16, Color(color.lerp(Color.WHITE, 0.3 + 0.2 * ring), 0.75 - ring * 0.15), 1.5)
	for k in 7:
		var travel := fposmod(t * 0.5 + k / 7.0, 1.0)
		var angle := k * 0.9 + t * 1.7
		var at := Vector2(cos(angle), sin(angle)) * (24.0 * (1.0 - travel) + 2.0)
		draw_rect(Rect2(at - Vector2(1, 1), Vector2(2, 2)), Color(1, 1, 1, travel))
	draw_set_transform(Vector2.ZERO)
