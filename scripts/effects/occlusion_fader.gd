class_name OcclusionFader
extends Node
## Trees, houses and tall props see-through while the player stands
## behind them, so the player is never lost from sight.

const REACH := 220.0
const FADED := 0.4

var _player: Player
var _faded: Array = []
var _check_left := 0.0


func setup(player: Player) -> void:
	_player = player


func _process(delta: float) -> void:
	for sprite: Variant in _faded:
		if is_instance_valid(sprite):
			var target: float = sprite.get_meta("fade_to", 1.0)
			sprite.self_modulate.a = move_toward(sprite.self_modulate.a, target, delta * 4.0)
	_check_left -= delta
	if _check_left > 0.0 or _player == null:
		return
	_check_left = 0.08
	var body := _player.global_position + Vector2(0, -18)
	for sprite: Variant in _faded:
		if is_instance_valid(sprite):
			sprite.set_meta("fade_to", 1.0)
	for node in get_tree().get_nodes_in_group("occluders"):
		var sprite := node as Sprite2D
		if sprite == null or not sprite.is_visible_in_tree():
			continue
		var base: float = sprite.get_parent().global_position.y
		if absf(sprite.global_position.x - body.x) > REACH or base <= _player.global_position.y or base - _player.global_position.y > REACH:
			continue
		var rect := sprite.get_rect()
		var local := sprite.to_local(body)
		if rect.grow(-4.0).has_point(local):
			sprite.set_meta("fade_to", FADED)
			if not sprite in _faded:
				_faded.append(sprite)
	_faded = _faded.filter(func(s: Variant) -> bool: return is_instance_valid(s) and (s.get_meta("fade_to", 1.0) < 1.0 or s.self_modulate.a < 0.99))
