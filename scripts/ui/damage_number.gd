class_name DamageNumber
extends Label
## A number that floats up from a hit and fades out.

const RISE := 30.0
const LIFETIME := 0.6


static func spawn(
	parent: Node, world_position: Vector2, amount: float, color: Color, big: bool = false
) -> void:
	spawn_text(parent, world_position, str(roundi(amount)), color, 20 if big else 14)


static func spawn_text(
	parent: Node, world_position: Vector2, text: String, color: Color, font_size: int = 14
) -> void:
	var label := DamageNumber.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	# The camera zooms in 2x; shrink so the text stays small and sharp.
	label.scale = Vector2.ONE / 2.0
	label.z_index = 100
	label.position = world_position + Vector2(randf_range(-10.0, 10.0), -46.0)
	parent.add_child(label)

	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y - RISE, LIFETIME)
	tween.tween_property(label, "modulate:a", 0.0, LIFETIME).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)
