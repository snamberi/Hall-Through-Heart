class_name RemotePlayer
extends Node2D
## Another player in a shared game, as this game sees them: their own
## look, their name over their head in their colour, their level and
## health, walking and striking as they do. Their place arrives about
## fifteen times a second; between those it glides there smoothly (a
## little behind, so it never has to guess).

## Seconds behind the newest news, so there are always two to glide between.
const DELAY := 0.1
## Further than this off and it is put straight there (a waystone, a door).
const SNAP := 420.0

var peer := 0
var player_name := ""
var colour := Color.WHITE
var level := 1
var health_share := 1.0
var dead := false
## Where this game's own player is: "" out in the world, else their room.
## Someone is seen only by players in the same place.
var local_place := ""
var place := ""

var _figure: PersonFigure
## [time, position, velocity] newest last.
var _history: Array = []
var _pose := "idle"
var _strike_left := 0.0
var _clock := 0.0
var _look: Dictionary = {}
var _class := ""


func setup(peer_id: int, info: Dictionary) -> void:
	peer = peer_id
	player_name = str(info.get("name", "Wanderer"))
	level = int(info.get("level", 1))
	colour = Net.colour_of(peer)
	_look = info.get("look", {}) if info.get("look", {}) is Dictionary else {}
	_class = str(info.get("class", ""))


func _ready() -> void:
	add_to_group("remote_players")
	# Where the world allows fighting between players, they can be struck.
	if Net.rules.get("pvp", false):
		add_to_group("rivals")
	_figure = PersonFigure.new()
	var look := Appearance.DEFAULT.duplicate()
	look.merge(_look, true)
	_figure.dress(look)
	_figure.stance = "idle_" + str(_class)
	add_child(_figure)


## What they wear (PlayerAnimator.worn()), told when it changes.
func wear(gear: Array) -> void:
	if _figure:
		_figure.wear(gear)


## News of where they are: {"p", "v", "fx", "a", "hp", "mhp", "lv", "d"}.
func hear(state: Dictionary) -> void:
	var at: Vector2 = state.get("p", global_position)
	var moving: Vector2 = state.get("v", Vector2.ZERO)
	if _history.is_empty() or at.distance_to(global_position) > SNAP:
		_history.clear()
		global_position = at
	_history.append([_clock, at, moving])
	while _history.size() > 8:
		_history.pop_front()
	level = int(state.get("lv", level))
	health_share = clampf(float(state.get("hp", 1.0)) / maxf(float(state.get("mhp", 1.0)), 1.0), 0.0, 1.0)
	dead = bool(state.get("d", false))
	var facing := float(state.get("fx", 0.0))
	if absf(facing) > 0.05:
		_figure.face(facing)
	# Seen from the way they are going; at rest, in their class's stance.
	_figure.set_heading(moving if moving.length() > 20.0 else Vector2.ZERO)
	var animation := str(state.get("a", "idle"))
	# A blow arrives with its view ("attack_side"): played as it was seen.
	if animation.get_slice("_", 0) in ["attack", "heavy", "thrust", "smash", "shoot", "cast", "dodge"]:
		if _pose != animation:
			_strike_left = 0.4
			_figure.pose(animation, 1.0)
			_pose = animation
	elif _strike_left <= 0.0:
		var walk := "walk" if moving.length() > 20.0 else "idle"
		if moving.length() > 260.0:
			walk = "run"
		if dead:
			walk = "idle"
		if walk != _pose:
			_figure.pose(walk, 1.0)
			_pose = walk
	modulate.a = 0.45 if dead else 1.0
	# Someone in a cave or dungeon is only seen by others in the same one.
	place = str(state.get("ik", "" if not state.get("in", false) else "?"))
	visible = place == local_place
	queue_redraw()


func _process(delta: float) -> void:
	_clock += delta
	_strike_left = maxf(_strike_left - delta, 0.0)
	if _history.size() >= 2:
		var when := _clock - DELAY
		var older: Array = _history[0]
		var newer: Array = _history[_history.size() - 1]
		for k in range(_history.size() - 1):
			if float(_history[k][0]) <= when and float(_history[k + 1][0]) >= when:
				older = _history[k]
				newer = _history[k + 1]
				break
		var span := maxf(float(newer[0]) - float(older[0]), 0.001)
		var share := clampf((when - float(older[0])) / span, 0.0, 1.2)
		var goal := (older[1] as Vector2).lerp(newer[1], share)
		if share > 1.0:
			# Past the newest: carry on as they were going, briefly.
			goal = (newer[1] as Vector2) + (newer[2] as Vector2) * minf(when - float(newer[0]), 0.15)
		global_position = global_position.lerp(goal, 1.0 - exp(-20.0 * delta))
	elif _history.size() == 1:
		global_position = global_position.lerp(_history[0][1], 1.0 - exp(-12.0 * delta))


func _draw() -> void:
	# A shadow at the feet, their name and level, and their health.
	draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 11.0, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO)
	var font := UITheme.bold()
	var top := -_figure.head_height() - 12.0 if _figure else -56.0
	var words := "%s  Lv %d" % [player_name, level]
	var width := font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	var origin := Vector2(roundf(-width / 2.0), roundf(top))
	draw_string_outline(font, origin, words, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 3, Color(0.02, 0.02, 0.05, 0.9))
	draw_string(font, origin, words, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, colour)
	var bar := Rect2(Vector2(-12, roundf(top + 3.0)), Vector2(24, 3))
	draw_rect(bar.grow(1.0), Color(0.02, 0.02, 0.05, 0.9))
	draw_rect(bar, Color(0.25, 0.06, 0.08))
	draw_rect(Rect2(bar.position, Vector2(roundf(24.0 * health_share), 3)), Color(0.85, 0.25, 0.28) if not dead else Color(0.4, 0.4, 0.45))
	if dead:
		var fallen := "Fallen"
		var fallen_width := font.get_string_size(fallen, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_string_outline(font, Vector2(roundf(-fallen_width / 2.0), roundf(top - 14.0)), fallen, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 4, Color.BLACK)
		draw_string(font, Vector2(roundf(-fallen_width / 2.0), roundf(top - 14.0)), fallen, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UITheme.BAD)
