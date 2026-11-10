class_name ResourcePool
extends Node
## A spendable, regenerating pool such as stamina or mana.

signal changed(current: float, maximum: float)

@export var max_value := 100.0
@export var regen_per_second := 0.0
## Seconds after spending before regeneration starts again.
@export var regen_delay := 0.0

var current := 0.0

var _delay_left := 0.0


func _ready() -> void:
	current = max_value


func _physics_process(delta: float) -> void:
	if _delay_left > 0.0:
		_delay_left -= delta
	elif current < max_value and regen_per_second > 0.0:
		current = minf(current + regen_per_second * delta, max_value)
		changed.emit(current, max_value)


## Takes `amount` if there is enough. Returns whether it was spent.
func spend(amount: float) -> bool:
	if amount > current:
		return false
	current -= amount
	_delay_left = regen_delay
	changed.emit(current, max_value)
	return true


func fill() -> void:
	current = max_value
	changed.emit(current, max_value)


## Changes the maximum. Any increase is also added to the current amount.
func set_max(value: float) -> void:
	if is_equal_approx(value, max_value):
		return
	var gained := maxf(value - max_value, 0.0)
	max_value = value
	current = clampf(current + gained, 0.0, max_value)
	changed.emit(current, max_value)
