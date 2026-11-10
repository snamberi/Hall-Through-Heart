extends CanvasLayer
## Small readout of where the player is. Toggle with F3.
## F8 deletes the save file and starts a new game (for testing).

var _world: World
var _player: Player

@onready var _label: Label = $Label


func setup(world: World, player: Player) -> void:
	_world = world
	_player = player


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode == KEY_F3:
		visible = not visible
	elif key.keycode == KEY_F8:
		SaveGame.delete_save()
		get_tree().paused = false
		get_tree().reload_current_scene()


func _process(_delta: float) -> void:
	if _world == null or not visible:
		return
	var cell := _world.world_to_cell(_player.global_position)
	_label.text = "Seed %d\nTile %d, %d\n%s - area level %d\nChunks %d   Enemies %d   FPS %d" % [
		_world.generator.world_seed,
		cell.x,
		cell.y,
		TerrainTiles.display_name(_world.generator.tile_type_at(cell)),
		_world.generator.enemy_level_at(cell),
		_world.loaded_chunk_count(),
		get_tree().get_nodes_in_group("enemies").size(),
		Engine.get_frames_per_second(),
	]
