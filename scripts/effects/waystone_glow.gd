class_name WaystoneGlow
extends Node2D
## What an awake waystone does: a ring of runes glowing on the ground round
## its plinth and slowly turning, a crystal floating over the socket in its
## crown, bobbing and turning, and motes of light drifting up. All in hard
## pixel steps, in the stones' cold blue.

const COLOR := Color(0.55, 0.92, 1.0)
const RING := 40.0
const CRYSTAL_HEIGHT := -62.0

var _age := 0.0
## [x, y, age, life]
var _motes: Array = []


var _ring: Node2D


func _ready() -> void:
	z_index = 1
	_age = randf() * 10.0
	# The ring lies on the ground, under the plinth and everything standing.
	_ring = Node2D.new()
	_ring.z_as_relative = false
	_ring.z_index = -7
	_ring.draw.connect(_draw_ring)
	add_child(_ring)


func _process(delta: float) -> void:
	_age += delta
	if randf() < delta * 5.0:
		_motes.append([randf_range(-16.0, 16.0), randf_range(-8.0, 4.0), 0.0, randf_range(1.2, 2.2)])
	for mote: Array in _motes:
		mote[2] += delta
	_motes = _motes.filter(func(m: Array) -> bool: return m[2] < m[3])
	queue_redraw()
	_ring.queue_redraw()


## The rune ring, flattened onto the ground and slowly turning: dashes of
## light with a brighter rune mark every sixth.
func _draw_ring() -> void:
	var pulse := 0.65 + 0.35 * sin(_age * 2.0)
	var steps := 60
	for i in steps:
		var a := TAU * i / steps + _age * 0.25
		var at := Vector2(cos(a) * RING, sin(a) * RING * 0.42 + 4.0).round()
		if i % 6 == 0:
			_ring.draw_rect(Rect2(at - Vector2(1, 1), Vector2(3, 3)), Color(1.4, 1.8, 2.0, pulse))
		elif i % 2 == 0:
			_ring.draw_rect(Rect2(at, Vector2(2, 2)), Color(COLOR * 1.5, 0.75 * pulse))


func _draw() -> void:
	var pulse := 0.65 + 0.35 * sin(_age * 2.0)
	# The crystal: a pixel diamond turning (its width breathing) over the socket.
	var bob := roundf(sin(_age * 1.6) * 3.0)
	var top := Vector2(0, CRYSTAL_HEIGHT + bob)
	var half := maxf(1.0, roundf(absf(cos(_age * 1.2)) * 4.0))
	for row in 12:
		var t := float(row) / 11.0
		var w := roundf(half * (1.0 - absf(t - 0.4) / 0.6))
		if w < 0.5:
			w = 0.5
		var shade := COLOR.lightened(0.5) if row < 5 else COLOR.darkened(0.15)
		draw_rect(Rect2(top + Vector2(-w, row), Vector2(w * 2.0, 1)), shade)
	draw_rect(Rect2(top + Vector2(-1, 2), Vector2(1, 2)), Color.WHITE)
	# A faint shaft between crystal and socket.
	draw_rect(Rect2(Vector2(-1, CRYSTAL_HEIGHT + 12 + bob), Vector2(2, 10 - bob)), Color(COLOR, 0.25 * pulse))
	# Motes drifting up.
	for mote: Array in _motes:
		var t: float = mote[2] / mote[3]
		draw_rect(Rect2(Vector2(mote[0], mote[1] - t * 46.0).round(), Vector2(2, 2)), Color(COLOR.lightened(0.3), (1.0 - t) * 0.8))
