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


func setup(player: Player) -> void:
	_player = player
	_bind(_health_bar, Color(0.62, 0.1, 0.14), func() -> float:
		return player.health.current / player.health.max_health)
	_bind(_xp_bar, Color(0.25, 0.5, 0.9), func() -> float:
		return float(player.leveling.xp) / player.leveling.xp_to_next())
	_bind(_stamina_bar, Color(0.75, 0.62, 0.22), func() -> float:
		return player.stamina.current / player.stamina.max_value)
	_bind(_mana_bar, Color(0.45, 0.35, 0.85), func() -> float:
		return player.mana.current / player.mana.max_value)
	player.health.changed.connect(func(_c: float, _m: float) -> void: _health_bar.queue_redraw())
	player.stamina.changed.connect(func(_c: float, _m: float) -> void: _stamina_bar.queue_redraw())
	player.mana.changed.connect(func(_c: float, _m: float) -> void: _mana_bar.queue_redraw())
	player.leveling.xp_changed.connect(func(_x: int, _r: int) -> void: _refresh())
	player.attributes.changed.connect(_refresh)
	Events.level_up.connect(_on_level_up)
	_death_message.visible = false
	_banner.visible = false
	# Nothing spends mana yet; the bar appears once a class or ability does.
	_mana_bar.visible = false
	_refresh()


func show_death(xp_lost: int, respawn_name: String) -> void:
	_death_summary.text = "Lost %d XP  -  waking at %s" % [xp_lost, respawn_name]
	_death_message.visible = true


func hide_death() -> void:
	_death_message.visible = false


func _refresh() -> void:
	_level_label.text = "Lv %d" % _player.leveling.level
	_points_label.visible = _player.attributes.unspent > 0
	_points_label.text = "%d attribute points to spend - press C" % _player.attributes.unspent
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


func _bind(bar: Control, fill: Color, fraction: Callable) -> void:
	bar.draw.connect(func() -> void:
		var size := bar.size
		bar.draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.75))
		var width: float = (size.x - 4.0) * clampf(fraction.call(), 0.0, 1.0)
		bar.draw_rect(Rect2(Vector2(2, 2), Vector2(width, size.y - 4.0)), fill)
		bar.draw_rect(Rect2(Vector2.ZERO, size), Color(0.55, 0.5, 0.42), false, 1.0)
	)
