class_name Health
extends Node
## Hit points for anything that can be hurt.

signal changed(current: float, maximum: float)
signal damaged(amount: float)
signal died

@export var max_health := 100.0

var current := 0.0


func _ready() -> void:
	current = max_health


func is_dead() -> bool:
	return current <= 0.0


## Returns the health actually removed.
func take_damage(amount: float) -> float:
	if is_dead() or amount <= 0.0:
		return 0.0
	var dealt := minf(amount, current)
	current -= dealt
	damaged.emit(dealt)
	changed.emit(current, max_health)
	if is_dead():
		died.emit()
	return dealt


func heal(amount: float) -> void:
	if is_dead() or amount <= 0.0 or current >= max_health:
		return
	current = minf(current + amount, max_health)
	changed.emit(current, max_health)


## Changes the maximum. Any increase is also added to current health.
func set_max_health(value: float) -> void:
	if is_equal_approx(value, max_health):
		return
	var gained := maxf(value - max_health, 0.0)
	max_health = value
	current = clampf(current + gained, 0.0, max_health)
	changed.emit(current, max_health)


func heal_full() -> void:
	current = max_health
	changed.emit(current, max_health)
