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
	# Numbers are drawn in pixel digits, a world pixel at a time (twice as
	# big for a critical hit); words still use the type.
	var hit := PixelHit.new()
	hit.text = str(roundi(amount)) + ("!" if big else "")
	hit.colour = color
	hit.block = (3 if big else 2) + (1 if GameSettings.damage_number_size >= 1.5 else 0)
	hit.big = big
	hit.z_index = 100
	parent.add_child(hit)
	hit.position = (world_position + Vector2(randf_range(-8.0, 8.0), -46.0 - mini(_stack_at(world_position), 5) * 9.0)).round()


## How many numbers landed here just now (each new one goes above them).
static func _stack_at(world_position: Vector2) -> int:
	var now := Time.get_ticks_msec() / 1000.0
	_recent = _recent.filter(func(entry: Array) -> bool: return now - entry[1] < 0.45)
	var stacked := 0
	for entry: Array in _recent:
		if (entry[0] as Vector2).distance_to(world_position) < 40.0:
			stacked += 1
	_recent.append([world_position, now])
	return stacked


## Damage in pixel digits: 3x5 glyphs, each pixel a square `block` wide,
## a dark outline round them, lighter on top and darker below; it hops up,
## drifts, and fades in steps.
class PixelHit extends Node2D:
	const GLYPHS := {
		"0": ["111", "101", "101", "101", "111"], "1": ["010", "110", "010", "010", "111"],
		"2": ["111", "001", "111", "100", "111"], "3": ["111", "001", "111", "001", "111"],
		"4": ["101", "101", "111", "001", "001"], "5": ["111", "100", "111", "001", "111"],
		"6": ["111", "100", "111", "101", "111"], "7": ["111", "001", "010", "010", "010"],
		"8": ["111", "101", "111", "101", "111"], "9": ["111", "101", "111", "001", "111"],
		"!": ["1", "1", "1", "0", "1"], "-": ["000", "000", "111", "000", "000"],
	}
	var text := ""
	var colour := Color.WHITE
	var block := 1
	var big := false
	var _time := 0.0
	var _drift := 0.0

	func _ready() -> void:
		_drift = randf_range(-6.0, 6.0)

	func _process(delta: float) -> void:
		_time += delta
		if _time >= LIFETIME:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var t := _time / LIFETIME
		# Up fast then settling; whole pixels only.
		var rise := roundf(RISE * (1.0 - pow(1.0 - t, 3.0)))
		var fade := 1.0 if t < 0.55 else 1.0 - snappedf((t - 0.55) / 0.45, 0.25)
		var at := Vector2(roundf(_drift * t), -rise)
		var width := 0
		for ch in text:
			width += (GLYPHS.get(ch, ["1"])[0] as String).length() * block + block
		var x := at.x - roundf(width / 2.0)
		# A critical hit flashes white for its first moment.
		var face := Color.WHITE if big and t < 0.08 else colour.lightened(0.1)
		for pass_ in 2:
			var cx := x
			for ch in text:
				var rows: Array = GLYPHS.get(ch, ["1"])
				for r in rows.size():
					var row: String = rows[r]
					for col in row.length():
						if row[col] != "1":
							continue
						var cell := Rect2(Vector2(cx + col * block, at.y + r * block), Vector2(block, block))
						if pass_ == 0:
							draw_rect(cell.grow(1.0), Color(0.02, 0.01, 0.03, fade))
						else:
							var shade := face.lightened(0.25) if r == 0 else face.darkened(0.25) if r == rows.size() - 1 else face
							draw_rect(cell, Color(shade, fade))
				cx += (rows[0] as String).length() * block + block


static func spawn_text(
	parent: Node, world_position: Vector2, text: String, color: Color, font_size: int = 14, pop: bool = false
) -> void:
	var stacked := _stack_at(world_position)
	var label := DamageNumber.new()
	label.text = text
	label.add_theme_font_override("font", UITheme.bold())
	label.add_theme_font_size_override("font_size", roundi((font_size + 2) * GameSettings.damage_number_size))
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
