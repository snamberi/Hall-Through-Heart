class_name Builder
extends Node2D
## Placement mode: shows a see-through blueprint of the thing being placed
## under the mouse, green where it can go and red where it cannot.
## Left-click sets it down; right-click or Esc cancels.

var _buildings: Buildings
var _player: Player
var _item: Item
var _kind := ""
var _ghost: Sprite2D
var _problem := ""


func setup(buildings: Buildings, player: Player) -> void:
	_buildings = buildings
	_player = player
	z_index = 80
	Events.placement_requested.connect(begin)
	_ghost = Sprite2D.new()
	_ghost.texture = Prop.SHEET
	_ghost.hframes = Prop.FRAMES
	_ghost.visible = false
	add_child(_ghost)


func is_active() -> bool:
	return _item != null


func begin(item: Item) -> void:
	_item = item
	_kind = item.definition()["place"]
	var kind: Dictionary = Buildings.KINDS[_kind]
	_ghost.texture = Prop.DECOR if kind.has("decor") else Prop.SHEET
	_ghost.hframes = Prop.DECOR_FRAMES if kind.has("decor") else Prop.FRAMES
	_ghost.frame = kind.get("decor", kind.get("art", 0))
	_ghost.scale = Vector2(2.0, 2.0) if _kind == "house" else Vector2.ONE
	_ghost.visible = true
	_player.placing = true


func cancel() -> void:
	_item = null
	_ghost.visible = false
	_player.placing = false
	queue_redraw()


func _process(_delta: float) -> void:
	if _item == null:
		return
	if _player.is_dead() or not _item in _player.inventory.items:
		cancel()
		return
	var at := _snapped(get_global_mouse_position())
	_problem = _buildings.placement_problem(_kind, at)
	_ghost.global_position = at + Vector2(0, -50.0 if _kind == "house" else -22.0)
	_ghost.modulate = Color(0.5, 1.0, 0.55, 0.7) if _problem == "" else Color(1.0, 0.4, 0.4, 0.6)
	queue_redraw()


func _draw() -> void:
	if _item == null:
		return
	# The footprint on the ground, and a line of advice by the cursor.
	var at := to_local(_snapped(get_global_mouse_position()))
	var half := TerrainTiles.TILE_SIZE * (1.5 if _kind == "house" else 0.5)
	var color := UITheme.GOOD if _problem == "" else UITheme.BAD
	draw_rect(Rect2(at - Vector2(half, half), Vector2(half, half) * 2.0), Color(color, 0.18))
	draw_rect(Rect2(at - Vector2(half, half), Vector2(half, half) * 2.0), color, false, 2.0)
	var text := "Left-click to place, right-click to cancel" if _problem == "" else _problem
	var font := UITheme.get_theme().default_font
	draw_string_outline(font, at + Vector2(-150, half + 22.0), text, HORIZONTAL_ALIGNMENT_CENTER, 300.0, 13, 4, Color.BLACK)
	draw_string(font, at + Vector2(-150, half + 22.0), text, HORIZONTAL_ALIGNMENT_CENTER, 300.0, 13, color)


func _unhandled_input(event: InputEvent) -> void:
	if _item == null:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		cancel()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		confirm(_snapped(get_global_mouse_position()))


## Places the item at a position if it is allowed there. Returns whether it was.
func confirm(at: Vector2) -> bool:
	if _item == null or _buildings.placement_problem(_kind, at) != "":
		return false
	_player.inventory.take(_item.id, 1)
	_buildings.place(_kind, at)
	Audio.play("hit", -8.0)
	cancel()
	return true


## The middle of the tile under a point.
func _snapped(at: Vector2) -> Vector2:
	var size := float(TerrainTiles.TILE_SIZE)
	return (at / size).floor() * size + Vector2(size, size) / 2.0
