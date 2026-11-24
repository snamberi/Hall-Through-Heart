extends Node2D
## Rain drawn in whole pixels: thin streaks stepping sideways with the wind,
## never rotated or smeared, in three layers (far drops short, dim and slow;
## near drops long, bright and quick), the lowest pixel of each a little
## brighter where it catches the light. A storm brings more of them, longer
## and slanting harder. Atmosphere makes it a child of the player and sets
## `power` (0 dry, 1 rain, 2 storm). (Loaded by path.)

## Half the size of the patch of sky kept full of rain, around the player.
const EXTENT := Vector2(440, 280)
## Per layer: length in pixels, speed (pixels a second), alpha.
const LAYERS := [[5, 380.0, 0.3], [8, 540.0, 0.46], [12, 720.0, 0.66]]
const COLOUR := Color(0.72, 0.82, 1.0)

var power := 0.0
## Drops striking the ground: [x, y, age]. Each is a few frames of whole
## pixels: a bright point, a crown thrown up and out, a ring fading away.
var _splashes: Array[Vector3] = []
var _splash_debt := 0.0
const SPLASH_SECONDS := 0.27
## Sideways pixels for each pixel fallen.
var slant := 0.12
var _drops: Array[Vector3] = []


func _ready() -> void:
	top_level = true
	z_index = 40


func _process(delta: float) -> void:
	var wanted := 0 if power <= 0.0 else roundi((360.0 if power < 1.5 else 600.0) * GameSettings.weather_share())
	var centre: Vector2 = (get_parent() as Node2D).global_position if get_parent() is Node2D else Vector2.ZERO
	while _drops.size() < wanted:
		_drops.append(Vector3(centre.x + randf_range(-EXTENT.x, EXTENT.x), centre.y + randf_range(-EXTENT.y, EXTENT.y), randi() % LAYERS.size()))
	if _drops.size() > wanted:
		_drops.resize(wanted)
	visible = wanted > 0
	if not visible:
		_splashes.clear()
		return
	# Splashes on the ground round the player, more in a storm.
	_splash_debt += delta * (150.0 if power >= 1.5 else 80.0) * GameSettings.weather_share()
	while _splash_debt >= 1.0:
		_splash_debt -= 1.0
		_splashes.append(Vector3(roundf(centre.x + randf_range(-EXTENT.x, EXTENT.x)), roundf(centre.y + randf_range(-EXTENT.y, EXTENT.y)), 0.0))
	for i in range(_splashes.size() - 1, -1, -1):
		var splash := _splashes[i]
		splash.z += delta
		if splash.z >= SPLASH_SECONDS:
			_splashes.remove_at(i)
		else:
			_splashes[i] = splash
	var storm := 1.25 if power >= 1.5 else 1.0
	for i in _drops.size():
		var drop := _drops[i]
		var speed: float = LAYERS[int(drop.z)][1] * storm
		drop.y += speed * delta
		drop.x += speed * slant * delta
		# Keep every drop in the patch round the player, wrapping at its edges.
		drop.x = centre.x - EXTENT.x + fposmod(drop.x - (centre.x - EXTENT.x), EXTENT.x * 2.0)
		drop.y = centre.y - EXTENT.y + fposmod(drop.y - (centre.y - EXTENT.y), EXTENT.y * 2.0)
		_drops[i] = drop
	queue_redraw()


func _draw() -> void:
	var storm := 1.4 if power >= 1.5 else 1.0
	for drop in _drops:
		var layer: Array = LAYERS[int(drop.z)]
		var length := roundi(float(layer[0]) * storm)
		var colour := Color(COLOUR, float(layer[2]))
		var head := Vector2(floorf(drop.x), floorf(drop.y))
		# A run of 1px-wide segments, each a pixel further over: a slant in
		# whole pixels.
		var steps := roundi(length * slant)
		var segment := maxi(1, ceili(float(length) / float(steps + 1)))
		var y := 0
		var x := 0
		while y < length:
			var tall := mini(segment, length - y)
			draw_rect(Rect2(head + Vector2(x, y - length), Vector2(1, tall)), colour)
			y += tall
			x += 1
		draw_rect(Rect2(head + Vector2(x - 1, -1), Vector2(1, 1)), Color(1, 1, 1, float(layer[2]) + 0.15))
	for splash in _splashes:
		var at := Vector2(splash.x, splash.y)
		var frame := int(splash.z / SPLASH_SECONDS * 3.0)
		var fade := 1.0 - splash.z / SPLASH_SECONDS
		var bright := Color(0.86, 0.92, 1.0, 0.75 * fade)
		var dim := Color(COLOUR, 0.45 * fade)
		match frame:
			0:
				draw_rect(Rect2(at, Vector2(1, 1)), bright)
			1:
				# The crown: droplets thrown up and to each side.
				draw_rect(Rect2(at + Vector2(-1, 0), Vector2(1, 1)), bright)
				draw_rect(Rect2(at + Vector2(1, 0), Vector2(1, 1)), bright)
				draw_rect(Rect2(at + Vector2(-2, -1), Vector2(1, 1)), dim)
				draw_rect(Rect2(at + Vector2(2, -1), Vector2(1, 1)), dim)
				draw_rect(Rect2(at + Vector2(0, -2), Vector2(1, 1)), dim)
			_:
				# A flat ring spreading, wider than tall (seen at a slant).
				for offset: Vector2 in [Vector2(-3, 0), Vector2(3, 0), Vector2(-2, -1), Vector2(2, -1), Vector2(-2, 1), Vector2(2, 1), Vector2(0, -1), Vector2(0, 1)]:
					draw_rect(Rect2(at + offset, Vector2(1, 1)), dim)
