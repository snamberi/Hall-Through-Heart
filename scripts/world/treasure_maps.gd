class_name TreasureMaps
extends Node
## Treasure maps: reading one marks a buried cache on the map, somewhere a
## good walk away. Find the spot, and a mound of earth waits to be dug.

const SHOW_DISTANCE := 700.0

## [{"cell": [x, y], "level": int}]
var spots: Array = []

var _world: World
var _player: Player
var _mounds: Dictionary = {}
var _check_left := 0.0


func _ready() -> void:
	SaveGame.register("treasure", self)


func setup(world: World, player: Player) -> void:
	_world = world
	_player = player


func read_map(player: Player) -> String:
	if player.indoors:
		return "Read the map under the open sky."
	var here := _world.world_to_cell(player.global_position)
	for attempt in 12:
		var cell := here + Vector2i(Vector2.from_angle(randf() * TAU) * randf_range(70.0, 180.0))
		cell = _world.generator.find_walkable_near(cell, 20)
		if _world.generator.is_dry_land(cell):
			var level := _world.generator.enemy_level_at(cell)
			spots.append({"cell": [cell.x, cell.y], "level": level})
			var offset := Vector2(cell - here)
			Events.announcement.emit("X MARKS THE SPOT", "%d tiles away - look on your map" % roundi(offset.length()))
			SaveGame.request_save()
			return ""
	return "The map makes no sense here."


func cell_of(spot: Dictionary) -> Vector2i:
	return Vector2i(int(spot["cell"][0]), int(spot["cell"][1]))


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	_check_left -= delta
	if _check_left > 0.0:
		return
	_check_left = 1.0
	for spot: Dictionary in spots:
		var key := str(spot["cell"])
		var at := _world.cell_to_world(cell_of(spot))
		var near := not _player.indoors and at.distance_to(_player.global_position) < SHOW_DISTANCE
		if near and not (_mounds.has(key) and is_instance_valid(_mounds[key])):
			var mound := Prop.create_decor(Prop.Decor.RUBBLE, at, 0.0, "Dig up the buried cache", _dig.bind(spot))
			mound.sprite().modulate = Color(0.75, 0.55, 0.35)
			var mark := Label.new()
			mark.text = "X"
			mark.add_theme_font_size_override("font_size", 28)
			mark.add_theme_color_override("font_color", Color(0.85, 0.15, 0.1))
			mark.add_theme_color_override("font_outline_color", Color.BLACK)
			mark.add_theme_constant_override("outline_size", 6)
			mark.scale = Vector2(0.5, 0.5)
			mark.position = Vector2(-5, -40)
			mound.add_child(mark)
			_player.get_parent().add_child(mound)
			_mounds[key] = mound
		elif not near and _mounds.has(key):
			if is_instance_valid(_mounds[key]):
				_mounds[key].queue_free()
			_mounds.erase(key)


func _dig(player: Player, spot: Dictionary) -> void:
	var key := str(spot["cell"])
	spots.erase(spot)
	if _mounds.has(key) and is_instance_valid(_mounds[key]):
		_mounds[key].queue_free()
	_mounds.erase(key)
	var level: int = spot["level"]
	var items: Array = Structures.roll_chest(level, 2.5)
	items.append(Item.create(Gems.random_gem(level + 10)).to_dict())
	var special := LootGenerator.roll_special(level, "miniboss", 0.0, 0.6)
	if special:
		items.append(special.to_dict())
	if randf() < 0.25:
		items.append(Item.create("treasure_map").to_dict())
	player.professions.add_xp("mining", 40.0)
	Events.loot_opened.emit({"items": items, "title": "Buried cache", "take_only": true})
	SaveGame.request_save()


func save_data() -> Dictionary:
	return {"spots": spots.duplicate(true)}


func load_data(data: Dictionary) -> void:
	spots.clear()
	for saved: Variant in data.get("spots", []):
		if saved is Dictionary and saved.has("cell"):
			spots.append(saved)
