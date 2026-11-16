class_name RiftRun
extends Node2D
## One run through a Heart Rift: the clock, the rooms' monsters, and the
## boss at the end. The week's affix on the player holds while inside. When
## the boss falls the hoard appears with the way out, and the run is
## recorded: timed clears go a depth deeper.

var rooms: Array = []          # [{"rect": Rect2i, "enemies": []}]
var boss: Enemy
var limit := 300.0
var level := 1
var affixes: Array[String] = []

var _room: Room
var _player: Player
var _instances: Instances
var _rifts: HeartRift
var _clock := 0.0
var _done := false
var _layer: CanvasLayer
var _label: Label


func setup(room: Room, player: Player, instances: Instances, rifts: HeartRift) -> void:
	_room = room
	_player = player
	_instances = instances
	_rifts = rifts


func _ready() -> void:
	for id in affixes:
		if HeartRift.PLAYER_AFFIXES.has(id):
			_player.stats.set_modifiers("rift", HeartRift.PLAYER_AFFIXES[id]["mods"])
	_instances.left.connect(_on_left, CONNECT_ONE_SHOT)
	_layer = CanvasLayer.new()
	_layer.layer = 5
	add_child(_layer)
	_label = UITheme.strong("", 20, UITheme.GOLD)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04, 0.9))
	_label.add_theme_constant_override("outline_size", 6)
	_label.anchor_left = 0.5
	_label.anchor_right = 0.5
	_label.offset_left = -360.0
	_label.offset_right = 360.0
	_label.offset_top = 128.0
	_label.offset_bottom = 156.0
	_layer.add_child(_label)


func _physics_process(delta: float) -> void:
	if _done or _player.is_dead():
		return
	_clock += delta
	var left := limit - _clock
	var alive := 0
	for info: Dictionary in rooms:
		for enemy: Variant in info["enemies"]:
			if is_instance_valid(enemy) and not enemy.health.is_dead():
				alive += 1
	_label.text = "Depth %d   ·   %s   ·   %d left" % [_rifts.depth, RaceCourse.clock_text(absf(left)) if left >= 0.0 else "+" + RaceCourse.clock_text(-left), alive]
	_label.add_theme_color_override("font_color", UITheme.GOLD if left > 60.0 else (UITheme.BAD if left < 0.0 else Color(1.0, 0.6, 0.35)))
	if not is_instance_valid(boss) or boss.health.is_dead():
		_finish()


func _finish() -> void:
	_done = true
	var timed := _clock <= limit
	var shards := _rifts.record(_clock, timed)
	var last: Dictionary = rooms[-1]
	var center: Vector2 = _room.cell_position((last["rect"] as Rect2i).get_center())
	LightPillar.spawn(_room, center, Color(1.0, 0.3, 0.4))
	Events.codex_event.emit("rifts", 1)
	Events.announcement.emit("RIFT CLOSED" if timed else "RIFT CLEARED, TOO SLOW", "%s  ·  +%d Rift Shards%s" % [
		RaceCourse.clock_text(_clock), shards, "  ·  depth %d next" % _rifts.depth if timed else "  ·  beat %s to go deeper" % RaceCourse.clock_text(limit)])
	_label.text = "Rift closed in %s" % RaceCourse.clock_text(_clock)
	var items: Array = [Item.create("rift_shard", shards).to_dict()]
	for rune in (2 if timed else 1):
		items.append(Item.create(LootGenerator.random_rune()).to_dict())
	var finds := 3 if timed else 2
	for index in finds:
		var rarity := 4 if timed and index == 0 and randf() < 0.35 + 0.03 * _rifts.depth else 3
		items.append(LootGenerator.make_equipment(level, rarity).to_dict())
	_player.inventory.add_gold(int(40 * level * (1.0 + 0.1 * _rifts.depth) * (1.0 if timed else 0.5)))
	var chest := Prop.create(Prop.Art.CHEST, center + Vector2(0, -40), 12.0, "Open the rift's hoard")
	chest.on_interact = func(_p: Player) -> void:
		chest.set_art(Prop.Art.CHEST_OPEN)
		Events.loot_opened.emit({"items": items, "title": "Rift hoard", "take_only": true})
	_room.add_prop(chest)
	_room.add_prop(Prop.create(Prop.Art.PORTAL, center + Vector2(0, 50), 0.0, "Leave the rift", func(_p: Player) -> void: _instances.leave()))


func _on_left() -> void:
	_player.stats.clear_modifiers("rift")
	(_player.get_parent().get_node("Enemies") as EnemySpawner).forced_modifiers.clear()
	if not _done:
		# Walked out (or fell): the rift slips back a depth.
		_rifts.fall_back()
