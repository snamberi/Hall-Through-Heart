class_name Exploration
extends Node
## Remembers which parts of the world the player has seen, for the map.
##
## The world is measured in map cells of CELL x CELL tiles, grouped into
## blocks of BLOCK x BLOCK cells, each stored as a bitmask.

const CELL := 4
const BLOCK := 64
## How far the player sees, in tiles.
const SIGHT := 16

var _blocks: Dictionary = {}
var _player: Player
var _world: World
var _last := Vector2i.MAX


func _ready() -> void:
	SaveGame.register("exploration", self)


func setup(player: Player, world: World) -> void:
	_player = player
	_world = world


func _physics_process(_delta: float) -> void:
	if _player == null or _player.indoors:
		return
	var cell := _map_cell(_world.world_to_cell(_player.global_position))
	if cell == _last:
		return
	_last = cell
	var reach := SIGHT / CELL
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			if Vector2(dx, dy).length() <= reach + 0.5:
				_mark(cell + Vector2i(dx, dy))


## The map cell holding a tile.
static func _map_cell(tile: Vector2i) -> Vector2i:
	return Vector2i((Vector2(tile) / CELL).floor())


func is_seen(map_cell: Vector2i) -> bool:
	var block := Vector2i((Vector2(map_cell) / BLOCK).floor())
	var bits: PackedByteArray = _blocks.get(block, PackedByteArray())
	if bits.is_empty():
		return false
	var index := (map_cell.y - block.y * BLOCK) * BLOCK + (map_cell.x - block.x * BLOCK)
	return (bits[index >> 3] >> (index & 7)) & 1 == 1


func is_tile_seen(tile: Vector2i) -> bool:
	return is_seen(_map_cell(tile))


## Marks every map cell within `radius` tiles of a tile as seen (obelisks).
func reveal(center: Vector2i, radius: int) -> void:
	var middle := _map_cell(center)
	var reach := radius / CELL
	for y in range(-reach, reach + 1):
		for x in range(-reach, reach + 1):
			if x * x + y * y <= reach * reach:
				_mark(middle + Vector2i(x, y))
	SaveGame.request_save()


func _mark(map_cell: Vector2i) -> void:
	var block := Vector2i((Vector2(map_cell) / BLOCK).floor())
	if not _blocks.has(block):
		var empty := PackedByteArray()
		empty.resize(BLOCK * BLOCK / 8)
		_blocks[block] = empty
	var index := (map_cell.y - block.y * BLOCK) * BLOCK + (map_cell.x - block.x * BLOCK)
	var bits: PackedByteArray = _blocks[block]
	bits[index >> 3] |= 1 << (index & 7)
	_blocks[block] = bits


func save_data() -> Dictionary:
	var data := {}
	for block: Vector2i in _blocks:
		data["%d,%d" % [block.x, block.y]] = Marshalls.raw_to_base64(_blocks[block])
	return {"blocks": data}


func load_data(data: Dictionary) -> void:
	_blocks.clear()
	var saved: Variant = data.get("blocks", {})
	if saved is Dictionary:
		for key: String in saved:
			var parts := key.split(",")
			if parts.size() == 2:
				_blocks[Vector2i(int(parts[0]), int(parts[1]))] = Marshalls.base64_to_raw(saved[key])
