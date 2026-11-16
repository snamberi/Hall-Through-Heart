class_name AreaBanner
extends Control
## A quiet banner near the top of the screen naming the land underfoot and
## how dangerous it is ("Withered Fields  ·  area level 12") when the player
## walks into a different one. It waits until the new land has held for a
## moment, and the same land is not named again within a minute.

const CHECK_EVERY := 0.5
const SETTLE := 1.0
const REPEAT_AFTER := 60.0
const SHOW_FOR := 3.0

var _player: Player
var _world: World
var _check_left := 0.0
var _current := ""
var _candidate := ""
var _candidate_time := 0.0
var _last_shown: Dictionary = {}
var _title: Label
var _detail: Label
var _tween: Tween


func setup(player: Player) -> void:
	_player = player
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = -300.0
	offset_right = 300.0
	offset_top = 62.0
	offset_bottom = 122.0
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_title = UITheme.heading("", 26)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04, 0.9))
	_title.add_theme_constant_override("outline_size", 6)
	box.add_child(_title)
	_detail = UITheme.label("", 15, UITheme.TEXT)
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04, 0.9))
	_detail.add_theme_constant_override("outline_size", 4)
	box.add_child(_detail)
	modulate.a = 0.0


func _process(delta: float) -> void:
	if _player == null:
		return
	_check_left -= delta
	if _check_left > 0.0:
		return
	_check_left = CHECK_EVERY
	if _world == null:
		_world = _player.get_parent().get_node_or_null("World")
		if _world == null:
			return
	if _player.indoors or _player.is_dead():
		_candidate = ""
		return
	var cell := _world.world_to_cell(_player.global_position)
	var land := TerrainTiles.display_name(_world.generator.tile_type_at(cell))
	if land == _current:
		_candidate = ""
		return
	if land != _candidate:
		_candidate = land
		_candidate_time = 0.0
		return
	_candidate_time += CHECK_EVERY
	if _candidate_time < SETTLE:
		return
	var first := _current == ""
	_current = land
	_candidate = ""
	var now := Time.get_ticks_msec() / 1000.0
	if first or now - float(_last_shown.get(land, -1000.0)) < REPEAT_AFTER:
		return
	_last_shown[land] = now
	show_area(land, _world.generator.enemy_level_at(cell))


func show_area(land: String, level: int) -> void:
	_title.text = land
	var gap := level - _player.leveling.level
	var warning := "  ·  dangerous for your level" if gap >= 8 else ("  ·  a little above you" if gap >= 3 else "")
	_detail.text = "Area level %d%s" % [level, warning]
	_detail.add_theme_color_override("font_color", UITheme.BAD if gap >= 8 else (UITheme.GOLD if gap >= 3 else UITheme.TEXT))
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.4)
	_tween.tween_interval(SHOW_FOR)
	_tween.tween_property(self, "modulate:a", 0.0, 0.8)
