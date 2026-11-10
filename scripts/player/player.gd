class_name Player
extends CharacterBody2D

@export var move_speed := 90.0
## How quickly the player reaches full speed and stops, in pixels/second².
@export var acceleration := 900.0

## Last direction the player moved in. Combat will aim attacks along this.
var facing := Vector2.DOWN

@onready var camera: Camera2D = $Camera
@onready var _visual: Node2D = $Visual


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input != Vector2.ZERO:
		facing = input.normalized()
		if absf(input.x) > 0.1:
			_visual.scale.x = signf(input.x)
	velocity = velocity.move_toward(input * move_speed, acceleration * delta)
	move_and_slide()
