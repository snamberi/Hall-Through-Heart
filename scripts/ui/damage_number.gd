class_name DamageNumber
extends Label
## A number that pops out of a hit, floats up and fades. Numbers landing in
## the same spot at once stack upward instead of piling on top of each other.

const RISE := 26.0
const LIFETIME := 0.75
## Recent numbers: [position, time] so new ones can stack above them.
static var _recent: Array = []


static func spawn(
	parent: Node, world_position: Vector2, amount: float, color: Color, big: bool = false
) -> void:
	if not GameSettings.damage_numbers:
		return
	spawn_text(parent, world_position, str(roundi(amount)) + ("!" if big else ""), color, 19 if big else 13, big)


static func spawn_text(
	parent: Node, world_position: Vector2, text: String, color: Color, font_size: int = 14, pop: bool = false
) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	_recent = _recent.filter(func(entry: Array) -> bool: return now - entry[1] < 0.45)
	var stacked := 0
	for entry: Array in _recent:
		if (entry[0] as Vector2).distance_to(world_position) < 40.0:
			stacked += 1
	_recent.append([world_position, now])
	var label := DamageNumber.new()
	label.text = text
	label.add_theme_font_override("font", UITheme.bold())
	label.add_theme_font_size_override("font_size", font_size + 2)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.03))
	label.add_theme_constant_override("outline_size", 5)
	label.z_index = 100
	parent.add_child(label)
	var width := label.get_minimum_size().x / 2.0
	# The camera zooms in 2x; shrink so the text stays small and sharp.
	label.scale = Vector2.ONE / 2.0
	var drift := randf_range(-8.0, 8.0)
	label.position = world_position + Vector2(-width / 2.0 + drift, -46.0 - mini(stacked, 5) * 9.0)
	label.pivot_offset = label.get_minimum_size() / 2.0
	var tween := label.create_tween()
	if pop:
		label.scale = Vector2.ONE * 0.9
		tween.tween_property(label, "scale", Vector2.ONE * 0.5, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.set_parallel()
	tween.tween_property(label, "position:y", label.position.y - RISE, LIFETIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(label, "position:x", label.position.x + drift * 0.6, LIFETIME)
	tween.tween_property(label, "modulate:a", 0.0, LIFETIME * 0.45).set_delay(LIFETIME * 0.55)
	tween.chain().tween_callback(label.queue_free)
