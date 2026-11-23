class_name RingBurst
extends Node2D
## A pixel shockwave ring that grows and breaks apart. Drawn a whole pixel
## at a time at whatever size it reaches (never a scaled picture, so the
## pixels stay square): a thick bright band at first, thinning as it
## spreads, gaps opening along it until only scattered pixels are left.

const LIFE := 0.42

var radius := 90.0
var colour := Color.WHITE
var _time := 0.0
## Where along the ring the gaps open, so each ring breaks its own way.
var _seed := 0.0


static func spawn(parent: Node, at: Vector2, color: Color, max_radius: float = 90.0) -> void:
	var ring := RingBurst.new()
	ring.position = at.round()
	ring.colour = color
	ring.radius = max_radius
	ring.z_index = 50
	ring._seed = randf() * 100.0
	parent.add_child(ring)


func _process(delta: float) -> void:
	_time += delta
	if _time >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _time / LIFE
	var grow := 1.0 - pow(1.0 - t, 3.0)
	var r := maxf(3.0, radius * (0.2 + 0.8 * grow))
	var thick := 3 if t < 0.3 else 2 if t < 0.65 else 1
	var alpha := 1.0 - t * t
	# The ground inside glows faintly at first.
	if t < 0.35:
		_ring(r * 0.55, 1, Color(colour, 0.25 * (1.0 - t / 0.35)), 0.0)
	_ring(r, thick, Color(colour, alpha), t)
	# A pale inner edge, the light catching the front of the wave.
	if t < 0.6:
		_ring(r - thick, 1, Color(colour.lightened(0.55), alpha * 0.8), t)


## Whole-pixel ring of radius r, `width` pixels thick; `broken` (0 to 1)
## opens gaps along it.
func _ring(r: float, width: int, c: Color, broken: float) -> void:
	var steps := maxi(12, int(TAU * r))
	for i in steps:
		var angle := TAU * i / steps
		if broken > 0.35:
			var gap := sin(angle * 7.0 + _seed) + sin(angle * 13.0 + _seed * 1.7)
			if gap > 1.6 - broken * 2.2:
				continue
		var dir := Vector2(cos(angle), sin(angle) * 0.8)
		for k in width:
			draw_rect(Rect2((dir * (r - k)).floor(), Vector2.ONE), c)
