class_name MapIcons
extends RefCounted
## The little pictures on the map and the minimap: one for each kind of
## place, and for the player, animals, monsters, pets and people.
## Drawn by tools/generate_art.py into assets/icons/map.png, in this order.

const SHEET: Texture2D = preload("res://assets/icons/map.png")
const CELL := 22
const KINDS: Array[String] = ["village", "ruin", "shrine", "cave", "lair", "portal", "camp", "waystone", "obelisk", "merchant", "shipwreck", "treasure",
	"boss", "dungeon", "bounty", "temple", "home", "checkpoint", "player", "animal", "monster", "pet", "npc", "chest"]

static var _textures: Dictionary = {}


static func texture(kind: String) -> Texture2D:
	if not _textures.has(kind):
		var atlas := AtlasTexture.new()
		atlas.atlas = SHEET
		atlas.region = Rect2(maxi(KINDS.find(kind), 0) * CELL, 0, CELL, CELL)
		_textures[kind] = atlas
	return _textures[kind]


## Draws a kind's icon centred on a point, `size` pixels across.
static func draw(canvas: CanvasItem, at: Vector2, kind: String, size: float = 22.0, tint: Color = Color.WHITE) -> void:
	if not kind in KINDS:
		canvas.draw_circle(at, size * 0.28, Color(0, 0, 0, 0.85))
		canvas.draw_circle(at, size * 0.18, tint)
		return
	canvas.draw_texture_rect(texture(kind), Rect2(at - Vector2(size, size) / 2.0, Vector2(size, size)), false, tint)


## The player's marker: an arrowhead turned to face the way they look.
static func draw_player(canvas: CanvasItem, at: Vector2, facing: Vector2, size: float = 22.0) -> void:
	var angle := (facing if facing != Vector2.ZERO else Vector2.DOWN).angle() + PI / 2.0
	canvas.draw_set_transform(at, angle, Vector2.ONE)
	canvas.draw_texture_rect(texture("player"), Rect2(-Vector2(size, size) / 2.0, Vector2(size, size)), false)
	canvas.draw_set_transform(Vector2.ZERO)
