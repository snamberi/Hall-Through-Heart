class_name Mount
extends AnimatedSprite2D
## The beast under the player while riding. Mounts are summoned with a
## whistle; each is faster than walking and some have gifts of their own.
##
## Each mount is drawn at its own size (tools/generate_mounts.py), never
## stretched. A second sheet holds its near side (flank, saddle, a boot in
## the stirrup), drawn over the rider, so the rider sits in the saddle
## rather than standing on the beast's back.

const MOUNTS := {
	"pony": {"name": "Pony", "sheet": "pony", "speed": 1.4, "seat": 20.0, "text": "Sturdy and willing. 40% faster than walking."},
	"horse": {"name": "Horse", "sheet": "horse", "speed": 1.65, "seat": 26.0, "text": "A proper steed. 65% faster than walking."},
	"frost_elk": {"name": "Frost Elk", "sheet": "frost_elk", "speed": 1.6, "seat": 26.0, "snow": true, "text": "60% faster; snow and blizzards do not slow or chill it."},
	"sand_strider": {"name": "Sand Strider", "sheet": "sand_strider", "speed": 1.6, "seat": 26.0, "sand": true, "text": "60% faster; sand and sandstorms do not slow it."},
	"nightmare": {"name": "Nightmare", "sheet": "nightmare", "speed": 1.95, "seat": 27.0, "steady": true, "text": "95% faster, and blows do not knock you from the saddle."},
}
## The rows of a mount's sheet: a beast's usual ones and a gallop.
const ROWS: Array[Dictionary] = [
	{"name": "idle", "frames": 4, "fps": 5.0, "loop": true},
	{"name": "walk", "frames": 8, "fps": 10.0, "loop": true},
	{"name": "windup", "frames": 6, "fps": 13.0, "loop": false},
	{"name": "lunge", "frames": 6, "fps": 16.0, "loop": false},
	{"name": "hurt", "frames": 3, "fps": 12.0, "loop": false},
	{"name": "death", "frames": 8, "fps": 10.0, "loop": false},
	{"name": "gallop", "frames": 6, "fps": 11.0, "loop": true},
]
## How high the rider sits on the average mount (see seat()).
const SEAT := 26.0
## Above this speed a walk becomes a gallop.
const GALLOP_SPEED := 190.0

var _player: Player
var _id := ""
var _front: AnimatedSprite2D


## How high the rider sits on a mount.
static func seat(id: String) -> float:
	return float(MOUNTS.get(id, {}).get("seat", SEAT))


func setup(player: Player) -> void:
	_player = player
	z_index = -1
	visible = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_front = AnimatedSprite2D.new()
	# Over the rider: the mount itself sits one below them.
	_front.z_index = 2
	_front.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_front)


func ride(id: String) -> void:
	_id = id
	var data: Dictionary = MOUNTS[id]
	sprite_frames = SheetAnimations.build(load("res://assets/sprites/mounts/%s.png" % data["sheet"]), 96, ROWS)
	_front.sprite_frames = SheetAnimations.build(load("res://assets/sprites/mounts/%s_front.png" % data["sheet"]), 96, ROWS)
	modulate = Color.WHITE
	scale = Vector2.ONE
	position = Vector2(2.0, -19.0)
	visible = true
	_play("idle")


func put_away() -> void:
	visible = false
	_id = ""


func _play(wanted: String) -> void:
	if animation != wanted:
		play(wanted)
		_front.play(wanted)


func _process(_delta: float) -> void:
	if not visible:
		return
	var speed := _player.velocity.length()
	var wanted := "idle"
	if speed > 20.0:
		wanted = "gallop" if speed > GALLOP_SPEED else "walk"
	_play(wanted)
	speed_scale = clampf(speed / (240.0 if wanted == "gallop" else 160.0), 0.6, 2.0) if speed > 20.0 else 1.0
	_front.speed_scale = speed_scale
	# The two sheets stay on the same frame.
	if _front.frame != frame:
		_front.frame = frame
	if absf(_player.velocity.x) > 5.0:
		flip_h = _player.velocity.x < 0.0
		_front.flip_h = flip_h
		# The saddle sits a little behind the middle of the beast.
		position.x = -2.0 if flip_h else 2.0
