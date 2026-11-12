class_name StateMark
extends Control
## A small drawn mark for whether something can be done: a green tick
## (ready), a red cross (missing what it needs), a padlock (not yet allowed).

var kind := "ready"


static func make(p_kind: String, side: float = 18.0) -> StateMark:
	var mark := StateMark.new()
	mark.kind = p_kind
	mark.custom_minimum_size = Vector2(side, side)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return mark


func set_kind(p_kind: String) -> void:
	kind = p_kind
	queue_redraw()


func _draw() -> void:
	var s := minf(size.x, size.y)
	var o := (size - Vector2(s, s)) / 2.0
	match kind:
		"ready":
			draw_polyline(PackedVector2Array([o + Vector2(s * 0.12, s * 0.55), o + Vector2(s * 0.4, s * 0.82), o + Vector2(s * 0.9, s * 0.18)]), Color(0, 0, 0, 0.6), 5.0)
			draw_polyline(PackedVector2Array([o + Vector2(s * 0.12, s * 0.55), o + Vector2(s * 0.4, s * 0.82), o + Vector2(s * 0.9, s * 0.18)]), UITheme.GOOD, 3.0)
		"missing":
			for line: Array in [[Vector2(0.2, 0.2), Vector2(0.8, 0.8)], [Vector2(0.8, 0.2), Vector2(0.2, 0.8)]]:
				draw_line(o + line[0] * s, o + line[1] * s, Color(0, 0, 0, 0.6), 5.0)
				draw_line(o + line[0] * s, o + line[1] * s, UITheme.BAD, 3.0)
		"locked":
			var body := Rect2(o + Vector2(s * 0.18, s * 0.45), Vector2(s * 0.64, s * 0.5))
			draw_arc(o + Vector2(s * 0.5, s * 0.45), s * 0.22, PI, TAU, 12, Color("c8b88a"), 2.0)
			draw_rect(body, Color("c8b88a"))
			draw_rect(Rect2(o + Vector2(s * 0.46, s * 0.6), Vector2(s * 0.08, s * 0.2)), Color("2a2418"))
