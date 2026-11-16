class_name RaceCourse
extends Node2D
## A village's mount race: a loop of gates out round the village and back
## to the race post, ridden against the clock. Each course has its own
## times to beat for bronze, silver and gold; the first time each medal is
## won it pays out, and the best time is kept (see Stable).
##
## The course is laid from the post's position, so the same village always
## has the same course. Gates are drawn on the ground in whole pixels: the
## next one bright, the rest dim, with a pointer at the rider's feet.

const GATES := 8
const GATE_RADIUS := 40.0
const COUNTDOWN := 3.0
## Times to beat, as path length over these speeds (pixels a second).
const PACE := [190.0, 240.0, 290.0]
const PRIZE := [0, 80, 200, 450]

## The race being run, if any.
static var current: RaceCourse

var course := ""
var post := Vector2.ZERO
var gates: Array[Vector2] = []
var times: Array[float] = []
var _player: Player
var _next := 0
var _clock := -COUNTDOWN
var _layer: CanvasLayer
var _label: Label
var _done := false


## Lays out a course round a village from its race post. Gates go out in a
## loop between `inner` and `outer` tiles from the village centre, on dry
## ground; the last gate is the post itself.
static func plan(world: World, centre: Vector2i, post_at: Vector2, inner := 20.0, outer := 32.0) -> Array[Vector2]:
	var random := RandomNumberGenerator.new()
	random.seed = hash(Vector3i(centre.x, centre.y, 7177))
	var start := (post_at - world.cell_to_world(centre)).angle()
	var result: Array[Vector2] = []
	for index in GATES - 1:
		var angle := start + TAU * (index + 1) / GATES + random.randf_range(-0.2, 0.2)
		var radius := random.randf_range(inner, outer)
		var placed := false
		for attempt in 6:
			var tiles: float = radius + [0.0, -4.0, 4.0, -8.0, 8.0, -12.0][attempt]
			var cell := centre + Vector2i((Vector2.from_angle(angle) * tiles).round())
			if world.generator.is_dry_land(cell):
				result.append(world.cell_to_world(cell))
				placed = true
				break
		if not placed:
			continue
	result.append(post_at)
	return result


## Seconds to beat for bronze, silver and gold on a set of gates.
static func par_times(from: Vector2, points: Array[Vector2]) -> Array[float]:
	var length := 0.0
	var at := from
	for point in points:
		length += at.distance_to(point)
		at = point
	var result: Array[float] = []
	for pace: float in PACE:
		result.append(snappedf(length / pace, 0.1))
	return result


## Starts a race for the player from a post. Returns "" or why not.
static func start(player: Player, key: String, post_at: Vector2, points: Array[Vector2]) -> String:
	if is_instance_valid(current):
		return "A race is already under way."
	if points.size() < 4:
		return "There is no room for a course here."
	if player.mount_id == "":
		# Climb onto the best mount in the bag.
		var problem := player.ride("")
		if problem != "":
			return "You need a mount to race. " + problem
	if points.size() < 4:
		return "There is no room for a course here."
	var race := RaceCourse.new()
	race.course = key
	race.post = post_at
	race.gates = points
	race.times = par_times(post_at, points)
	race._player = player
	player.get_parent().add_child(race)
	current = race
	return ""


func _ready() -> void:
	z_index = -4
	_layer = CanvasLayer.new()
	_layer.layer = 5
	add_child(_layer)
	_label = UITheme.strong("", 20, UITheme.GOLD)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04, 0.9))
	_label.add_theme_constant_override("outline_size", 6)
	_label.anchor_left = 0.5
	_label.anchor_right = 0.5
	_label.offset_left = -300.0
	_label.offset_right = 300.0
	_label.offset_top = 128.0
	_label.offset_bottom = 156.0
	_layer.add_child(_label)
	Audio.play("ui_click")


func _process(delta: float) -> void:
	if _done:
		return
	if not is_instance_valid(_player) or _player.is_dead():
		_end("")
		return
	if _player.mount_id == "":
		_end("Off the saddle: the race is lost.")
		return
	if _player.global_position.distance_to(post) > 2400.0 or _clock > times[0] * 3.0:
		_end("Too far off the course: the race is lost.")
		return
	var was := _clock
	_clock += delta
	if _clock < 0.0:
		_label.text = "%d" % ceili(-_clock)
		if ceili(-was) != ceili(-_clock):
			Audio.play("ui_click")
	else:
		if was < 0.0:
			Audio.play("level_up", -6.0)
		var gold := times[2]
		_label.text = "%s   ·   gate %d / %d   ·   gold %s" % [clock_text(_clock), _next + 1, gates.size(), clock_text(gold)]
		_label.add_theme_color_override("font_color", UITheme.GOLD if _clock <= gold else (UITheme.TEXT if _clock <= times[0] else UITheme.BAD))
		if _player.global_position.distance_to(gates[_next]) < GATE_RADIUS + 8.0:
			_next += 1
			RingBurst.spawn(get_parent(), gates[_next - 1] + Vector2(0, -6), UITheme.GOLD, 50.0)
			Audio.play("pickup", -4.0, 0.05)
			if _next >= gates.size():
				_finish()
				return
	queue_redraw()


func _finish() -> void:
	var medal := 0
	for index in times.size():
		if _clock <= times[index]:
			medal = index + 1
	var record := _player.stable.record_race(course, _clock, medal)
	var line := "%s  ·  %s" % [clock_text(_clock), Stable.MEDALS[medal] + " medal" if medal > 0 else "no medal (bronze %s)" % clock_text(times[0])]
	if record["new_medal"]:
		var prize := int(PRIZE[medal] * (1.0 + _player.leveling.level / 20.0))
		_player.inventory.add_gold(prize)
		line += "  ·  +%d gold" % prize
		Events.codex_event.emit("races_won", 1)
	elif record["new_best"]:
		line += "  ·  new best"
	Events.announcement.emit("RACE FINISHED", line)
	_end("")


func _end(message: String) -> void:
	_done = true
	if message != "":
		DamageNumber.spawn_text(get_parent(), _player.global_position + Vector2(0, -60), message, UITheme.BAD, 13)
	if current == self:
		current = null
	queue_free()


## "0:31.4"
static func clock_text(seconds: float) -> String:
	var whole := maxf(seconds, 0.0)
	return "%d:%04.1f" % [int(whole) / 60, fmod(whole, 60.0)]


func _draw() -> void:
	for index in gates.size():
		if index < _next:
			continue
		var at := gates[index] - global_position
		var next := index == _next
		var finish := index == gates.size() - 1
		var color := (UITheme.GOLD if next else Color(0.85, 0.85, 0.95, 0.35))
		if finish and next:
			color = Color(1.0, 0.95, 0.8)
		# A flat ring on the ground: two pixel posts and a squashed circle.
		draw_set_transform(at, 0.0, Vector2(1.0, 0.5))
		draw_arc(Vector2.ZERO, GATE_RADIUS, 0.0, TAU, 36, Color(0, 0, 0, 0.35), 4.0)
		draw_arc(Vector2.ZERO, GATE_RADIUS, 0.0, TAU, 36, color, 2.0)
		draw_set_transform(Vector2.ZERO)
		for side: float in [-1.0, 1.0]:
			var foot := (at + Vector2(side * GATE_RADIUS, 0)).round()
			draw_rect(Rect2(foot + Vector2(-1, -22), Vector2(3, 22)), Color(0.12, 0.1, 0.14))
			draw_rect(Rect2(foot + Vector2(0, -21), Vector2(1, 20)), color)
			draw_rect(Rect2(foot + Vector2(-1, -26), Vector2(3, 4)), Color(0.85, 0.3, 0.3) if not finish else Color(0.95, 0.95, 0.95))
		if next:
			var number := str(index + 1) if not finish else "FINISH"
			draw_string_outline(UITheme.body_bold(), at + Vector2(-20, -30), number, HORIZONTAL_ALIGNMENT_CENTER, 40, 14, 4, Color(0, 0, 0, 0.9))
			draw_string(UITheme.body_bold(), at + Vector2(-20, -30), number, HORIZONTAL_ALIGNMENT_CENTER, 40, 14, color)
	# A pointer at the rider's feet toward the next gate.
	if is_instance_valid(_player) and _next < gates.size():
		var from := _player.global_position - global_position
		var way := (gates[_next] - _player.global_position).normalized()
		var tip := from + way * 34.0
		draw_colored_polygon(PackedVector2Array([tip, from + way * 24.0 + way.orthogonal() * 6.0, from + way * 24.0 - way.orthogonal() * 6.0]), Color(UITheme.GOLD, 0.9))
