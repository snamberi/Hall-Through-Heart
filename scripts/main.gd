extends Node2D

const START_NAME := "the Sanctuary"

## World seed. Leave at 0 to use the saved world, or a new random one if
## there is no save. Set a number to force that world.
@export var world_seed := 0

var _active_seed := 0
## Where the player wakes after dying; INF until they rest somewhere.
var _checkpoint := Vector2.INF
var _checkpoint_name := START_NAME

@onready var _world: World = $World
@onready var _player: Player = $Player
@onready var _spawner: EnemySpawner = $Enemies
@onready var _resources: ResourceSpawner = $Resources
@onready var _day_night: DayNight = $DayNight
@onready var _instances: Instances = $Instances
@onready var _structures: Structures = $Structures
@onready var _loot: Node2D = $Loot
@onready var _cinematic: CanvasLayer = $Cinematic
@onready var _hud: CanvasLayer = $HUD
@onready var _menus: CanvasLayer = $Menus
@onready var _debug_hud: CanvasLayer = $DebugHUD


func _ready() -> void:
	Difficulty.current = str(SaveGame.get_section("meta").get("difficulty", "normal"))
	_active_seed = world_seed
	if _active_seed == 0:
		_active_seed = int(SaveGame.get_section("world").get("seed", 0))
	if _active_seed == 0:
		_active_seed = int(randi())
	var saved_world := SaveGame.get_section("world")
	_day_night.day = maxi(int(saved_world.get("day", 1)), 1)
	_day_night.time = clampf(float(saved_world.get("time", _day_night.time)), 0.0, 0.999)
	_day_night.setup(_player)
	SaveGame.register("world", self)

	var stones := Waystones.new()
	stones.name = "Waystones"
	add_child(stones)
	stones.setup(_world, _player)
	var hunts := TreasureMaps.new()
	hunts.name = "TreasureMaps"
	add_child(hunts)
	hunts.setup(_world, _player)
	_world.setup(_active_seed)
	_instances.setup(_player, _world, _spawner, _loot)
	_structures.setup(_world, _player, _spawner, _loot, _instances)
	if saved_world.has("checkpoint"):
		var point: Array = saved_world["checkpoint"]
		_checkpoint = Vector2(point[0], point[1])
		_checkpoint_name = str(saved_world.get("checkpoint_name", START_NAME))
	Events.checkpoint_set.connect(func(at: Vector2, place: String) -> void:
		_checkpoint = at
		_checkpoint_name = place
		SaveGame.request_save()
	)
	var buildings: Buildings = $Buildings
	buildings.setup(_player, _instances)
	$Builder.setup(buildings, _player)
	var settlers := Settlers.new()
	settlers.name = "Settlers"
	add_child(settlers)
	settlers.setup(_player, buildings)
	var raids := Raids.new()
	raids.name = "Raids"
	add_child(raids)
	raids.setup(_player, settlers, _spawner, _world, _day_night)
	_day_night.day_changed.connect(func(_day: int) -> void:
		buildings.dry_plots()
		settlers.morning()
	)
	Events.recall_requested.connect(func() -> void:
		var problem := buildings.recall_problem()
		if problem != "":
			Events.announcement.emit("", problem)
		else:
			buildings.recall()
	)
	Events.dismantle_requested.connect(func() -> void:
		var problem := buildings.dismantle_nearest()
		if problem != "" and problem != "Nothing of yours within reach.":
			Events.announcement.emit("", problem)
	)
	var bounties := Bounties.new()
	bounties.name = "Bounties"
	add_child(bounties)
	bounties.setup(_world, _player, _spawner)
	$Villages.setup(_world)
	$Exploration.setup(_player, _world)
	_resources.setup(_world)
	$Atmosphere.setup(_player, _world, _day_night)
	$Npcs.setup(_world)
	_place_player_at_start()
	_world.target = _player
	_spawner.setup(_world, _player)
	_loot.setup(_player)
	_hud.setup(_player)
	_menus.setup(_player)
	_debug_hud.setup(_world, _player)
	_player.died.connect(_on_player_died)


func save_data() -> Dictionary:
	var data := {"seed": _active_seed, "day": _day_night.day, "time": _day_night.time}
	if _checkpoint != Vector2.INF:
		data["checkpoint"] = [_checkpoint.x, _checkpoint.y]
		data["checkpoint_name"] = _checkpoint_name
	return data


func load_data(_data: Dictionary) -> void:
	pass  # The seed is read in _ready, before the world is built.


## Puts the player where they wake: the last place they rested, or the
## Sanctuary. Brings them out of any cave or interior first.
func _place_player_at_start() -> void:
	var spawn := _checkpoint
	if spawn == Vector2.INF:
		spawn = _world.cell_to_world(_world.generator.find_walkable_near(Vector2i.ZERO))
	if _instances.is_inside():
		_instances.leave(spawn)
	_player.global_position = spawn
	_player.camera.reset_smoothing()
	_world.load_around_now(_player.global_position)


func _on_player_died(xp_lost: int) -> void:
	await _cinematic.play_death(_player, _hud.show_death.bind(xp_lost, _checkpoint_name))
	_place_player_at_start()
	_hud.hide_death()
	await _cinematic.play_rebirth(_player)


## Everything listening to the global event hubs belongs to this scene, so
## drop those connections when the scene goes (back to the title screen, or
## a new game) rather than leave them pointing at freed nodes.
func _exit_tree() -> void:
	for hub: Object in [Events, GameSettings]:
		for signal_info in hub.get_signal_list():
			for connection in hub.get_signal_connection_list(signal_info["name"]):
				hub.disconnect(signal_info["name"], connection["callable"])
