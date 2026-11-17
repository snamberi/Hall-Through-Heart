class_name ResourceNode
extends Node2D
## A rock, tree, herb, or fishing spot the player can gather from.
##
## The tool matters past being good enough: each tier it has over what the
## node needs works faster, may bring out one more, and makes a finer
## material likelier. About one node in RICH_ONE_IN (of the better ones) is
## rich: it glints, takes longer, yields far more, and while it is worked a
## timing bar (GatherMeter) gives perfect blows for striking on the beat,
## each worth one more and a finer roll. A rich fishing spot is teeming:
## perfect timing lands better fish.

signal harvested(node: ResourceNode)

const SHEET: Texture2D = preload("res://assets/sprites/nodes.png")
const FRAMES := 5
const REACH := 62.0
const RICH_ONE_IN := 6
## Extra work a rich node takes, as a multiple.
const RICH_WORK := 1.6
## Chance per spare tool tier of one more of what is gathered.
const SURPLUS_EXTRA := 0.3

var resource_id := ""
## A rich node: glints, yields far more, and is worked with a timing bar.
var rich := false
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
	rich = absi(hash([cell, resource_id])) % RICH_ONE_IN == 0 and (int(_data["level"]) >= 5 or _data["kind"] == "fish")
	set_process(rich)
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
		sprite.add_to_group("occluders")
		sprite.material = Wind.material
		add_child(sprite)
		SunShadow.cast(sprite)
		solid = 9.0 if _data["kind"] == "tree" else 0.0
	elif _data.has("flora"):
		var plant := Sprite2D.new()
		plant.texture = Flora.SMALL
		plant.region_enabled = true
		plant.region_rect = Flora.small_region(_data["flora"])
		plant.position.y = -14.0
		add_child(plant)
		ContactShadow.under(plant)
	else:
		var sprite := _sprite(_kind["frame"], Color.WHITE)
		match _data["kind"]:
			"ore":
				# A plain boulder with flecks in the ore's colour.
				_sprite(1, tint).material = Wind.still
				sprite.material = Wind.still
				solid = 14.0
				ContactShadow.under(sprite)
			"fish":
				sprite.modulate = Color(0.75, 0.9, 1.0, 0.8)
				sprite.position.y = 0.0
				var tween := create_tween().set_loops()
				tween.tween_property(sprite, "scale", Vector2(1.15, 1.15), 0.9)
				tween.tween_property(sprite, "scale", Vector2(0.9, 0.9), 0.9)
				add_child(FishShoal.new())
	if solid > 0.0:
		var body := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = solid
		shape.shape = circle
		body.add_child(shape)
		add_child(body)


var _glint_time := 0.0


func _process(delta: float) -> void:
	_glint_time += delta
	queue_redraw()


## A rich node glints: small gold crosses that wink in turn about it.
func _draw() -> void:
	if not rich:
		return
	var top := -48.0 if is_tall() else -18.0
	for index in 3:
		var phase := fposmod(_glint_time * 0.8 + index * 0.37, 1.0)
		if phase > 0.35:
			continue
		var size := roundf(sin(phase / 0.35 * PI) * 3.0)
		var at := Vector2(roundf([-9.0, 8.0, -1.0][index]), roundf(top + [4.0, -3.0, -10.0][index]))
		var glow := Color(1.0, 0.86, 0.4, 0.95)
		draw_rect(Rect2(at.x - size, at.y, size * 2.0 + 1.0, 1.0), glow)
		draw_rect(Rect2(at.x, at.y - size, 1.0, size * 2.0 + 1.0), glow)
		draw_rect(Rect2(at.x, at.y, 1.0, 1.0), Color.WHITE)


func kind() -> String:
	return _data["kind"]


## How many tiers the player's tool has over what this needs (0 without one).
func tool_surplus(player: Player) -> int:
	if _kind["tool"] == "":
		return 0
	var tool := player.equipment.tool(_kind["tool"])
	if tool == null:
		return 0
	return maxi(int(tool.definition()["tool"]["tier"]) - int(_data["tier"]), 0)


## The tool this is gathered with: "pickaxe", "hatchet", "rod", or "".
func tool_kind() -> String:
	return _kind["tool"]


## Trees and tall bushes, which the mouse may point at well above the root.
func is_tall() -> bool:
	return tall_look >= 0 or _data.has("tall")


## Brightens while the mouse is on it, so it is clear what a click will hit.
func set_lit(lit: bool) -> void:
	modulate = Color(1.28, 1.26, 1.15) if lit else Color.WHITE


## A tool has struck: shudder, and throw off chips of what it is made of.
func take_blow(from: Vector2) -> void:
	var away := from.direction_to(global_position)
	var chips := "_wood" if kind() == "tree" else "_stone" if kind() == "ore" else "_leaf"
	Gore.spray(get_parent(), global_position + Vector2(0, -14 if is_tall() else -6), chips, -away + Vector2(0, -0.6), 5, false)
	var rest := position
	var tween := create_tween()
	tween.tween_property(self, "position", rest + away * 3.0, 0.05)
	tween.tween_property(self, "position", rest - away * 1.5, 0.07)
	tween.tween_property(self, "position", rest, 0.06)


func profession() -> String:
	return _kind["profession"]


## "Mine Copper Vein", "Mine Rich Iron Vein", "Fish Teeming Fishing Spot".
func prompt() -> String:
	var name := GatherDB.display_name(resource_id)
	if rich:
		name = ("Teeming " if kind() == "fish" else "Rich ") + name
	return "%s %s" % [_kind["verb"], name]


## Why the player cannot gather this, or "".
func blocked_reason(player: Player) -> String:
	if player.professions.level(profession()) < _data["level"]:
		return "Requires %s %d" % [Professions.NAMES[profession()], _data["level"]]
	if _kind["tool"] != "":
		var tool := player.equipment.tool(_kind["tool"])
		if tool == null:
			return "Needs a %s" % ("fishing rod" if _kind["tool"] == "rod" else _kind["tool"])
		if tool.definition()["tool"]["tier"] < _data["tier"]:
			return "Needs a tier %d %s" % [_data["tier"], _kind["tool"]]
	return ""


## Seconds of work for this player to gather it.
func gather_seconds(player: Player) -> float:
	var speed := player.professions.speed_multiplier(profession()) * player.stats.get_stat("gather_speed")
	if _kind["tool"] != "":
		speed *= player.equipment.tool(_kind["tool"]).definition()["tool"]["speed"]
	if kind() == "ore":
		speed *= player.stats.get_stat("mining_efficiency")
	# Each spare tool tier works a tenth faster again.
	speed *= 1.0 + 0.1 * tool_surplus(player)
	return (_kind["seconds"] + _data["level"] * 0.02) / speed * (RICH_WORK if rich else 1.0)


## Gives the player what this yields, then disappears until it regrows.
## `perfects` is how many perfect blows the timing bar gave on a rich node.
func harvest(player: Player, perfects := 0) -> void:
	var skill := player.professions.level(profession())
	var item_id: String = _data["item"]
	var count := randi_range(1, 2) if kind() != "fish" else 1
	var surplus := tool_surplus(player)
	for tier in surplus:
		if randf() < SURPLUS_EXTRA:
			count += 1
	var luck := 0.25 * surplus + (0.5 + 0.35 * perfects if rich else 0.0)
	if rich and kind() != "fish":
		count += 2 + perfects
	if kind() == "fish":
		if randf() < GatherDB.TREASURE_CHANCE * (2.0 if rich else 1.0):
			_give_treasure(player)
			item_id = ""
		else:
			# Perfect timing on a teeming spot hooks finer fish.
			item_id = _roll_fish(skill + (perfects * 12 if rich else 0))
			if rich:
				count += perfects / 2
	if item_id != "":
		if randf() < player.professions.double_chance(profession()):
			count *= 2
		var item := Item.create_rolled(item_id, count, luck)
		if player.inventory.add(item):
			Events.pickup_noted.emit(item.display_name(), count, item.tint().lightened(0.3))
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
		if player.inventory.add(Item.create(seeds)):
			Events.pickup_noted.emit(ItemDB.ITEMS[seeds]["name"], 1, UITheme.GOOD)
	# Ore veins sometimes hold a gem.
	if kind() == "ore" and randf() < (0.04 + skill * 0.0008 + 0.01 * surplus) * (2.0 if rich else 1.0):
		var gem := Item.create(Gems.random_gem(maxi(_data["level"], skill)))
		Events.codex_event.emit("gems_found", 1)
		if player.inventory.add(gem):
			Events.pickup_noted.emit(gem.display_name(), 1, gem.tint())
	player.professions.add_xp(profession(), (10.0 + _data["level"] * 2.0) * (2.5 if rich else 1.0))
	if rich:
		Events.codex_event.emit("rich_nodes", 1)
	harvested.emit(self)
	queue_free()


## Root-tech worked this: what it yields, and it goes until it regrows.
func harvest_by_roots() -> Item:
	var item := Item.create_rolled(_data["item"], randi_range(1, 2))
	Gore.spray(get_parent(), global_position + Vector2(0, -14 if is_tall() else -6), "_wood" if kind() == "tree" else "_stone" if kind() == "ore" else "_leaf", Vector2(0, -1), 8, false)
	harvested.emit(self)
	queue_free()
	return item


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
