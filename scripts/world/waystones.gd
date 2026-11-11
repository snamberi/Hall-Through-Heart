class_name Waystones
extends Node
## Waystones: old standing stones in villages, at the Sanctuary, and out in
## the wilds. Touch one to wake it; from any waking stone you can travel to
## any other for a little gold.

## key -> {"name", "cell": [x, y]}
var known: Dictionary = {}
## The stone the player is using right now, for the travel screen.
var current := ""

var _world: World
var _player: Player


func _ready() -> void:
	SaveGame.register("waystones", self)


func setup(world: World, player: Player) -> void:
	_world = world
	_player = player
	# The Sanctuary's stone is always awake.
	if not known.has("sanctuary"):
		known["sanctuary"] = {"name": "The Sanctuary", "cell": [3, 4]}


## Builds the stone as a prop at a cell.
func make_stone(key: String, place_name: String, cell: Vector2i) -> Prop:
	var stone := Prop.create_decor(Prop.Decor.OBELISK, _world.cell_to_world(cell), 10.0, "Touch the waystone", func(_p: Player) -> void: use(key, place_name, cell))
	stone.sprite().modulate = Color(0.65, 0.9, 1.0) if known.has(key) else Color(0.6, 0.6, 0.65)
	if known.has(key):
		stone.add_light(0.8, 1.4)
	stone.set_meta("waystone", key)
	return stone


func use(key: String, place_name: String, cell: Vector2i) -> void:
	if not known.has(key):
		known[key] = {"name": place_name, "cell": [cell.x, cell.y]}
		Events.announcement.emit("WAYSTONE AWAKENED", place_name)
		Events.codex_event.emit("waystones", 1)
		Audio.play("level_up", -6.0, 0.0)
		for node in get_tree().get_nodes_in_group("props"):
			if node.get_meta("waystone", "") == key:
				node.sprite().modulate = Color(0.65, 0.9, 1.0)
				node.add_light(0.8, 1.4)
		SaveGame.request_save()
	current = key
	Events.screen_requested.emit("waystones")


func cell_of(key: String) -> Vector2i:
	return Vector2i(int(known[key]["cell"][0]), int(known[key]["cell"][1]))


func fee(key: String) -> int:
	var from := _world.world_to_cell(_player.global_position)
	return 5 + roundi(Vector2(cell_of(key) - from).length() / 25.0)


func travel(key: String) -> String:
	if not known.has(key):
		return "You have not woken that stone."
	var cost := fee(key)
	if _player.inventory.gold < cost:
		return "The journey costs %d gold." % cost
	_player.inventory.gold -= cost
	_player.inventory.changed.emit()
	RingBurst.spawn(_player.get_parent(), _player.global_position + Vector2(0, -14), Color(0.6, 0.9, 1.0), 80.0)
	var at := _world.cell_to_world(cell_of(key) + Vector2i(0, 2))
	_player.boating = false
	_player.global_position = at
	_world.load_around_now(at)
	_player.camera.reset_smoothing()
	RingBurst.spawn(_player.get_parent(), at + Vector2(0, -14), Color(0.6, 0.9, 1.0), 80.0)
	Events.announcement.emit(known[key]["name"].to_upper(), "")
	return ""


func save_data() -> Dictionary:
	return {"known": known.duplicate(true)}


func load_data(data: Dictionary) -> void:
	var saved: Variant = data.get("known", {})
	known = saved if saved is Dictionary else {}
