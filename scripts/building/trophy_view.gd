class_name TrophyView
extends Node2D
## The trophy standing on a Trophy Stand, drawn from its pixel map at the
## world's own pixel size, with a slow glint now and then.

signal changed

var record: Dictionary = {}
var _glint := 0.0


func _ready() -> void:
	add_to_group("trophy_views")
	z_index = 1


func refresh() -> void:
	queue_redraw()
	changed.emit()


func _process(delta: float) -> void:
	if record.get("trophy", "") == "":
		return
	var was := _glint
	_glint = fposmod(_glint + delta * 0.35, 1.0)
	if _glint < 0.12 or was < 0.12:
		queue_redraw()


func _draw() -> void:
	var boss: String = record.get("trophy", "")
	if not Trophies.TROPHIES.has(boss):
		return
	# Placed on the stand's cloth top (row 30 of its 64-pixel frame).
	var foot := Vector2.ZERO
	Trophies.draw(self, boss, foot)
	if _glint < 0.12:
		var size := Trophies.size_of(boss)
		var x := roundf(-size.x / 2.0 + _glint / 0.12 * size.x)
		draw_rect(Rect2(x, foot.y - size.y + 2, 1, 1), Color(1, 1, 1, 0.9))
