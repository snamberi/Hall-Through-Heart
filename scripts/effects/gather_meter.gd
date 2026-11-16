class_name GatherMeter
extends Node2D
## The timing bar over a rich node while it is worked. A marker sweeps back
## and forth across the bar; strike (attack or interact) while it is inside
## the gold zone for a perfect blow. Each strike moves the zone. Up to
## MAX_PERFECTS perfect blows count, shown as pips under the bar.

const WIDTH := 52.0
const HEIGHT := 7.0
const SWEEP := 1.1
const REST := 0.3
const MAX_PERFECTS := 3

var perfects := 0
var _time := 0.0
var _zone_start := 0.6
var _zone_width := 0.22
var _rest_left := 0.0
var _flash := 0.0
var _flash_good := false
var _random := RandomNumberGenerator.new()


func _ready() -> void:
	z_index = 60
	z_as_relative = false
	_random.randomize()
	_move_zone()


func _process(delta: float) -> void:
	_time += delta
	_rest_left = maxf(_rest_left - delta, 0.0)
	_flash = maxf(_flash - delta, 0.0)
	queue_redraw()


## Where the marker is, 0..1, sweeping back and forth.
func marker() -> float:
	var phase := fposmod(_time / SWEEP, 2.0)
	return phase if phase < 1.0 else 2.0 - phase


## A strike. Returns 1 for a perfect blow, 0 for a miss, -1 if the bar is
## still resting from the last strike.
func strike() -> int:
	if _rest_left > 0.0:
		return -1
	var at := marker()
	var hit := at >= _zone_start and at <= _zone_start + _zone_width
	_rest_left = REST
	_flash = 0.25
	_flash_good = hit
	if hit:
		perfects = mini(perfects + 1, MAX_PERFECTS)
		# Each perfect blow narrows the next zone a little.
		_zone_width = maxf(_zone_width - 0.03, 0.12)
	_move_zone()
	return 1 if hit else 0


func _move_zone() -> void:
	var start := _random.randf_range(0.05, 0.95 - _zone_width)
	# Keep the new zone away from where the marker is now.
	if absf(start + _zone_width / 2.0 - marker()) < 0.2:
		start = fposmod(start + 0.45, 0.95 - _zone_width)
	_zone_start = start


func _draw() -> void:
	var left := -WIDTH / 2.0
	var frame := Rect2(left - 2.0, -HEIGHT / 2.0 - 2.0, WIDTH + 4.0, HEIGHT + 4.0)
	draw_rect(frame, Color(0.03, 0.04, 0.07, 0.9))
	draw_rect(frame, Color("8a683a"), false, 1.0)
	var resting := _rest_left > 0.0
	var zone := Rect2(left + _zone_start * WIDTH, -HEIGHT / 2.0, _zone_width * WIDTH, HEIGHT)
	draw_rect(zone, Color(0.95, 0.78, 0.3, 0.45 if resting else 0.95))
	if _flash > 0.0:
		draw_rect(Rect2(left, -HEIGHT / 2.0, WIDTH, HEIGHT), Color(UITheme.GOOD if _flash_good else UITheme.BAD, _flash * 2.0))
	var x := roundf(left + marker() * WIDTH)
	draw_rect(Rect2(x - 1.0, -HEIGHT / 2.0 - 2.0, 2.0, HEIGHT + 4.0), Color(1, 1, 1, 0.5 if resting else 1.0))
	for index in MAX_PERFECTS:
		var pip := Rect2(-((MAX_PERFECTS - 1) * 7.0) / 2.0 + index * 7.0 - 2.0, HEIGHT / 2.0 + 4.0, 4.0, 4.0)
		draw_rect(pip, Color(0.02, 0.02, 0.04, 0.9))
		draw_rect(pip.grow(-1.0), UITheme.GOLD if index < perfects else Color(0.3, 0.3, 0.34))
