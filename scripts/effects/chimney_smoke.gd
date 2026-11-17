class_name ChimneySmoke
extends Node2D
## A thread of smoke from a lived-in house: soft square puffs, kept on the
## pixel grid, rising and drifting with the wind, thinning as they go.

const MAX_PUFFS := 7

## [offset, age, life, size]
var _puffs: Array = []
var _wind := 0.0


func _ready() -> void:
	z_index = 2
	_wind = randf_range(4.0, 9.0) * (1.0 if randf() < 0.6 else -1.0)


func _process(delta: float) -> void:
	if randf() < delta * 1.8 and _puffs.size() < MAX_PUFFS:
		_puffs.append([Vector2(randf_range(-1.0, 1.0), 0.0), 0.0, randf_range(2.4, 3.4), randf_range(2.0, 3.0)])
	for puff: Array in _puffs:
		puff[1] += delta
		var offset: Vector2 = puff[0]
		offset.y -= delta * 11.0
		offset.x += delta * _wind * (puff[1] / puff[2])
		puff[0] = offset
	_puffs = _puffs.filter(func(p: Array) -> bool: return p[1] < p[2])
	queue_redraw()


func _draw() -> void:
	for puff: Array in _puffs:
		var t: float = puff[1] / puff[2]
		var size := roundf(float(puff[3]) * (1.0 + t * 1.6))
		var at: Vector2 = (puff[0] as Vector2).round()
		var shade := lerpf(0.62, 0.78, t)
		draw_rect(Rect2(at - Vector2(size, size) / 2.0, Vector2(size, size)), Color(shade, shade, shade + 0.04, 0.42 * (1.0 - t)))
