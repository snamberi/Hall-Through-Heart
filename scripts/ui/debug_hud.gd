extends CanvasLayer
## The F3 debug screen: plain lines of technical readouts over the game.
##
## Hidden until F3 is pressed. F8 deletes the save and starts a new game
## while it is showing (for testing).

const VERSION := "Hall Through Heart  dev build"

var _world: World
var _player: Player
var _lines: PackedStringArray = []
var _font: Font

@onready var _canvas: Control = $Canvas


func _ready() -> void:
	visible = false
	_font = ThemeDB.fallback_font
	_canvas.draw.connect(_draw_lines)


func setup(world: World, player: Player) -> void:
	_world = world
	_player = player


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode == KEY_F3:
		visible = not visible
	elif key.keycode == KEY_F8 and visible:
		SaveGame.delete_save()
		get_tree().paused = false
		get_tree().reload_current_scene()


func _process(_delta: float) -> void:
	if _world == null or not visible:
		return
	var position := _player.global_position
	var cell := _world.world_to_cell(position)
	var chunk := _world.cell_to_chunk(cell)
	var generator := _world.generator
	_lines = PackedStringArray([
		VERSION,
		"%d fps   Godot %s" % [Engine.get_frames_per_second(), Engine.get_version_info()["string"]],
		"",
		"XY: %.1f / %.1f" % [position.x, position.y],
		"Tile: %d %d   Chunk: %d %d" % [cell.x, cell.y, chunk.x, chunk.y],
		"Biome: %s" % TerrainTiles.display_name(generator.tile_type_at(cell)),
		"Area level: %d" % generator.enemy_level_at(cell),
		"Seed: %d" % generator.world_seed,
		"",
		"Chunks loaded: %d" % _world.loaded_chunk_count(),
		"Enemies: %d   Pickups: %d" % [
			get_tree().get_nodes_in_group("enemies").size(),
			get_tree().get_nodes_in_group("pickups").size(),
		],
		"Player state: %s   Weapon: %s" % [Player.State.keys()[_player.state], _player.weapon_type],
		"Time scale: %.2f   Nodes: %d" % [Engine.time_scale, get_tree().get_node_count()],
		"Memory: %.1f MB" % (OS.get_static_memory_usage() / 1048576.0),
		"",
		"F3 hide   F8 new game",
	])
	_canvas.queue_redraw()


func _draw_lines() -> void:
	var y := 4.0
	for line in _lines:
		if line != "":
			var width := _font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			_canvas.draw_rect(Rect2(4, y, width + 8, 19), Color(0.2, 0.2, 0.2, 0.6))
			_canvas.draw_string(_font, Vector2(8, y + 14), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.88, 0.88, 0.88))
		y += 19.0
