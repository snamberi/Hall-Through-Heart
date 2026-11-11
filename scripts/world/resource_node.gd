class_name ResourceNode
extends Node2D
## A rock, tree, herb, or fishing spot the player can gather from.

signal harvested(node: ResourceNode)

const SHEET: Texture2D = preload("res://assets/sprites/nodes.png")
const FRAMES := 5
const REACH := 62.0

var resource_id := ""
## Which tree or bush from the flora sheet to show, or -1 for the default look.
var tall_look := -1
var cell := Vector2i.ZERO

var _data: Dictionary
var _kind: Dictionary


static func create(id: String, at_cell: Vector2i, world_position: Vector2) -> ResourceNode:
	var node := ResourceNode.new()
	node.resource_id = id
	node.cell = at_cell
	node.position = world_position
	return node


func _ready() -> void:
	add_to_group("resource_nodes")
	_data = GatherDB.RESOURCES[resource_id]
	_kind = GatherDB.KINDS[_data["kind"]]
	var tint := GatherDB.color(resource_id)
	var solid := 0.0
	if tall_look >= 0 or _data.has("tall"):
		# A tree or bush from the flora sheet.
		var sprite := Sprite2D.new()
		sprite.texture = Flora.TALL
		sprite.region_enabled = true
		sprite.region_rect = Flora.tall_region(tall_look if tall_look >= 0 else _data["tall"])
		sprite.position.y = -42.0
		sprite.flip_h = hash(cell) % 2 == 0
		add_child(sprite)
		solid = 9.0 if _data["kind"] == "tree" else 0.0
	elif _data.has("flora"):
		var plant := Sprite2D.new()
		plant.texture = Flora.SMALL
		plant.region_enabled = true
		plant.region_rect = Flora.small_region(_data["flora"])
		plant.position.y = -14.0
		plant.scale = Vector2(1.25, 1.25)
		add_child(plant)
	else:
		var sprite := _sprite(_kind["frame"], Color.WHITE)
		match _data["kind"]:
			"ore":
				# A plain boulder with flecks in the ore's colour.
				_sprite(1, tint)
				solid = 14.0
			"fish":
				sprite.modulate = Color(0.75, 0.9, 1.0, 0.8)
				sprite.position.y = 0.0
				var tween := create_tween().set_loops()
				tween.tween_property(sprite, "scale", Vector2(1.15, 1.15), 0.9)
				tween.tween_property(sprite, "scale", Vector2(0.9, 0.9), 0.9)
	if solid > 0.0:
		var body := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = solid
		shape.shape = circle
		body.add_child(shape)
		add_child(body)


func kind() -> String:
	return _data["kind"]


func profession() -> String:
	return _kind["profession"]


## "Mine Copper Vein" and so on.
func prompt() -> String:
	return "%s %s" % [_kind["verb"], GatherDB.display_name(resource_id)]


## Why the player cannot gather this, or "".
func blocked_reason(player: Player) -> String:
	if player.professions.level(profession()) < _data["level"]:
		return "Requires %s %d" % [Professions.NAMES[profession()], _data["level"]]
	if _kind["tool"] != "":
		var tool := player.inventory.best_tool(_kind["tool"])
		if tool == null:
			return "Needs a %s" % ("fishing rod" if _kind["tool"] == "rod" else _kind["tool"])
		if tool.definition()["tool"]["tier"] < _data["tier"]:
			return "Needs a tier %d %s" % [_data["tier"], _kind["tool"]]
	return ""


## Seconds of work for this player to gather it.
func gather_seconds(player: Player) -> float:
	var speed := player.professions.speed_multiplier(profession()) * player.stats.get_stat("gather_speed")
	if _kind["tool"] != "":
		speed *= player.inventory.best_tool(_kind["tool"]).definition()["tool"]["speed"]
	if kind() == "ore":
		speed *= player.stats.get_stat("mining_efficiency")
	return (_kind["seconds"] + _data["level"] * 0.02) / speed


## Gives the player what this yields, then disappears until it regrows.
func harvest(player: Player) -> void:
	var skill := player.professions.level(profession())
	var item_id: String = _data["item"]
	var count := randi_range(1, 2) if kind() != "fish" else 1
	if kind() == "fish":
		if randf() < GatherDB.TREASURE_CHANCE:
			_give_treasure(player)
			item_id = ""
		else:
			item_id = _roll_fish(skill)
	if item_id != "":
		if randf() < player.professions.double_chance(profession()):
			count *= 2
		var item := Item.create(item_id, count)
		var label := "%s x%d" % [item.display_name(), count] if count > 1 else item.display_name()
		if player.inventory.add(item):
			DamageNumber.spawn_text(get_parent(), player.global_position + Vector2(0, -30), label, item.tint().lightened(0.3), 12)
			Events.resource_gathered.emit({"resource": resource_id, "item": item_id, "count": count})
		else:
			DamageNumber.spawn_text(get_parent(), player.global_position + Vector2(0, -30), "Inventory full", UITheme.BAD, 12)
			return
	# Herbs and grasses sometimes shed seeds.
	if kind() == "herb" and randf() < 0.12:
		var world_node := get_tree().get_first_node_in_group("world") as World
		var tile: int = world_node.tile_type_at_position(global_position) if world_node else -1
		var seeds: String = "frostberry_seeds" if tile in [TerrainTiles.Type.SNOW, TerrainTiles.Type.FROSTPINE] else ["wheat_seeds", "carrot_seeds", "potato_seeds", "pumpkin_seeds"][randi() % 4]
		if randf() < 0.05:
			seeds = "sunroot_seeds"
		player.inventory.add(Item.create(seeds))
	# Ore veins sometimes hold a gem.
	if kind() == "ore" and randf() < 0.04 + skill * 0.0008:
		var gem := Item.create(Gems.random_gem(maxi(_data["level"], skill)))
		Events.codex_event.emit("gems_found", 1)
		if player.inventory.add(gem):
			DamageNumber.spawn_text(get_parent(), player.global_position + Vector2(0, -44), gem.display_name(), gem.tint(), 13)
	player.professions.add_xp(profession(), 10.0 + _data["level"] * 2.0)
	harvested.emit(self)
	queue_free()


func _roll_fish(skill: int) -> String:
	var total := 0.0
	for fish in GatherDB.FISH:
		if skill >= fish[1]:
			total += fish[2]
	var roll := randf() * total
	for fish in GatherDB.FISH:
		if skill >= fish[1]:
			roll -= fish[2]
			if roll <= 0.0:
				return fish[0]
	return "minnow"


func _give_treasure(player: Player) -> void:
	var gold := randi_range(15, 40) * player.leveling.level
	player.inventory.add_gold(gold)
	DamageNumber.spawn_text(get_parent(), player.global_position + Vector2(0, -30), "Sunken treasure: +%d gold" % gold, UITheme.GOLD, 13)


func _sprite(frame: int, tint: Color) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = SHEET
	sprite.hframes = FRAMES
	sprite.frame = frame
	sprite.modulate = tint
	sprite.position.y = -22.0
	add_child(sprite)
	return sprite
