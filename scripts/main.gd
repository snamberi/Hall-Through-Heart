extends Node2D

const START_NAME := "the Sanctuary"

## World seed. Leave at 0 to use the saved world, or a new random one if
## there is no save. Set a number to force that world.
@export var world_seed := 0
## Seconds between dying and waking up at the starting area.
@export var respawn_delay := 3.0

var _active_seed := 0

@onready var _world: World = $World
@onready var _player: Player = $Player
@onready var _spawner: EnemySpawner = $Enemies
@onready var _loot: Node2D = $Loot
@onready var _hud: CanvasLayer = $HUD
@onready var _menus: CanvasLayer = $Menus
@onready var _debug_hud: CanvasLayer = $DebugHUD


func _ready() -> void:
	_active_seed = world_seed
	if _active_seed == 0:
		_active_seed = int(SaveGame.get_section("world").get("seed", 0))
	if _active_seed == 0:
		_active_seed = int(randi())
	SaveGame.register("world", self)

	_world.setup(_active_seed)
	_place_player_at_start()
	_world.target = _player
	_spawner.setup(_world, _player)
	_loot.setup(_player)
	_hud.setup(_player)
	_menus.setup(_player)
	_debug_hud.setup(_world, _player)
	_player.died.connect(_on_player_died)


func save_data() -> Dictionary:
	return {"seed": _active_seed}


func load_data(_data: Dictionary) -> void:
	pass  # The seed is read in _ready, before the world is built.


func _place_player_at_start() -> void:
	var spawn_cell := _world.generator.find_walkable_near(Vector2i.ZERO)
	_player.global_position = _world.cell_to_world(spawn_cell)
	_player.camera.reset_smoothing()
	_world.load_around_now(_player.global_position)


func _on_player_died(xp_lost: int) -> void:
	_hud.show_death(xp_lost, START_NAME)
	await get_tree().create_timer(respawn_delay).timeout
	_place_player_at_start()
	_player.revive()
	_hud.hide_death()
