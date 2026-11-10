extends CanvasLayer
## On-screen player status: health, experience, stamina, level, and messages.

var _player: Player
var _banner_tween: Tween

@onready var _health_bar: Control = $HealthBar
@onready var _xp_bar: Control = $XPBar
@onready var _stamina_bar: Control = $StaminaBar
@onready var _mana_bar: Control = $ManaBar
@onready var _level_label: Label = $LevelLabel
@onready var _points_label: Label = $PointsLabel
@onready var _banner: Label = $LevelUpBanner
@onready var _banner_detail: Label = $LevelUpBanner/Detail
@onready var _death_message: Label = $DeathMessage
@onready var _death_summary: Label = $DeathMessage/Summary
@onready var _level_up_sound: AudioStreamPlayer = $LevelUpSound
@onready var _buff_label: Label = $BuffLabel


func setup(player: Player) -> void:
	_player = player
	UITheme.apply(self)
	_bind(_health_bar, Color(0.72, 0.13, 0.17), 35, func() -> float:
		return player.health.current / player.health.max_health)
	_bind(_xp_bar, Color(0.95, 0.76, 0.3), -1, func() -> float:
		return float(player.leveling.xp) / player.leveling.xp_to_next())
	_bind(_stamina_bar, Color(0.85, 0.7, 0.25), 37, func() -> float:
		return player.stamina.current / player.stamina.max_value)
	_bind(_mana_bar, Color(0.25, 0.5, 0.95), 36, func() -> float:
		return player.mana.current / player.mana.max_value)
	player.buffs.changed.connect(func() -> void: set_process(true))
	player.health.changed.connect(func(_c: float, _m: float) -> void: _health_bar.queue_redraw())
	player.stamina.changed.connect(func(_c: float, _m: float) -> void: _stamina_bar.queue_redraw())
	player.mana.changed.connect(func(_c: float, _m: float) -> void: _mana_bar.queue_redraw())
	player.leveling.xp_changed.connect(func(_x: int, _r: int) -> void: _refresh())
	player.attributes.changed.connect(_refresh)
	player.talents.changed.connect(_refresh)
	player.class_changed.connect(_refresh)
	Events.level_up.connect(_on_level_up)
	$AbilityBar.setup(player)
	_death_message.visible = false
	_banner.visible = false
	_refresh()


func show_death(xp_lost: int, respawn_name: String) -> void:
	_death_summary.text = "Lost %d XP  -  waking at %s" % [xp_lost, respawn_name]
	_death_message.visible = true


func hide_death() -> void:
	_death_message.visible = false


func _refresh() -> void:
	_level_label.text = "Lv %d" % _player.leveling.level
	var notes: PackedStringArray = []
	if _player.attributes.unspent > 0:
		notes.append("%d attribute points - press C" % _player.attributes.unspent)
	if _player.leveling.talent_points > 0:
		notes.append("%d talent points - press K" % _player.leveling.talent_points)
	if _player.class_id == "adventurer" and _player.leveling.level >= HeroClasses.CHOICE_LEVEL:
		notes.append("Choose a class - press M")
	_points_label.visible = not notes.is_empty()
	_points_label.text = "      ".join(notes)
	_xp_bar.queue_redraw()


func _on_level_up(level: int) -> void:
	_banner_detail.text = "Level %d" % level
	if level % Leveling.MILESTONE_INTERVAL == 0:
		_banner_detail.text += "  -  milestone reached"
	_level_up_sound.play()
	if _banner_tween:
		_banner_tween.kill()
	_banner.visible = true
	_banner.modulate.a = 1.0
	_banner.pivot_offset = _banner.size / 2.0
	_banner.scale = Vector2(0.4, 0.4)
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_interval(1.2)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.6)
	_banner_tween.tween_callback(_banner.hide)


func _process(_delta: float) -> void:
	# Running buffs with their time left, under the bars.
	var lines: PackedStringArray = []
	for id: String in _player.buffs.active:
		lines.append("%s  %ds" % [_player.buffs.active[id]["name"], ceili(_player.buffs.active[id]["time"])])
	_buff_label.text = "\n".join(lines)
	if lines.is_empty():
		set_process(false)


## Draws `bar` as a framed gauge with an optional icon to its left.
func _bind(bar: Control, fill: Color, icon: int, fraction: Callable) -> void:
	bar.draw.connect(func() -> void:
		var size := bar.size
		if icon >= 0:
			bar.draw_texture_rect(ItemDB.icon(icon), Rect2(-26.0, size.y / 2.0 - 11.0, 22.0, 22.0), false)
		bar.draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.05, 0.08, 0.9))
		var width: float = (size.x - 4.0) * clampf(fraction.call(), 0.0, 1.0)
		bar.draw_rect(Rect2(Vector2(2, 2), Vector2(width, size.y - 4.0)), fill)
		bar.draw_rect(Rect2(Vector2(2, 2), Vector2(width, (size.y - 4.0) * 0.35)), fill.lightened(0.25))
		bar.draw_rect(Rect2(Vector2.ZERO, size), Color("402f1c"), false, 2.0)
		bar.draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), Color("8a683a"), false, 1.0)
	)
