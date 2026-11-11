class_name Mount
extends AnimatedSprite2D
## The beast under the player while riding. Mounts are summoned with a
## whistle; each is faster than walking and some have gifts of their own.

const MOUNTS := {
	"pony": {"name": "Pony", "sheet": "horse", "speed": 1.4, "tint": Color(0.95, 0.85, 0.7), "scale": 1.15, "text": "Sturdy and willing. 40% faster than walking."},
	"horse": {"name": "Horse", "sheet": "horse", "speed": 1.65, "tint": Color.WHITE, "scale": 1.35, "text": "A proper steed. 65% faster than walking."},
	"frost_elk": {"name": "Frost Elk", "sheet": "frost_elk", "speed": 1.6, "tint": Color.WHITE, "scale": 1.35, "snow": true, "text": "60% faster; snow and blizzards do not slow or chill it."},
	"sand_strider": {"name": "Sand Strider", "sheet": "horse", "speed": 1.6, "tint": Color(1.0, 0.85, 0.55), "scale": 1.35, "sand": true, "text": "60% faster; sand and sandstorms do not slow it."},
	"nightmare": {"name": "Nightmare", "sheet": "horse", "speed": 1.95, "tint": Color(0.3, 0.25, 0.35), "scale": 1.4, "steady": true, "text": "95% faster, and blows do not knock you from the saddle."},
}
## How high the rider sits.
const SEAT := 21.0

var _player: Player
var _id := ""


func setup(player: Player) -> void:
	_player = player
	z_index = -1
	visible = false


func ride(id: String) -> void:
	_id = id
	var data: Dictionary = MOUNTS[id]
	sprite_frames = SheetAnimations.build(load("res://assets/sprites/mounts/%s.png" % data["sheet"]), 96, EnemyAnimator.ROWS)
	modulate = data["tint"]
	scale = Vector2(data["scale"], data["scale"])
	position = Vector2(0, -23.0 * data["scale"] + 4.0)
	visible = true
	play("idle")


func put_away() -> void:
	visible = false
	_id = ""


func _process(_delta: float) -> void:
	if not visible:
		return
	var moving := _player.velocity.length() > 20.0
	var wanted := "walk" if moving else "idle"
	if animation != wanted:
		play(wanted)
	speed_scale = clampf(_player.velocity.length() / 160.0, 0.6, 2.0) if moving else 1.0
	if absf(_player.velocity.x) > 5.0:
		flip_h = _player.velocity.x < 0.0
