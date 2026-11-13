class_name MarkOverlay
extends Control
## A tick in the corner and a bright edge over an item slot, for items
## marked to sell or throw away together.


static func attach(slot: Control) -> MarkOverlay:
	var mark := MarkOverlay.new()
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mark.visible = false
	slot.add_child(mark)
	return mark


func _draw() -> void:
	var edge := Color(0.55, 0.95, 0.5)
	draw_rect(Rect2(Vector2(1, 1), size - Vector2(2, 2)), Color(edge, 0.9), false, 2.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.3, 0.8, 0.3, 0.12))
	var box := Rect2(3, 3, 14, 14)
	draw_rect(box, Color(0.05, 0.08, 0.05, 0.9))
	draw_rect(box, edge, false, 1.0)
	draw_polyline(PackedVector2Array([box.position + Vector2(3, 7), box.position + Vector2(6, 10), box.position + Vector2(11, 3)]), edge, 2.0)
