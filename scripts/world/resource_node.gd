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
const FELL_DATA := preload("res://scripts/world/fell_data.gd")
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
## How much of the work is done, 0 to 1: shown as a notch cut into a tree
## or cracks through a rock, and kept if the work stops and starts again.
var worked := 0.0
## Which side the last blow came from (-1 left, 1 right).
var _struck_from := 1.0
var _marks: Node2D


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
		sprite.region_enabled = true
		var look: int = tall_look if tall_look >= 0 else _data["tall"]
		sprite.texture = Flora.tall_texture(look)
		sprite.region_rect = Flora.tall_region(look)
		sprite.position.y = Flora.tall_offset(look)
		sprite.flip_h = hash(cell) % 2 == 0
		sprite.add_to_group("occluders")
		# Broadleaf trees and bushes turn with the seasons.
		sprite.material = Seasons.material_for(look)
		if Seasons.is_leafy(look):
			add_to_group("leafy_trees")
			set_meta("tall", look)
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
	if _data["kind"] in ["tree", "ore"]:
		# Drawn over the picture: the work done on it.
		_marks = Marks.new()
		_marks.node = self
		add_child(_marks)
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
## `share` is how much of the work is done now (0 to 1), or -1 to leave it.
func take_blow(from: Vector2, share := -1.0) -> void:
	var away := from.direction_to(global_position)
	if share >= 0.0:
		worked = maxf(worked, clampf(share, 0.0, 1.0))
		_struck_from = -1.0 if from.x < global_position.x else 1.0
		if _marks:
			_marks.queue_redraw()
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
	if profession() == "mining":
		speed *= float(RaceTraits.value(player.race(), "mining", 1.0))
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
		elif profession() == "mining" and player.trinkets and player.trinkets.has_power("prospector") and randf() < 0.25:
			count *= 2
		# Races with a knack for it get one more now and then.
		if kind() != "fish" and randf() < float(RaceTraits.value(player.race(), "yield", 0.0)) * (1.0 if profession() == "mining" or player.race() == "goblin" else 0.0):
			count += 1
		var item := Item.create_rolled(item_id, count, luck)
		if player.inventory.add(item):
			Events.pickup_noted.emit(item.display_name(), count, item.tint().lightened(0.3))
			Events.resource_gathered.emit({"resource": resource_id, "item": item_id, "count": count, "kind": kind()})
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


## How far gone it looks: 0 untouched, up to 3 nearly through.
func damage_stage() -> int:
	return clampi(int(worked * 4.0), 0, 3)


## The marks of the work, drawn a pixel at a time over the picture: a
## notch cut into a tree's trunk on the side the axe bites, deeper with
## each stage, its upper face lit and lower in shade, chips round its foot;
## cracks spreading down a rock from its crown, fresh pale edges beside
## them, a chunk knocked out and grit at its foot at the last.
class Marks:
	extends Node2D
	var node: ResourceNode
	const WOOD := [Color("d6b07e"), Color("b08a5c"), Color("8a6642"), Color("4a3424")]
	const CRACK := Color(0.1, 0.09, 0.11)
	const FRESH := Color(0.82, 0.8, 0.78, 0.85)
	static var _masks: Dictionary = {}

	func _draw() -> void:
		var stage := node.damage_stage()
		if stage == 0:
			return
		if node.kind() == "tree":
			_notch(stage)
		else:
			_cracks(stage)

	func _notch(stage: int) -> void:
		var look: int = node.tall_look if node.tall_look >= 0 else int(node._data.get("tall", -1))
		var trunk: Array = FELL_DATA.TRUNKS.get(look, [-4, 4])
		var left := int(trunk[0])
		var right := int(trunk[1])
		if hash(node.cell) % 2 == 0:
			# The tree is drawn mirrored.
			var was := left
			left = -right
			right = -was
		var width := right - left + 1
		var depth := mini(stage * 2 + 1, width - 2)
		var side := node._struck_from
		for dy in range(-3, 4):
			var reach := depth - absi(dy)
			if reach <= 0:
				continue
			var y := -9 + dy
			for d in reach:
				var x := (left + d) if side < 0.0 else (right - d)
				var colour: Color = WOOD[0] if dy < 0 else WOOD[1] if dy == 0 else WOOD[2]
				if d == reach - 1:
					colour = WOOD[3]
				draw_rect(Rect2(x, y, 1, 1), colour)
		# Chips round the foot on the cut side.
		var seed := absi(hash(node.cell))
		for k in stage * 3:
			var cx := (left - 2 - (seed >> k) % 7) if side < 0.0 else (right + 2 + (seed >> k) % 7)
			draw_rect(Rect2(cx, (seed >> (k + 3)) % 4 - 1, 1, 1), WOOD[k % 2])

	func _mask(frame: int) -> Image:
		if not _masks.has(frame):
			var sheet := SHEET.get_image()
			var size := sheet.get_width() / FRAMES
			_masks[frame] = sheet.get_region(Rect2i(frame * size, 0, size, sheet.get_height()))
		return _masks[frame]

	func _cracks(stage: int) -> void:
		var mask := _mask(int(node._kind["frame"]))
		var w := mask.get_width()
		var h := mask.get_height()
		# The picture's top-left, as _sprite() places it.
		var origin := Vector2i(-w / 2, -22 - h / 2)
		var solid := func(x: int, y: int) -> bool:
			if x < 0 or y < 0 or x >= w or y >= h:
				return false
			var p := mask.get_pixel(x, y)
			return p.a > 0.5 and p.r + p.g + p.b > 0.35
		var random := RandomNumberGenerator.new()
		random.seed = hash(node.cell)
		for crack in stage:
			# Start on the rock's crown, somewhere along its top.
			var x := w / 2 + random.randi_range(-10, 10)
			var y := 0
			while y < h and not solid.call(x, y):
				y += 1
			y += 2
			for step in 6 + stage * 4:
				if not solid.call(x, y):
					break
				draw_rect(Rect2(Vector2(origin + Vector2i(x, y)), Vector2.ONE), CRACK)
				if solid.call(x - 1, y):
					draw_rect(Rect2(Vector2(origin + Vector2i(x - 1, y)), Vector2.ONE), FRESH)
				y += 1
				x += random.randi_range(-1, 1)
		if stage >= 3:
			# A chunk knocked out of its shoulder, and grit at its foot.
			var cx := w / 2 + 6
			var cy := 0
			while cy < h and not solid.call(cx, cy):
				cy += 1
			for dy in 3:
				for dx in 4 - dy:
					if solid.call(cx + dx, cy + dy):
						draw_rect(Rect2(Vector2(origin + Vector2i(cx + dx, cy + dy)), Vector2.ONE), Color(0.16, 0.15, 0.17))
			for k in 8:
				draw_rect(Rect2(random.randi_range(-12, 12), random.randi_range(-2, 2), 1, 1), Color(0.5, 0.48, 0.5))


func _sprite(frame: int, tint: Color) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = SHEET
	sprite.hframes = FRAMES
	sprite.frame = frame
	sprite.modulate = tint
	sprite.position.y = -22.0
	add_child(sprite)
	return sprite
