class_name HitSpark
extends Node2D
## A flash and a few flying chips where a blow lands, drawn a whole pixel
## at a time (never a turned or scaled picture): a white heart, rays of the
## blow's colour shooting out on the eight ways and shrinking back, and
## chips that fly off and slow.

const LIFE := 0.3

var colour := Color(1.0, 0.95, 0.8)
var big := false
var _time := 0.0
## Each chip: [position, velocity].
var _chips: Array = []
## Which of the eight ways have rays, and how long each is.
var _rays: Array = []


static func spawn(parent: Node, at: Vector2, color: Color = Color(1.0, 0.95, 0.8), is_big: bool = false) -> void:
	var spark := HitSpark.new()
	spark.position = at.round()
	spark.colour = color
	spark.big = is_big
	spark.z_index = 60
	var rays := 8 if is_big else 5
	var first := randi() % 8
	for k in rays:
		spark._rays.append([(first + k * (8 if rays == 8 else 3)) % 8, randf_range(0.7, 1.0)])
	for k in GameSettings.particle_amount(10 if is_big else 6):
		spark._chips.append([Vector2.ZERO, Vector2.from_angle(randf() * TAU) * randf_range(60.0, 170.0)])
	parent.add_child(spark)


func _process(delta: float) -> void:
	_time += delta
	if _time >= LIFE:
		queue_free()
		return
	for chip: Array in _chips:
		chip[0] += chip[1] * delta
		chip[1] *= pow(0.01, delta)
	queue_redraw()


func _draw() -> void:
	var t := _time / LIFE
	var fade := 1.0 - t
	# Rays: out fast, then shrinking back toward the heart.
	var reach := (7.0 if big else 5.0) * (minf(t * 5.0, 1.0) - maxf(t - 0.4, 0.0) * 1.4)
	for ray: Array in _rays:
		var dir := Vector2.from_angle(int(ray[0]) * PI / 4.0).round()
		var length := int(reach * float(ray[1]))
		for k in range(1, length + 1):
			var c := Color(1, 1, 1, fade) if k <= 1 else Color(colour, fade * (1.0 - float(k) / (length + 2)))
			draw_rect(Rect2(dir * k, Vector2.ONE), c)
	if t < 0.5:
		var core := 2 if big else 1
		draw_rect(Rect2(Vector2(-core / 2, -core / 2) - Vector2(0.5, 0.5).floor(), Vector2(core + 1, core + 1)), Color(1, 1, 1, 1.0 - t * 2.0))
	for chip: Array in _chips:
		draw_rect(Rect2((chip[0] as Vector2).floor(), Vector2(2, 2) if big else Vector2.ONE), Color(colour, fade))
