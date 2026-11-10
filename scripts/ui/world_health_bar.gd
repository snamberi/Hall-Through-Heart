extends Node2D
## Small bar above an enemy. Hidden until the enemy has been hurt.

const SIZE := Vector2(14.0, 2.0)

var _fraction := 1.0


func _ready() -> void:
	visible = false
	var health: Health = get_parent().get_node("Health")
	health.changed.connect(_on_health_changed)


func _on_health_changed(current: float, maximum: float) -> void:
	_fraction = current / maximum
	visible = _fraction > 0.0 and _fraction < 1.0
	queue_redraw()


func _draw() -> void:
	var origin := -SIZE / 2.0
	draw_rect(Rect2(origin - Vector2.ONE, SIZE + Vector2(2.0, 2.0)), Color(0, 0, 0, 0.8))
	draw_rect(Rect2(origin, Vector2(SIZE.x * _fraction, SIZE.y)), Color(0.7, 0.13, 0.16))
