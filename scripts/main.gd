extends Node2D

## World seed. Leave at 0 for a new random world every run; set a number to
## always get the same world.
@export var world_seed := 0

@onready var _world: World = $World
@onready var _player: Player = $Player
@onready var _hud: CanvasLayer = $DebugHUD


func _ready() -> void:
	var active_seed := world_seed if world_seed != 0 else int(randi())
	_world.setup(active_seed)

	var spawn_cell := _world.generator.find_walkable_near(Vector2i.ZERO)
	_player.global_position = _world.cell_to_world(spawn_cell)
	_player.camera.reset_smoothing()

	_world.target = _player
	_world.load_around_now(_player.global_position)
	_hud.setup(_world, _player)
