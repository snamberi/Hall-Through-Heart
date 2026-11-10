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


func take_damage(amount: float) -> void:
	if is_dead() or amount <= 0.0:
		return
	current = maxf(current - amount, 0.0)
	damaged.emit(amount)
	changed.emit(current, max_health)
	if is_dead():
		died.emit()


## Changes the maximum. Any increase is also added to current health.
func set_max_health(value: float) -> void:
	var gained := maxf(value - max_health, 0.0)
	max_health = value
	current = clampf(current + gained, 0.0, max_health)
	changed.emit(current, max_health)


func heal_full() -> void:
	current = max_health
	changed.emit(current, max_health)
