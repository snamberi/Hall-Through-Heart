class_name Dungeon
extends Node2D
## Runs a dungeon once it is built: each room's monsters, the key a cleared
## room gives up, locked doors that take a key, and the boss at the end.

var rooms: Array = []          # [{"rect": Rect2i, "enemies": [], "cleared": bool}]
var doors: Array = []          # [{"cells": [Vector2i], "prop": Prop, "open": bool}]
var boss_id := ""
var level := 1
var on_cleared: Callable

var _room: Room
var _player: Player
var _instances: Instances
var _done := false


func setup(room: Room, player: Player, instances: Instances) -> void:
	_room = room
	_player = player
	_instances = instances


func _physics_process(_delta: float) -> void:
	if _done or _player.is_dead():
		return
	for index in rooms.size():
		var info: Dictionary = rooms[index]
		if info["cleared"]:
			continue
		var alive := (info["enemies"] as Array).filter(func(e: Variant) -> bool: return is_instance_valid(e) and not e.health.is_dead())
		if alive.is_empty() and not (info["enemies"] as Array).is_empty():
			info["cleared"] = true
			if index < rooms.size() - 1:
				_player.inventory.add(Item.create("dungeon_key"))
				Events.announcement.emit("ROOM CLEARED", "You found a Dungeon Key")
			else:
				_finish()


## Opens door `index` if the player has a key.
func try_door(index: int) -> void:
	var door: Dictionary = doors[index]
	if door["open"]:
		return
	if not _player.inventory.take("dungeon_key", 1):
		Events.announcement.emit("LOCKED", "Clear a room to find a key")
		return
	door["open"] = true
	for cell: Vector2i in door["cells"]:
		_room.set_tile(cell, TerrainTiles.Type.CAVE_FLOOR)
	if is_instance_valid(door["prop"]):
		door["prop"].queue_free()
	Audio.play("hit", -6.0)


func _finish() -> void:
	_done = true
	var last: Dictionary = rooms[-1]
	var center: Vector2 = _room.cell_position((last["rect"] as Rect2i).get_center())
	LightPillar.spawn(_room, center, BossDB.BOSSES[boss_id]["color"])
	Events.announcement.emit("THE CRYPT IS CLEARED", "%s is no more" % BossDB.BOSSES[boss_id]["name"])
	Events.boss_defeated.emit(boss_id)
	Events.codex_event.emit("dungeons", 1)
	var items := BossDB.drops(boss_id, level)
	var chest := Prop.create(Prop.Art.CHEST, center + Vector2(0, -40), 12.0, "Open the boss's hoard")
	chest.on_interact = func(_p: Player) -> void:
		chest.set_art(Prop.Art.CHEST_OPEN)
		Events.loot_opened.emit({"items": items, "title": "Hoard", "take_only": true})
	_room.add_prop(chest)
	_room.add_prop(Prop.create(Prop.Art.PORTAL, center + Vector2(0, 50), 0.0, "Leave the crypt", func(_p: Player) -> void: _instances.leave()))
	if on_cleared.is_valid():
		on_cleared.call()
