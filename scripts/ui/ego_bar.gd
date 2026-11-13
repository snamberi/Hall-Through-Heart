class_name EgoBar
extends Control
## The Ego meter under the experience bar: a slim bar that fills violet,
## turning to angry red as pride grows past where it starts to cost, with a
## tick where the penalty begins and the tier named beside it. Point at it
## for what it costs now and how to bring it down.

var _player: Player
var _font: Font
var _shown := 0.0


func setup(player: Player) -> void:
	_player = player
	_font = UITheme.get_theme().default_font
	custom_minimum_size = Vector2(280, 14)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_PASS
	player.ego.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	tooltip_text = "Ego: %s (%d / 100)\n%s" % [_player.ego.tier(), roundi(_player.ego.value), _player.ego.describe()]


func _process(delta: float) -> void:
	if _player == null:
		return
	_shown = move_toward(_shown, _player.ego.value, delta * 120.0)
	queue_redraw()


func _draw() -> void:
	if _player == null:
		return
	var ego := _player.ego
	var bar := Rect2(40, 3, size.x - 40, 7)
	draw_string_outline(_font, Vector2(0, 11), "EGO", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color(0, 0, 0, 0.8))
	draw_string(_font, Vector2(0, 11), "EGO", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.82, 0.68, 1.0))
	draw_rect(bar.grow(1.0), Color(0.05, 0.04, 0.08, 0.9))
	var share := _shown / Ego.MAX
	var hot := clampf((_shown - Ego.FREE) / (Ego.MAX - Ego.FREE), 0.0, 1.0)
	var fill := Color(0.6, 0.42, 0.95).lerp(Color(0.95, 0.25, 0.3), hot)
	if share > 0.0:
		draw_rect(Rect2(bar.position, Vector2(roundf(bar.size.x * share), bar.size.y)), fill)
		draw_rect(Rect2(bar.position, Vector2(roundf(bar.size.x * share), 2)), fill.lightened(0.35))
	# Where it starts to cost.
	var tick := bar.position.x + roundf(bar.size.x * Ego.FREE / Ego.MAX)
	draw_rect(Rect2(tick, bar.position.y - 2, 1, bar.size.y + 4), Color(1, 1, 1, 0.6))
	draw_rect(bar.grow(1.0), Color(0.55, 0.45, 0.3), false, 1.0)
	if ego.value >= 1.0:
		var label := "%s%s" % [ego.tier(), "  -%d%%" % roundi(ego.damage_loss() * 100.0) if ego.weight() > 0.0 else ""]
		draw_string_outline(_font, Vector2(bar.end.x + 6, 11), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color(0, 0, 0, 0.8))
		draw_string(_font, Vector2(bar.end.x + 6, 11), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, fill.lightened(0.3))
