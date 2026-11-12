class_name SlashEffect
extends Node2D
## The swoosh of a melee swing: a pixel-art crescent that sweeps and fades.
##
## Wide swings (over 200 degrees) use a full-circle swoosh instead. Each
## kind of weapon swings in its own way (see `play_weapon`): greatswords
## cleave a wide, heavy arc that kicks up dust, daggers cross two quick
## cuts, spears thrust a straight streak, axes chop with flying chips. A
## weapon with an element trails its own particles: embers, frost, venom,
## shadow or light.

const CRESCENT: Texture2D = preload("res://assets/effects/slash.png")
const SPIN: Texture2D = preload("res://assets/effects/spin.png")
const FRAMES := 6
## Radius of the art in its texture, and the arc the crescent was drawn at.
const ART_RADIUS := 29.0
const ART_ARC := deg_to_rad(130.0)
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

var _sprite: Sprite2D
## A bright, additive copy inside the swoosh: the hot edge of the blade.
var _core: Sprite2D
## A second, crossing cut for quick weapons.
var _echo: Sprite2D
var _sparks: CPUParticles2D
## Dust for heavy blows, chips for chops.
var _debris: CPUParticles2D
var _element: CPUParticles2D
var _tween: Tween
var _flip := false
## A thrust or punch drawn by hand: its style, reach, colour and progress.
var _drawn := ""
var _reach := 0.0
var _color := Color.WHITE
var _t := 1.0


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.hframes = FRAMES
	_sprite.visible = false
	add_child(_sprite)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_core = Sprite2D.new()
	_core.hframes = FRAMES
	_core.visible = false
	_core.material = additive
	add_child(_core)
	_echo = Sprite2D.new()
	_echo.hframes = FRAMES
	_echo.visible = false
	_echo.material = additive
	add_child(_echo)
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
	particles.amount = amount
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
	particles.scale_amount_max = 2.0
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
			_draw_strike(style[0], direction, radius, duration, color)
		_:
			play(direction, radius, arc_radians * style[2], duration, color)
	match style[0]:
		"heavy":
			# A cleave that throws up dust where it lands.
			_burst(_debris, Vector2(radius * 0.85, 0), Color(0.62, 0.58, 0.52, 0.8), Vector2(0, 160), 10)
			_core.scale *= 1.05
		"chop":
			_burst(_debris, Vector2(radius * 0.8, 0), Color(0.55, 0.45, 0.35), Vector2(0, 320), 7)
		"quick":
			# A second cut across the first, a beat later.
			_echo.texture = CRESCENT
			_echo.frame = 0
			_echo.scale = Vector2(_sprite.scale.x * 0.85, -_sprite.scale.y * 0.85)
			_echo.rotation = deg_to_rad(18.0 if _flip else -18.0)
			_echo.modulate = Color(color.lightened(0.45), 0.85)
			_echo.visible = false
			var echo := create_tween()
			echo.tween_interval(duration * 0.35)
			echo.tween_callback(_echo.show)
			echo.tween_property(_echo, "frame", FRAMES - 1, duration * 0.6)
			echo.parallel().tween_property(_echo, "modulate:a", 0.0, duration * 0.6)
			echo.tween_callback(_echo.hide)
	if ELEMENTS.has(element):
		var look: Array = ELEMENTS[element]
		_element.amount = look[2]
		_burst(_element, Vector2(radius * 0.7, 0), look[0], Vector2(0, look[1]), look[2])
		_element.emission_sphere_radius = radius * 0.35


func _burst(particles: CPUParticles2D, at: Vector2, color: Color, gravity: Vector2, amount: int) -> void:
	particles.position = at
	particles.color = color
	particles.gravity = gravity.rotated(-rotation)
	particles.amount = maxi(1, amount)
	particles.restart()
	particles.emitting = true


## A thrust: a straight streak shooting out to the spear's reach with a
## flash at the point. A punch: a short burst of rings.
func _draw_strike(style: String, direction: Vector2, radius: float, duration: float, color: Color) -> void:
	rotation = direction.angle()
	_drawn = style
	_reach = radius
	_color = color
	_t = 0.0
	_sprite.hide()
	_core.hide()
	_sparks.position = Vector2(radius, 0)
	_sparks.color = color.lightened(0.4)
	_sparks.restart()
	_sparks.emitting = true
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "_t", 1.0, duration)
	_tween.tween_callback(func() -> void: _drawn = "")


func _process(_delta: float) -> void:
	if _drawn != "":
		queue_redraw()


func _draw() -> void:
	if _drawn == "":
		return
	var fade := 1.0 - _t
	if _drawn == "thrust":
		# The streak runs out fast, then thins away from the back.
		var front := _reach * minf(1.0, _t * 2.4)
		var back := _reach * clampf(_t * 1.6 - 0.25, 0.15, 0.95)
		var width := 7.0 * fade + 1.0
		var shaft := PackedVector2Array([Vector2(back, -width * 0.35), Vector2(front - 6.0, -width / 2.0), Vector2(front + 4.0, 0), Vector2(front - 6.0, width / 2.0), Vector2(back, width * 0.35)])
		draw_colored_polygon(shaft, Color(_color, 0.55 * fade))
		draw_line(Vector2(back, 0), Vector2(front + 2.0, 0), Color(_color.lightened(0.6), 0.9 * fade), 2.0)
		for k in 3:
			var y := (k - 1) * 7.0
			draw_line(Vector2(back * 0.7 + k * 6.0, y), Vector2(back * 0.7 + k * 6.0 + 14.0, y), Color(_color, 0.35 * fade), 1.0)
		if _t < 0.5:
			draw_circle(Vector2(front + 2.0, 0), 5.0 * (1.0 - _t * 2.0) + 1.0, Color(1, 1, 1, 0.8 * (1.0 - _t * 2.0)))
	else:
		var center := Vector2(_reach * 0.75, 0)
		draw_arc(center, 4.0 + _t * 12.0, 0.0, TAU, 16, Color(_color, 0.7 * fade), 2.0)
		draw_arc(center, 2.0 + _t * 6.0, 0.0, TAU, 12, Color(1, 1, 1, 0.6 * fade), 1.5)


func play(
	direction: Vector2, radius: float, arc_radians: float, duration: float,
	color: Color = Color(0.95, 0.9, 0.8)
) -> void:
	_drawn = ""
	queue_redraw()
	var full_circle := arc_radians > deg_to_rad(200.0)
	_sprite.texture = SPIN if full_circle else CRESCENT
	_sprite.frame = 0
	_sprite.visible = true
	_sprite.modulate = color
	rotation = direction.angle()
	var size := radius / ART_RADIUS
	# Narrow thrusts squeeze the crescent; alternate swings mirror it.
	var squeeze := 1.0 if full_circle else clampf(arc_radians / ART_ARC, 0.4, 1.25)
	_flip = not _flip
	_sprite.scale = Vector2(size, size * squeeze * (-1.0 if _flip and not full_circle else 1.0))
	_core.texture = _sprite.texture
	_core.frame = 0
	_core.visible = true
	_core.scale = _sprite.scale * 0.92
	_core.modulate = Color(color.lightened(0.5), 0.75)
	_sparks.position = Vector2(radius * 0.8, 0)
	_sparks.color = color.lightened(0.4)
	_sparks.gravity = Vector2.ZERO
	_sparks.restart()
	_sparks.emitting = true
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel()
	_tween.tween_property(_sprite, "frame", FRAMES - 1, duration)
	_tween.tween_property(_core, "frame", FRAMES - 1, duration)
	_tween.tween_property(_core, "modulate:a", 0.0, duration * 0.8)
	_tween.chain().tween_callback(func() -> void:
		_sprite.hide()
		_core.hide()
	)


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
