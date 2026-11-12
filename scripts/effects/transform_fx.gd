class_name TransformFX
extends Node2D
## What gathers around the player while they hold the key to transform:
## the world dims at the edges, motes spiral inward, rings close in and a
## pillar of light grows, faster and brighter as the moment nears.
##
## Each form has its own build-up and burst on top: fur and claw marks for
## the werewolf, orbiting stones and cracked ground for the golem, feathers
## and lightning for the harpy, smoke for the wraith, creeping roots and
## leaves for the treant, rising flame for the fiend, ice spikes for the
## troll, and a rift that pulls everything in for the void stalker.

var color := Color(0.9, 0.4, 0.3)
var seconds := 4.0
## Which form this is for (Transformations.FORMS).
var form := ""

var _time := 0.0
var _ending := 0.0
var _burst := false
## [angle, radius share, speed, size]
var _motes: Array = []
## The form's own pieces: [angle, distance, size, phase].
var _bits: Array = []
## Lightning or claw strokes, rebuilt now and then.
var _strokes: Array = []
var _stroke_left := 0.0


func _ready() -> void:
	z_index = 30
	for k in 46:
		_motes.append([randf() * TAU, randf_range(0.35, 1.0), randf_range(0.6, 1.6), randf_range(1.5, 3.2)])
	for k in 18:
		_bits.append([k * TAU / 18.0 + randf_range(-0.15, 0.15), randf_range(40.0, 110.0), randf_range(3.0, 7.0), randf()])


## The key was let go: fade away.
func cancel() -> void:
	if _ending == 0.0:
		_ending = 0.001


## The change happened: one bright beat, then gone.
func burst() -> void:
	_burst = true
	_ending = 0.001


func _process(delta: float) -> void:
	_time += delta
	if _ending > 0.0:
		_ending += delta
		if _ending > (0.6 if _burst else 0.35):
			queue_free()
	_stroke_left -= delta
	if _stroke_left <= 0.0 and form in ["harpy", "werewolf"]:
		_stroke_left = randf_range(0.18, 0.4) if form == "harpy" else 0.5
		_strokes = _make_strokes()
	queue_redraw()


func _make_strokes() -> Array:
	var result: Array = []
	if form == "harpy":
		# A bolt striking somewhere round the player.
		var at: Vector2 = Vector2.from_angle(randf() * TAU) * randf_range(50.0, 120.0) * Vector2(1.0, 0.55)
		var bolt := PackedVector2Array([at + Vector2(randf_range(-20, 20), -200)])
		while bolt[bolt.size() - 1].y < at.y - 8.0:
			var last := bolt[bolt.size() - 1]
			bolt.append(Vector2(last.x + randf_range(-12, 12), minf(at.y, last.y + randf_range(20, 40))))
		result.append(bolt)
	return result


func _draw() -> void:
	var share := clampf(_time / seconds, 0.0, 1.0)
	var fade := 1.0 - clampf(_ending / 0.35, 0.0, 1.0)
	# The world darkens toward the edges, drawing the eye in.
	draw_arc(Vector2(0, -16), 640.0, 0.0, TAU, 64, Color(0.0, 0.0, 0.03, 0.55 * share * fade), 840.0)
	draw_arc(Vector2(0, -16), 300.0 - share * 60.0, 0.0, TAU, 64, Color(0.0, 0.0, 0.03, 0.22 * share * fade), 160.0)
	if _burst:
		draw_circle(Vector2(0, -16), 40.0 + _ending * 600.0, Color(1, 1, 1, 0.5 * fade))
	# Rings closing in on the ground.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	for k in 3:
		var phase := fposmod(_time * (0.6 + share * 1.4) + k / 3.0, 1.0)
		draw_arc(Vector2.ZERO, 120.0 * (1.0 - phase) + 14.0, 0.0, TAU, 48, Color(color, phase * 0.75 * fade), 2.0 + share * 2.0)
	draw_arc(Vector2.ZERO, 26.0, 0.0, TAU * share, 40, Color(1, 1, 1, 0.9 * fade), 3.0)
	draw_set_transform(Vector2.ZERO)
	# A pillar of light rising.
	var height := 30.0 + share * 220.0
	var width := 6.0 + share * 18.0
	draw_rect(Rect2(-width / 2.0, -height, width, height), Color(color, 0.16 * fade + 0.18 * share * fade))
	draw_rect(Rect2(-width / 6.0, -height, width / 3.0, height), Color(1, 1, 1, 0.25 * share * fade))
	_draw_form(share, fade)
	# Motes spiralling in.
	for mote: Array in _motes:
		var travel := fposmod(_time * mote[2] * (0.5 + share), 1.0)
		var radius: float = 150.0 * mote[1] * (1.0 - travel) + 8.0
		var angle: float = mote[0] + _time * (1.5 + share * 3.0) * mote[2]
		var at: Vector2 = Vector2(cos(angle) * radius, sin(angle) * radius * 0.55 - 16.0 - travel * 26.0)
		var bright := Color(color.lerp(Color.WHITE, travel * 0.7), (0.3 + 0.7 * travel) * fade * (0.4 + 0.6 * share))
		draw_rect(Rect2(at - Vector2(mote[3], mote[3]) / 2.0, Vector2(mote[3], mote[3])), bright)


## The form's own build-up while the key is held, and its burst.
func _draw_form(share: float, fade: float) -> void:
	var blast := _ending / 0.6 if _burst else 0.0
	match form:
		"werewolf":
			# Tufts of fur whirling in, then three claw marks torn across.
			for bit: Array in _bits:
				var angle: float = bit[0] + _time * 2.4
				var at: Vector2 = Vector2.from_angle(angle) * bit[1] * (1.0 - share * 0.6) * Vector2(1.0, 0.55) + Vector2(0, -20)
				draw_line(at, at + Vector2.from_angle(angle + 1.6) * bit[2] * 1.6, Color(0.55, 0.45, 0.4, 0.8 * fade), 2.0)
			if share > 0.6:
				var eye := 0.5 + 0.5 * sin(_time * 18.0)
				draw_rect(Rect2(-6, -42, 3, 2), Color(1.0, 0.2, 0.15, eye * fade))
				draw_rect(Rect2(3, -42, 3, 2), Color(1.0, 0.2, 0.15, eye * fade))
			if _burst:
				for k in 3:
					var x := -26.0 + k * 18.0
					var grow := minf(1.0, blast * 3.0)
					draw_line(Vector2(x, -70), Vector2(x + 30.0 * grow, -70 + 80.0 * grow), Color(1.0, 0.25, 0.2, 0.9 * fade), 4.0)
					draw_line(Vector2(x + 1, -69), Vector2(x + 1 + 30.0 * grow, -69 + 80.0 * grow), Color(1, 0.9, 0.85, 0.7 * fade), 1.5)
		"golem":
			# Stones rise and circle, then slam in; the ground splits.
			for bit: Array in _bits:
				var angle: float = bit[0] + _time * 0.9
				var lift: float = minf(1.0, share * 1.6) * (30.0 + bit[3] * 30.0)
				var reach: float = bit[1] * (1.0 - share * 0.55)
				var at: Vector2 = Vector2(cos(angle) * reach, sin(angle) * reach * 0.5 - lift)
				var size: float = bit[2] * 1.3
				draw_colored_polygon(PackedVector2Array([at + Vector2(-size, 0), at + Vector2(-size * 0.4, -size), at + Vector2(size, -size * 0.6), at + Vector2(size * 0.7, size * 0.6)]), Color(0.55, 0.53, 0.6, fade))
				draw_line(at + Vector2(-size * 0.4, -size), at + Vector2(size, -size * 0.6), Color(0.8, 0.78, 0.85, fade), 1.0)
			if _burst:
				for k in 8:
					var dir := Vector2.from_angle(k * TAU / 8.0 + 0.3) * Vector2(1.0, 0.5)
					var crack := PackedVector2Array([Vector2.ZERO, dir * 30.0 * (1.0 + blast) + dir.orthogonal() * 5.0, dir * 70.0 * (0.5 + blast)])
					draw_polyline(crack, Color(0.12, 0.1, 0.1, 0.9 * fade), 3.0)
		"harpy":
			# Feathers lifted on a rising wind, lightning striking round about.
			for bit: Array in _bits:
				var rise := fposmod(_time * 0.6 + bit[3], 1.0)
				var at: Vector2 = Vector2(cos(bit[0]) * bit[1] * 0.9, sin(bit[0]) * bit[1] * 0.4 - rise * 140.0)
				var tilt := sin(_time * 4.0 + bit[3] * 9.0) * 0.8
				var tip: Vector2 = at + Vector2.from_angle(tilt - PI / 2.0) * bit[2] * 1.5
				draw_line(at, tip, Color(0.9, 0.95, 1.0, (1.0 - rise) * fade), 2.0)
				draw_line(at, at.lerp(tip, 0.5) + Vector2(2, 0), Color(0.55, 0.8, 1.0, (1.0 - rise) * fade), 1.0)
			if share > 0.3 or _burst:
				for bolt: PackedVector2Array in _strokes:
					draw_polyline(bolt, Color(0.75, 0.9, 1.0, 0.85 * fade), 3.0)
					draw_polyline(bolt, Color(1, 1, 1, fade), 1.0)
			if _burst:
				draw_line(Vector2(0, -320), Vector2(0, -20), Color(0.85, 0.95, 1.0, (1.0 - blast) * fade), 10.0 * (1.0 - blast) + 2.0)
		"wraith":
			# Smoke curling in; the burst is a dark bloom.
			for bit: Array in _bits:
				var angle: float = bit[0] - _time * 1.4
				var reach: float = bit[1] * (1.0 - share * 0.7)
				var at: Vector2 = Vector2(cos(angle) * reach, sin(angle) * reach * 0.5 - 20.0 - bit[3] * 20.0)
				draw_circle(at, bit[2] * 2.0, Color(0.22, 0.2, 0.26, 0.35 * fade))
				draw_circle(at + Vector2(-1, -1), bit[2], Color(0.5, 0.5, 0.58, 0.25 * fade))
			if _burst:
				draw_circle(Vector2(0, -20), 20.0 + blast * 110.0, Color(0.08, 0.07, 0.1, 0.55 * (1.0 - blast)))
		"treant":
			# Roots creep in across the ground; leaves swirl up.
			for k in 7:
				var angle := k * TAU / 7.0 + 0.4
				var start := Vector2.from_angle(angle) * 130.0 * Vector2(1.0, 0.5)
				var root := PackedVector2Array()
				var steps := 8
				for i in steps + 1:
					var along := float(i) / steps * minf(1.0, share * 1.3)
					var bend := Vector2.from_angle(angle + PI / 2.0) * sin(along * 6.0 + k) * 8.0 * Vector2(1.0, 0.5)
					root.append(start.lerp(Vector2.ZERO, along) + bend)
				draw_polyline(root, Color(0.35, 0.25, 0.15, 0.9 * fade), 3.0)
				draw_polyline(root, Color(0.45, 0.65, 0.3, 0.6 * fade), 1.0)
			for bit: Array in _bits:
				var angle: float = bit[0] + _time * 2.0
				var reach: float = (bit[1] * 0.8) * (1.0 + (blast * 2.0 if _burst else 0.0))
				var at: Vector2 = Vector2(cos(angle) * reach, sin(angle) * reach * 0.5 - 10.0 - bit[3] * 50.0 * share)
				draw_colored_polygon(PackedVector2Array([at + Vector2(-3, 0), at + Vector2(0, -2), at + Vector2(3, 0), at + Vector2(0, 2)]), Color(0.45, 0.8, 0.35, 0.85 * fade))
		"fiend":
			# Flame tongues rising in a ring; the burst is a ring of fire.
			for bit: Array in _bits:
				var angle: float = bit[0]
				var reach := 60.0 - share * 20.0 + (blast * 90.0 if _burst else 0.0)
				var at: Vector2 = Vector2(cos(angle) * reach, sin(angle) * reach * 0.5)
				var tall: float = (10.0 + bit[2] * 3.0) * (0.4 + share) * (0.8 + 0.2 * sin(_time * 12.0 + bit[3] * 7.0))
				draw_colored_polygon(PackedVector2Array([at + Vector2(-4, 0), at + Vector2(sin(_time * 9.0 + bit[3] * 5.0) * 2.0, -tall), at + Vector2(4, 0)]), Color(1.0, 0.45, 0.15, 0.85 * fade))
				draw_colored_polygon(PackedVector2Array([at + Vector2(-2, 0), at + Vector2(0, -tall * 0.55), at + Vector2(2, 0)]), Color(1.0, 0.85, 0.4, 0.9 * fade))
		"troll":
			# Ice spikes grow up in a ring; the burst shatters them outward.
			for bit: Array in _bits:
				var angle: float = bit[0]
				var reach := 54.0 + (blast * 110.0 if _burst else 0.0)
				var at: Vector2 = Vector2(cos(angle) * reach, sin(angle) * reach * 0.5)
				var tall: float = (8.0 + bit[2] * 3.0) * minf(1.0, share * 1.4)
				draw_colored_polygon(PackedVector2Array([at + Vector2(-4, 0), at + Vector2(0, -tall), at + Vector2(4, 0)]), Color(0.65, 0.88, 1.0, 0.9 * fade))
				draw_line(at + Vector2(-1, -1), at + Vector2(0, -tall + 2.0), Color(1, 1, 1, 0.9 * fade), 1.0)
		"void":
			# A rift opens underfoot and pulls the motes down into it.
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
			var rift := 10.0 + share * 46.0 - (blast * 50.0 if _burst else 0.0)
			if rift > 0.0:
				draw_circle(Vector2.ZERO, rift, Color(0.02, 0.0, 0.05, 0.9 * fade))
				draw_arc(Vector2.ZERO, rift, 0.0, TAU, 40, Color(0.75, 0.5, 1.0, 0.9 * fade), 2.0)
			draw_set_transform(Vector2.ZERO)
			for bit: Array in _bits:
				var pull := fposmod(_time * 0.8 + bit[3], 1.0)
				var angle: float = bit[0] + pull * 3.0
				var at: Vector2 = Vector2(cos(angle), sin(angle) * 0.45) * bit[1] * (1.0 - pull)
				draw_rect(Rect2(at - Vector2(1.5, 1.5), Vector2(3, 3)), Color(0.85, 0.7, 1.0, pull * fade))
