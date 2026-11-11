class_name Critter
extends Node2D
## Harmless wildlife: rabbits and frogs hop about and bolt from the player,
## birds take off, butterflies flutter by day, fireflies glow at night.

const SHEET: Texture2D = preload("res://assets/sprites/critters.png")
const KINDS := ["rabbit", "bird", "butterfly", "frog"]
const SCARE := 120.0

var kind := "rabbit"

var _sprite: Sprite2D
var _velocity := Vector2.ZERO
var _think := 0.0
var _flying := false
var _time := 0.0
var _home := Vector2.ZERO


static func create(p_kind: String, at: Vector2) -> Critter:
	var critter := Critter.new()
	critter.kind = p_kind
	critter.position = at
	critter._home = at
	return critter


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = SHEET
	_sprite.hframes = KINDS.size() * 2
	_sprite.frame = KINDS.find(kind) * 2
	_sprite.position.y = -8.0
	add_child(_sprite)
	_flying = kind == "butterfly"
	_time = randf() * 10.0


func _process(delta: float) -> void:
	_time += delta
	_think -= delta
	var player: Node2D = get_tree().get_first_node_in_group("player")
	var away := Vector2.ZERO
	if player and player.global_position.distance_to(global_position) < SCARE:
		away = player.global_position.direction_to(global_position)
	match kind:
		"bird":
			if away != Vector2.ZERO and not _flying:
				_flying = true
				_velocity = (away + Vector2(0, -0.6)).normalized() * 260.0
			if _flying:
				_sprite.frame = 2 + int(_time * 12.0) % 2
				_sprite.position.y -= 40.0 * delta
				modulate.a -= delta * 0.4
				if modulate.a <= 0.0:
					queue_free()
			elif _think <= 0.0:
				_think = randf_range(0.6, 2.0)
				_sprite.frame = 2 + (1 if randf() < 0.2 else 0)
		"butterfly":
			_sprite.frame = 4 + int(_time * 8.0) % 2
			_sprite.position.y = -18.0 + sin(_time * 3.0) * 4.0
			if _think <= 0.0:
				_think = randf_range(0.5, 1.5)
				_velocity = (Vector2.from_angle(randf() * TAU) * 40.0 + (_home - global_position) * 0.3)
			if away != Vector2.ZERO:
				_velocity = away * 80.0
		_:
			var base := KINDS.find(kind) * 2
			if away != Vector2.ZERO:
				_velocity = away * 170.0
				_think = 0.6
			elif _think <= 0.0:
				_think = randf_range(0.8, 2.5)
				_velocity = Vector2.ZERO if randf() < 0.5 else Vector2.from_angle(randf() * TAU) * 50.0
			# A hop: up and down while moving.
			var moving := _velocity.length() > 5.0
			_sprite.frame = base + (1 if moving and int(_time * 6.0) % 2 == 0 else 0)
			_sprite.position.y = -8.0 - (abs(sin(_time * 10.0)) * 4.0 if moving else 0.0)
			_velocity = _velocity.move_toward(Vector2.ZERO, 40.0 * delta) if _think < 0.3 else _velocity
	position += _velocity * delta
	if absf(_velocity.x) > 1.0:
		_sprite.flip_h = _velocity.x < 0.0
