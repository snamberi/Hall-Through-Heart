class_name FlickerLight
extends PointLight2D
## A firelit glow that never quite holds still: torches, braziers, lanterns,
## campfires.

var base_energy := 0.9
var base_scale := 1.6
var _phase := randf() * 100.0


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0 + _phase
	var wave := sin(t * 9.0) * 0.45 + sin(t * 23.0 + 1.3) * 0.25 + sin(t * 3.1) * 0.5 + sin(t * 41.0) * 0.12
	energy = base_energy * (1.0 + wave * 0.08)
	texture_scale = base_scale * (1.0 + wave * 0.025)
