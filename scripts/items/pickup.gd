class_name Pickup
extends Node2D
## An item or pile of gold on the ground. Flies to the player when close.

const MAGNET_RADIUS := 110.0
const COLLECT_RADIUS := 22.0
const MAGNET_SPEED := 460.0
const LIFETIME := 180.0

var item: Item
var gold := 0

var _player: Player
var _age := 0.0
var _blocked_left := 0.0
var _sprite: Sprite2D


static func create(player: Player, p_item: Item, p_gold: int = 0) -> Pickup:
	var pickup := Pickup.new()
	pickup._player = player
	pickup.item = p_item
	pickup.gold = p_gold
	return pickup


## Height of the light beam over a dropped item, by rarity (common
## things have none; the rarer the taller).
const BEAM_HEIGHT: Array[float] = [0.0, 34.0, 58.0, 92.0, 132.0, 170.0]


func _ready() -> void:
	add_to_group("pickups")
	_sprite = Sprite2D.new()
	_sprite.texture = item.icon() if item else ItemDB.icon(ItemDB.GOLD_ICON)
	if item:
		_sprite.modulate = item.icon_tint()
	else:
		# A bigger heap for a bigger purse.
		_sprite.scale = Vector2.ONE * clampf(0.85 + log(maxf(gold, 1)) * 0.08, 0.85, 1.35)
	add_child(_sprite)


## Tosses the pickup a short way from where it appeared.
func scatter() -> void:
	var landing := position + Vector2.from_angle(randf() * TAU) * randf_range(14.0, 44.0)
	create_tween().tween_property(self, "position", landing, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _physics_process(delta: float) -> void:
	_age += delta
	_blocked_left = maxf(_blocked_left - delta, 0.0)
	_sprite.position.y = -8.0 + sin(_age * 4.0) * 2.0
	queue_redraw()
	if _age > LIFETIME:
		queue_free()
		return
	if _age < 0.35 or _blocked_left > 0.0 or _player.is_dead():
		return
	var offset := _player.global_position - global_position
	if offset.length() < COLLECT_RADIUS:
		_collect()
	elif offset.length() < MAGNET_RADIUS:
		global_position += offset.normalized() * MAGNET_SPEED * delta


## What lies on the ground shows what it is worth: a column of light in its
## rarity colour rising behind it (taller, wider and brighter the rarer it
## is, with motes drifting up it for Epic and better), a pool of that light
## on the ground, and a glint now and then on a pile of gold. Drawn in hard
## pixel steps to match the art.
func _draw() -> void:
	var pulse := 0.8 + 0.2 * sin(_age * 3.0)
	if item == null:
		# Gold: a soft warm pool, and a star-glint that comes and goes.
		_pixel_pool(Color(1.0, 0.82, 0.3), 7.0, 0.35 * pulse)
		var glint := fmod(_age, 1.6)
		if glint < 0.25:
			var at := (Vector2(4, -12) + Vector2(0, _sprite.position.y + 8.0)).round()
			var size := 1.0 + (1.0 - absf(glint - 0.125) / 0.125) * 2.0
			draw_rect(Rect2(at - Vector2(size, 0.5), Vector2(size * 2.0 + 1.0, 1)), Color(1, 1, 0.9))
			draw_rect(Rect2(at - Vector2(0.5, size), Vector2(1, size * 2.0 + 1.0)), Color(1, 1, 0.9))
		return
	var rarity := clampi(item.rarity, 0, BEAM_HEIGHT.size() - 1)
	var color := item.color()
	var notable := rarity > 0 or item.is_equipment() or item.set_id != ""
	_pixel_pool(color, 6.0 + rarity * 1.5, (0.25 + rarity * 0.08) * pulse if notable else 0.12)
	if not notable:
		return
	var height := maxf(BEAM_HEIGHT[rarity], 24.0)
	var width := 4.0 + rarity * 1.5
	# The beam: bands that fade as they rise, a bright core, and a lit edge.
	var bands := 8
	for band in bands:
		var t := float(band) / bands
		var y0 := 2.0 - height * (band + 1) / bands
		var alpha := (1.0 - t) * (0.32 + rarity * 0.05) * pulse
		var w := roundf(width * (1.0 - t * 0.35))
		draw_rect(Rect2(Vector2(-w, y0).round(), Vector2(w * 2.0, height / bands + 1.0).round()), Color(color, alpha))
		draw_rect(Rect2(Vector2(-1, y0).round(), Vector2(2, height / bands + 1.0).round()), Color(color.lightened(0.6), alpha * 1.6))
	if rarity >= 3:
		# Motes drifting up the beam.
		for mote in rarity:
			var phase := fmod(_age * 0.6 + mote * 0.37, 1.0)
			var x := roundf(sin(mote * 2.3 + _age * 1.5) * (width - 1.0))
			var y := roundf(-phase * height)
			draw_rect(Rect2(x, y, 2, 2), Color(color.lightened(0.5), (1.0 - phase) * 0.9))


## A flat pool of light on the ground, as a stepped pixel ellipse.
func _pixel_pool(color: Color, radius: float, alpha: float) -> void:
	for ring in 3:
		var r := radius * (1.0 - ring * 0.3)
		var rows := int(ceilf(r * 0.45))
		for row in range(-rows, rows + 1):
			var half := roundf(r * sqrt(maxf(0.0, 1.0 - pow(float(row) / (r * 0.45 + 0.01), 2.0))))
			draw_rect(Rect2(-half, 3 + row, half * 2.0, 1), Color(color, alpha * (0.5 + ring * 0.25)))


func _collect() -> void:
	var text_position := _player.global_position + Vector2(0, -20)
	Audio.play("pickup", -8.0)
	if item == null:
		_player.inventory.add_gold(gold)
		DamageNumber.spawn_text(get_parent(), text_position, "+%d gold" % gold, Color(0.95, 0.8, 0.3), 12)
		queue_free()
		return
	var label := item.display_name() if item.count == 1 else "%s x%d" % [item.display_name(), item.count]
	if _player.inventory.add(item):
		DamageNumber.spawn_text(get_parent(), text_position, label, item.color(), 12)
		Events.item_acquired.emit(item.to_dict())
		queue_free()
	else:
		DamageNumber.spawn_text(get_parent(), text_position, "Inventory full", Color(0.9, 0.4, 0.4), 12)
		_blocked_left = 2.5
