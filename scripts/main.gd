extends Node2D

## World seed. Leave at 0 for a new random world every run; set a number to
## always get the same world.
@export var world_seed := 0
## Seconds between dying and waking up at the starting area.
@export var respawn_delay := 2.0

@onready var _world: World = $World
@onready var _player: Player = $Player
@onready var _spawner: EnemySpawner = $Enemies
@onready var _hud: CanvasLayer = $HUD
@onready var _debug_hud: CanvasLayer = $DebugHUD


func _ready() -> void:
	var active_seed := world_seed if world_seed != 0 else int(randi())
	_world.setup(active_seed)
	_place_player_at_start()

	_world.target = _player
	_spawner.setup(_world, _player)
	_hud.setup(_player)
	_debug_hud.setup(_world, _player)
	_player.died.connect(_on_player_died)


func _place_player_at_start() -> void:
	var spawn_cell := _world.generator.find_walkable_near(Vector2i.ZERO)
	_player.global_position = _world.cell_to_world(spawn_cell)
	_player.camera.reset_smoothing()
	_world.load_around_now(_player.global_position)


func _on_player_died() -> void:
	_hud.show_death_message(true)
	await get_tree().create_timer(respawn_delay).timeout
	_place_player_at_start()
	_player.revive()
	_hud.show_death_message(false)
