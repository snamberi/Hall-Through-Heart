class_name FightMarks
extends Node2D
## What a fight leaves on the ground: blood where creatures were cut (goo
## from slimes, ichor from things of the void, bone dust from the dead),
## scorched earth where fire burst, its embers glowing a while as they
## cool, ground cracked where something heavy struck, and rime where frost
## blew out. Blood darkens as it dries; everything fades away over a few
## minutes. Drawn from marks.png (tools/generate_marks.py), each mark
## whole-pixel, turned only by flipping.

const SHEET: Texture2D = preload("res://assets/sprites/marks.png")
const LIFE := 180.0
const FADE := 60.0
## Blood dries over this long, from wet red to old brown.
const DRY := 55.0
const DRIED := Color(0.6, 0.48, 0.44)
## Embers glow this long.
const EMBERS := 9.0
const MOST := 150
## kind -> [frames, frame size, row y]
const KINDS := {
	"blood": [[0, 1, 2, 3, 4, 5], 32, 0],
	"drip": [[6, 7, 8, 9], 32, 0],
	"goo": [[10, 11, 12], 32, 0],
	"ichor": [[13, 14], 32, 0],
	"dust": [[15], 32, 0],
	"scorch": [[0, 1, 2], 64, 32],
	"crack": [[6, 7], 64, 32],
	"frost": [[0, 1], 64, 96],
}

## [kind, frame, position, flip_x, flip_y, age]
var _marks: Array = []
var _player: Node2D


static func find(tree: SceneTree) -> FightMarks:
	return tree.get_first_node_in_group("fight_marks") as FightMarks if tree else null


## Leaves a mark at a point (where the ground is), if the game has a place
## for them.
static func leave(tree: SceneTree, kind: String, at: Vector2) -> void:
	var marks := find(tree)
	if marks:
		marks.add(kind, at)


## The mark a creature of this matter leaves (see Gore.MATTER).
static func for_matter(matter: String, colour: Color) -> String:
	match matter:
		"blood":
			return "blood"
		"slime":
			return "goo"
		"dust", "stone":
			return "dust"
		"ember":
			return "scorch"
		"smoke":
			# Void things bleed violet; ash and spores leave nothing.
			return "ichor" if colour.b > colour.g * 1.3 and colour.b > 0.7 else ""
	return ""


## What a blast of an ability or spell does to the ground, by its status
## or its colour: fire scorches, frost rimes, anything else cracks it.
static func for_blast(status: String, colour: Color) -> String:
	if status in ["burn", "ignite", "fire"]:
		return "scorch"
	if status in ["chill", "freeze", "frost"]:
		return "frost"
	if colour.r > 0.85 and colour.g < 0.7 and colour.b < 0.45:
		return "scorch"
	if colour.b > 0.85 and colour.r < 0.75 and colour.g > 0.75:
		return "frost"
	return "crack"


func setup(player: Node2D) -> void:
	_player = player


func _ready() -> void:
	add_to_group("fight_marks")
	z_as_relative = false
	z_index = -9
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func add(kind: String, at: Vector2) -> void:
	if not KINDS.has(kind):
		return
	# Water carries it away.
	var world := get_tree().get_first_node_in_group("world") as World if is_inside_tree() else null
	if world and world.generator and TerrainTiles.is_water(world.tile_type_at_position(at)):
		return
	var frames: Array = KINDS[kind][0]
	# Close to another of its kind, a mark joins it rather than piling up.
	for mark: Array in _marks:
		if mark[0] == kind and (mark[2] as Vector2).distance_to(at) < 6.0 and mark[5] < 2.0:
			return
	_marks.append([kind, frames[randi() % frames.size()], at.floor(), randf() < 0.5, randf() < 0.3 and kind != "scorch", 0.0])
	while _marks.size() > MOST:
		_marks.pop_front()
	queue_redraw()


func _process(delta: float) -> void:
	if _marks.is_empty():
		return
	for index in range(_marks.size() - 1, -1, -1):
		var mark: Array = _marks[index]
		mark[5] += delta
		var far := _player != null and is_instance_valid(_player) and (mark[2] as Vector2).distance_to(_player.global_position) > 1800.0
		if mark[5] >= LIFE or far:
			_marks.remove_at(index)
	queue_redraw()


func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for mark: Array in _marks:
		var info: Array = KINDS[mark[0]]
		var size: int = info[1]
		var frame: int = mark[1]
		var age: float = mark[5]
		var alpha := clampf((LIFE - age) / FADE, 0.0, 1.0)
		var tint := Color(1, 1, 1, alpha)
		if mark[0] in ["blood", "drip"]:
			tint = Color.WHITE.lerp(DRIED, clampf(age / DRY, 0.0, 1.0))
			tint.a = alpha
		var source := Rect2(frame * size, info[2], size, size)
		var half := Vector2(size, size) / 2.0
		var rect := Rect2((mark[2] as Vector2) - half, Vector2(size, size))
		if mark[3]:
			rect = Rect2(rect.position + Vector2(size, 0), Vector2(-size, size))
		if mark[4]:
			rect = Rect2(rect.position + Vector2(0, size), Vector2(rect.size.x, -size))
		draw_texture_rect_region(SHEET, rect, source, tint)
		# A scorch's embers, glowing and flickering as they cool.
		if mark[0] == "scorch" and age < EMBERS:
			var glow := (1.0 - age / EMBERS) * (0.75 + 0.25 * sin(t * 11.0 + frame * 2.0))
			draw_texture_rect_region(SHEET, rect, Rect2((frame + 3) * size, info[2], size, size), Color(1.3, 1.1, 1.0, glow))
