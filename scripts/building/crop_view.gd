class_name CropView
extends Node2D
## Draws what is growing in a farm plot: rows of sprouts, then leaves, then
## the crop itself, with a dark patch of wet earth when it is watered.

var record: Dictionary


func _ready() -> void:
	z_index = 1


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var crop: String = record.get("crop", "")
	if record.get("watered", false):
		draw_rect(Rect2(-24, -12, 48, 30), Color(0.1, 0.06, 0.04, 0.35))
	if crop == "":
		return
	var data: Dictionary = Crops.CROPS[crop]
	var growth: float = record.get("growth", 0.0)
	var stage := Crops.stage(growth)
	var stalk: Color = data["stalk"]
	var fruit: Color = data["fruit"]
	var sway := sin(Time.get_ticks_msec() / 600.0 + position.x) * 1.0
	for row in 3:
		for column in 3:
			var base := Vector2(-16 + column * 16, -6 + row * 9)
			match stage:
				0:
					draw_line(base, base + Vector2(0, -3), stalk, 1.0)
					draw_rect(Rect2(base + Vector2(-1, -4), Vector2(2, 1)), stalk.lightened(0.3))
				1:
					draw_line(base, base + Vector2(sway, -7), stalk, 1.5)
					draw_circle(base + Vector2(-2 + sway, -6), 1.8, stalk)
					draw_circle(base + Vector2(2 + sway, -7), 1.8, stalk.lightened(0.15))
				_:
					var tall := 12.0 if crop in ["wheat", "sunroot"] else 8.0
					draw_line(base, base + Vector2(sway, -tall), stalk.darkened(0.1), 1.5)
					draw_circle(base + Vector2(-3 + sway, -tall * 0.6), 2.4, stalk)
					draw_circle(base + Vector2(3 + sway, -tall * 0.7), 2.4, stalk.lightened(0.15))
					if stage == 3:
						match crop:
							"wheat", "sunroot":
								draw_rect(Rect2(base + Vector2(-1.5 + sway, -tall - 5), Vector2(3, 6)), fruit)
								draw_rect(Rect2(base + Vector2(-0.5 + sway, -tall - 6), Vector2(1, 1)), fruit.lightened(0.4))
							"pumpkin":
								if column != 1:
									draw_circle(base + Vector2(0, -2), 5.0, fruit.darkened(0.3))
									draw_circle(base + Vector2(0, -2.5), 4.2, fruit)
									draw_line(base + Vector2(0, -6), base + Vector2(1, -8), stalk.darkened(0.3), 1.5)
							"carrot", "potato":
								draw_circle(base + Vector2(0, 0), 2.6, fruit)
								draw_circle(base + Vector2(-0.6, -0.6), 1.0, fruit.lightened(0.4))
							_:
								for k in 3:
									draw_circle(base + Vector2(-3 + k * 3 + sway, -tall * 0.6 - k % 2 * 3), 1.8, fruit)
	if stage == 3:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 250.0)
		draw_string_outline(UITheme.get_theme().default_font, Vector2(-30, -26), "Ripe", HORIZONTAL_ALIGNMENT_CENTER, 60, 11, 3, Color.BLACK)
		draw_string(UITheme.get_theme().default_font, Vector2(-30, -26), "Ripe", HORIZONTAL_ALIGNMENT_CENTER, 60, 11, Color(1.0, 0.9, 0.5, 0.6 + 0.4 * pulse))
