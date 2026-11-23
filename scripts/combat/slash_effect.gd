class_name SlashEffect
extends Node2D
## The swoosh of a melee swing: a crescent of whole pixels that sweeps and
## fades, never a turned or stretched picture.
##
## Wide swings (over 200 degrees) use a full-circle swoosh instead. Each
## kind of weapon swings in its own way (see `play_weapon`): greatswords
## cleave a wide, heavy arc that kicks up dust, daggers cross two quick
## cuts, spears thrust a straight streak, axes chop with flying chips. A
## weapon with an element trails its own particles: embers, frost, venom,
## shadow or light.

## How each weapon type swings: [style, reach scale, arc scale, time scale].
const STYLES := {
	"swords": ["sword", 1.0, 1.0, 1.0], "greatswords": ["heavy", 1.12, 1.15, 1.3], "axes": ["chop", 1.0, 0.85, 1.1],
	"daggers": ["quick", 0.82, 0.8, 0.7], "spears": ["thrust", 1.05, 0.5, 0.9], "unarmed": ["punch", 0.8, 0.8, 0.8],
}
## Particle looks for each element: [colour, upward drift, count].
const ELEMENTS := {
	"fire": [Color(1.0, 0.62, 0.22), -90.0, 12], "frost": [Color(0.7, 0.92, 1.0), 30.0, 10], "poison": [Color(0.5, 0.95, 0.35), 220.0, 10],
	"shadow": [Color(0.62, 0.4, 0.95), -40.0, 12], "holy": [Color(1.0, 0.92, 0.55), -20.0, 12], "blood": [Color(0.9, 0.2, 0.22), 260.0, 8],
}

var _sparks: CPUParticles2D
## Dust for heavy blows, chips for chops.
var _debris: CPUParticles2D
var _element: CPUParticles2D
## Alternate swings come from the other side.
var _flip := false
## What is being drawn: "swing", "spin", "thrust" or "punch" ("" for
## nothing), its direction, reach, arc, colour, how far through it is (0 to
## 1), and its style ("sword", "heavy", "chop", "quick"...).
var _drawn := ""
var _dir := Vector2.RIGHT
var _reach := 0.0
var _arc := 0.0
var _color := Color.WHITE
var _t := 1.0
var _duration := 0.2
var _style := "sword"


func _ready() -> void:
	# Never turned or stretched: every pixel of a swing is placed by hand,
	# square and on the grid, whichever way it points.
	rotation = 0.0
	_sparks = _particles(8, 0.25, 80.0, 160.0)
	_debris = _particles(10, 0.45, 40.0, 110.0)
	_debris.gravity = Vector2(0, 260)
	_element = _particles(12, 0.6, 20.0, 70.0)
	_element.damping_min = 40.0
	_element.damping_max = 80.0


func _particles(amount: int, lifetime: float, speed_min: float, speed_max: float) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.amount = GameSettings.particle_amount(amount)
	particles.lifetime = lifetime
	particles.explosiveness = 0.7
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 6.0
	particles.direction = Vector2.RIGHT
	particles.spread = 70.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = speed_min
	particles.initial_velocity_max = speed_max
	particles.damping_min = 300.0
	particles.damping_max = 400.0
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 1.0
	add_child(particles)
	return particles


## A basic attack with the weapon in hand: its type sets the swing's shape
## and the element (if any) its particles.
func play_weapon(type: String, element: String, direction: Vector2, radius: float, arc_radians: float, duration: float, color: Color) -> void:
	var style: Array = STYLES.get(type, STYLES["swords"])
	radius *= style[1]
	duration *= style[3]
	match style[0]:
		"thrust", "punch":
			_start(style[0], style[0], direction, radius, 0.0, duration, color)
		_:
			play(direction, radius, arc_radians * style[2], duration, color)
			_style = style[0]
	match style[0]:
		"heavy":
			# A cleave that throws up dust where it lands.
			_burst(_debris, _dir * radius * 0.85, Color(0.62, 0.58, 0.52, 0.8), Vector2(0, 160), 10)
		"chop":
			_burst(_debris, _dir * radius * 0.8, Color(0.55, 0.45, 0.35), Vector2(0, 320), 7)
	if ELEMENTS.has(element):
		var look: Array = ELEMENTS[element]
		_element.emission_sphere_radius = radius * 0.35
		_burst(_element, _dir * radius * 0.7, look[0], Vector2(0, look[1]), look[2])


func _burst(particles: CPUParticles2D, at: Vector2, color: Color, gravity: Vector2, amount: int) -> void:
	particles.position = at
	particles.direction = _dir
	particles.color = color
	particles.gravity = gravity
	particles.amount = GameSettings.particle_amount(maxi(1, amount))
	particles.restart()
	particles.emitting = true


func _start(kind: String, style: String, direction: Vector2, radius: float, arc: float, duration: float, color: Color) -> void:
	_drawn = kind
	_style = style
	_dir = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	_reach = radius
	_arc = arc
	_color = color
	_duration = maxf(duration, 0.05)
	_t = 0.0
	_burst(_sparks, _dir * radius * 0.8, color.lightened(0.4), Vector2.ZERO, 8)
	queue_redraw()


## A swing: the blade's path drawn as a crescent that sweeps across the
## arc, thick and bright at its head, thinning and fading along its tail.
## Swings over 200 degrees go all the way round.
func play(
	direction: Vector2, radius: float, arc_radians: float, duration: float,
	color: Color = Color(0.95, 0.9, 0.8)
) -> void:
	_flip = not _flip
	var full_circle := arc_radians > deg_to_rad(200.0)
	_start("spin" if full_circle else "swing", "sword", direction, radius, arc_radians, duration, color)


func _process(delta: float) -> void:
	if _drawn == "":
		return
	rotation = 0.0
	_t += delta / _duration
	if _t >= 1.0:
		_drawn = ""
	queue_redraw()


func _px(at: Vector2, c: Color) -> void:
	draw_rect(Rect2(at.floor(), Vector2.ONE), c)


func _draw() -> void:
	if _drawn == "":
		return
	match _drawn:
		"swing", "spin":
			_draw_swing()
			if _style == "quick" and _t > 0.3:
				# Daggers: a second, smaller cut across the first.
				_draw_crescent(clampf((_t - 0.3) / 0.7, 0.0, 1.0), _reach * 0.82, _arc * 0.8, not _flip, 3.0, 0.85)
		"thrust":
			_draw_thrust()
		"punch":
			_draw_punch()


func _draw_swing() -> void:
	var thick := 6.0
	match _style:
		"heavy":
			thick = 9.0
		"chop":
			thick = 7.0
		"quick":
			thick = 4.0
	if _drawn == "spin":
		_draw_crescent(_t, _reach, TAU, _flip, thick, 1.0, true)
	else:
		_draw_crescent(_t, _reach, _arc, _flip, thick, 1.0)


## One crescent at progress t: the head sweeps out fast and eases in, the
## tail follows; `thick` pixels deep at the head.
func _draw_crescent(t: float, reach: float, arc: float, mirrored: bool, thick: float, alpha: float, round_trip: bool = false) -> void:
	var sweep := 1.0 - pow(1.0 - minf(t * 1.5, 1.0), 3.0)
	var side := -1.0 if mirrored else 1.0
	var start := -arc / 2.0
	var head := start + arc * sweep
	var trail := arc * (0.75 if not round_trip else 0.5) * (1.0 - maxf(0.0, t - 0.5) * 1.6)
	var tail := maxf(start, head - trail)
	if head - tail <= 0.01:
		return
	var fade := alpha * clampf(1.4 - t * 1.4, 0.0, 1.0)
	var lit := _color.lightened(0.55)
	var deep := _color.darkened(0.25)
	# Walk the band one pixel at a time along its outer edge.
	var steps := int((head - tail) * reach) + 1
	for i in steps:
		var a := tail + (head - tail) * float(i) / steps
		var share := float(i) / steps
		var depth := maxf(1.0, roundf(thick * pow(share, 0.7)))
		var dir := _dir.rotated(a * side)
		for k in int(depth):
			var c: Color
			if k == 0:
				c = Color(lit, fade * (0.4 + 0.6 * share))
			elif k == int(depth) - 1:
				c = Color(deep, fade * 0.5 * share)
			else:
				c = Color(_color, fade * (0.25 + 0.6 * share))
			_px(dir * (reach - k), c)
	# A glint at the blade's tip while it travels.
	if t < 0.6:
		var tip := _dir.rotated(head * side) * reach
		_px(tip, Color(1, 1, 1, fade))
		_px(tip + _dir.rotated(head * side) * -1.0, Color(1, 1, 1, fade * 0.7))


## A spear's thrust: a streak that shoots out to its reach and thins away
## from the back, speed lines beside it, a star at the point.
func _draw_thrust() -> void:
	var fade := 1.0 - _t
	var front := _reach * minf(1.0, _t * 2.4)
	var back := _reach * clampf(_t * 1.6 - 0.25, 0.15, 0.95)
	var side := Vector2(-_dir.y, _dir.x)
	var width := int(3.0 * fade) + 1
	var k := back
	while k <= front:
		var along := (k - back) / maxf(front - back, 1.0)
		for w in range(-width, width + 1):
			if absi(w) > int(width * (0.3 + 0.7 * along)):
				continue
			var c := Color(_color.lightened(0.6), 0.9 * fade) if w == 0 else Color(_color, 0.5 * fade)
			_px(_dir * k + side * w, c)
		k += 1.0
	for lane in [-6.0, 6.0]:
		for j in 10:
			_px(_dir * (back * 0.7 + j * 1.5) + side * lane, Color(_color, 0.35 * fade))
	if _t < 0.5:
		var star := _dir * (front + 2.0)
		var size := int(4.0 * (1.0 - _t * 2.0)) + 1
		for j in range(-size, size + 1):
			_px(star + Vector2(j, 0), Color(1, 1, 1, 0.85 * (1.0 - _t * 2.0)))
			_px(star + Vector2(0, j), Color(1, 1, 1, 0.85 * (1.0 - _t * 2.0)))


## A punch: two rings of pixels bursting out where the fist lands.
func _draw_punch() -> void:
	var fade := 1.0 - _t
	var centre := _dir * _reach * 0.75
	for ring in 2:
		var r := (4.0 + _t * 12.0) if ring == 0 else (2.0 + _t * 6.0)
		var c := Color(_color, 0.75 * fade) if ring == 0 else Color(1, 1, 1, 0.6 * fade)
		var steps := maxi(8, int(TAU * r))
		for i in steps:
			if ring == 0 and i % 4 == 3:
				continue
			_px(centre + Vector2.from_angle(TAU * i / steps) * r, c)


## The element a weapon fights with, for its particles: the strongest
## elemental damage it carries, or what its hits inflict.
static func element_of(item: Item) -> String:
	if item == null:
		return ""
	var best := ""
	var most := 0.0
	for modifier in item.all_modifiers():
		var stat: String = modifier["stat"]
		if stat.ends_with("_damage") and stat.trim_suffix("_damage") in Elements.LIST and float(modifier["value"]) > most:
			most = float(modifier["value"])
			best = stat.trim_suffix("_damage")
	if best != "":
		return best
	var on_hit: Dictionary = item.definition().get("on_hit", {})
	return {"burn": "fire", "chill": "frost", "poison": "poison", "bleed": "blood"}.get(on_hit.get("status", ""), "")
