extends CanvasLayer
## On-screen player status: health bar and the death message.

@onready var _bar: Control = $HealthBar
@onready var _death_message: Label = $DeathMessage

var _fraction := 1.0


func setup(player: Player) -> void:
	player.health.changed.connect(_on_health_changed)
	_bar.draw.connect(_draw_bar)
	_death_message.visible = false


func show_death_message(shown: bool) -> void:
	_death_message.visible = shown


func _on_health_changed(current: float, maximum: float) -> void:
	_fraction = current / maximum
	_bar.queue_redraw()


func _draw_bar() -> void:
	var size := _bar.size
	_bar.draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.75))
	var inner := Rect2(Vector2(2, 2), Vector2((size.x - 4.0) * _fraction, size.y - 4.0))
	_bar.draw_rect(inner, Color(0.62, 0.1, 0.14))
	_bar.draw_rect(Rect2(Vector2.ZERO, size), Color(0.55, 0.5, 0.42), false, 1.0)
