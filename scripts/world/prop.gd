class_name Prop
extends Node2D
## A thing standing in the world: a pillar, a chest, an altar, a cave mouth.
## Some are only scenery; others do something when the player presses F.

const SHEET: Texture2D = preload("res://assets/sprites/props.png")
const FRAMES := 14
const REACH := 70.0
const DECOR: Texture2D = preload("res://assets/sprites/decor.png")
const DECOR_FRAMES := 34
enum Decor { FLOOR, RUBBLE, STATUE, BRAZIER, BANNER, BONES, CRATE, BARREL, WELL, FENCE, LANTERN, STALL, SIGNPOST,
	RUG, SHELF, PLANT_POT, TABLE, CHAIR, CANDLES, CAGE, TENT, OBELISK, PALISADE, SPIKE_TRAP, BALLISTA, SOIL, SCARECROW,
	TORCH, FIREPLACE, WAYSTONE, WAYSTONE_LIT, GRAVESTONE, RUINED_TOWER, CART }
static var LIGHT: Texture2D = _make_light()
## Frame numbers in the sheet.
enum Art { PILLAR, WALL, CHEST, CHEST_OPEN, ALTAR, CAVE, PORTAL, LADDER, TABLE, BED, DOOR, CAMPFIRE, TOTEM, HOUSE }

## What the prompt says, e.g. "Open the chest". Empty for scenery.
var prompt_text := ""
## Called with the player when they interact.
var on_interact: Callable
## How close the player must be to use it; big things reach further.
var reach := REACH
## Free text for whoever placed this (a structure key, a kind name).
var tag := ""

var _sprite: Sprite2D
## Hits left before a crate or barrel breaks (0: it can't be broken).
var hits_left := 0
## Crates and barrels broken in the world, by where they stood; saved with
## the structures, so a broken one stays broken.
static var broken: Dictionary = {}


## `solid` is the radius of the collision circle, or 0 to walk through.
static func create(art: Art, at: Vector2, solid: float = 0.0, prompt: String = "", action: Callable = Callable()) -> Prop:
	var prop := Prop.new()
	prop.position = at
	prop.prompt_text = prompt
	prop.on_interact = action
	prop._sprite = Sprite2D.new()
	prop._sprite.texture = SHEET
	prop._sprite.hframes = FRAMES
	prop._sprite.frame = art
	prop._sprite.position.y = -22.0
	prop._sprite.add_to_group("occluders")
	prop.add_child(prop._sprite)
	if solid > 0.0:
		var body := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = solid
		shape.shape = circle
		body.add_child(shape)
		prop.add_child(body)
	if prompt != "":
		prop.add_to_group("props")
	return prop


## Things lying flat on the floor cast no shadow.
const FLAT_ART: Array[int] = [Art.CAVE, Art.LADDER, Art.DOOR, Art.PORTAL]
const FLAT_DECOR: Array[int] = [Decor.FLOOR, Decor.RUBBLE, Decor.BONES, Decor.RUG, Decor.SOIL, Decor.SPIKE_TRAP]


func _ready() -> void:
	if hits_left > 0 and broken.has(break_key()):
		queue_free()
		return
	if z_index < 0 or _sprite == null:
		return
	var flat: Array[int] = FLAT_DECOR if _sprite.texture == DECOR else FLAT_ART
	if not _sprite.frame in flat:
		SunShadow.cast(_sprite)
		ContactShadow.under(_sprite)
		_sprite.material = Wind.still
	if _sprite.texture == DECOR and _sprite.frame == Decor.BANNER:
		_sprite.material = Wind.material
	elif _sprite.texture == SHEET and _sprite.frame == Art.PORTAL:
		var swirl := PortalFX.new()
		swirl.position = Vector2(0, -24)
		add_child(swirl)


## A prop drawn from the decor sheet (tools/generate_flora.py) instead.
static var _decor_icons: Dictionary = {}


## One decor frame as an inventory icon.
static func decor_icon(index: int) -> Texture2D:
	if not _decor_icons.has(index):
		var atlas := AtlasTexture.new()
		atlas.atlas = DECOR
		atlas.region = Rect2(index * 64 + 4, 4, 56, 56)
		_decor_icons[index] = atlas
	return _decor_icons[index]


static func create_decor(index: int, at: Vector2, solid: float = 0.0, prompt: String = "", action: Callable = Callable()) -> Prop:
	var prop := create(Art.PILLAR, at, solid, prompt, action)
	prop._sprite.texture = DECOR
	prop._sprite.hframes = DECOR_FRAMES
	prop._sprite.frame = index
	# Crates and barrels found in the world can be smashed open.
	if index == Decor.CRATE or index == Decor.BARREL:
		prop.hits_left = 1 if index == Decor.CRATE else 2
		prop.add_to_group("breakables")
	return prop


func break_key() -> String:
	return "%d,%d" % [roundi(global_position.x), roundi(global_position.y)]


## Takes a blow: a shake, and after enough of them the thing bursts into
## splinters and spills 1 to 3 things.
func take_hit(player: Player) -> void:
	if hits_left <= 0:
		return
	hits_left -= 1
	Audio.play("chop", -6.0, 0.15)
	if hits_left > 0:
		var shake := create_tween()
		for step: float in [3.0, -3.0, 2.0, 0.0]:
			shake.tween_property(_sprite, "position:x", step, 0.04)
		_sprite.modulate = Color(1.5, 1.4, 1.3)
		shake.tween_property(_sprite, "modulate", Color.WHITE, 0.12)
		return
	broken[break_key()] = true
	var wood: Array[Color] = [Color("8a6a48"), Color("6b4f36"), Color("a8875c"), Color("4a3626")]
	if _sprite.frame == Decor.BARREL:
		wood.append(Color("7a7680"))
	Debris.spawn(get_parent(), global_position + Vector2(0, -6), wood, 16)
	Audio.play("hit", -4.0, 0.2)
	var loot: Node = player.get_parent().get_node_or_null("Loot")
	if loot:
		for thing: Variant in roll_breakable(player.leveling.level, _sprite.frame == Decor.BARREL):
			var spot := global_position + Vector2(randf_range(-14.0, 14.0), randf_range(-6.0, 10.0))
			if thing is int:
				loot.drop_gold(thing, spot)
			else:
				loot.drop_item(thing, spot)
	remove_from_group("breakables")
	queue_free()


## What spills out: 1 to 3 things (an int is a pile of gold). Barrels lean
## to food and drink, crates to supplies.
static func roll_breakable(level: int, barrel: bool) -> Array:
	var table: Array = [["oak_wood", 3.0, 1, 3], ["torch", 2.0, 1, 2], ["bandage", 1.5, 1, 2], ["healing_herb", 2.0, 1, 2],
		["health_potion", 0.7, 1, 1], ["wheat_seeds", 1.0, 1, 3], ["leather", 0.8, 1, 2], ["gold", 3.0, 0, 0]]
	if barrel:
		table.append_array([["wild_berries", 3.0, 1, 4], ["bread", 2.0, 1, 2], ["hunters_brew", 1.0, 1, 1], ["carrot", 1.5, 1, 3]])
	var total := 0.0
	for entry: Array in table:
		total += entry[1]
	var result: Array = []
	for i in randi_range(1, 3):
		var roll := randf() * total
		for entry: Array in table:
			roll -= entry[1]
			if roll <= 0.0:
				if entry[0] == "gold":
					result.append(randi_range(2, 6) + level * 2)
				elif ItemDB.ITEMS.has(entry[0]):
					result.append(Item.create(entry[0], randi_range(entry[2], entry[3])))
				break
	return result


## Where the flames sit on things that burn: [where the flame's base
## stands, size, smoke, flame sheet] for each one (candles have several).
const ART_FLAMES := {Art.CAMPFIRE: [[Vector2(0, -5), 1.25, true, "campfire"]],
	Art.ALTAR: [[Vector2(0, -25), 0.85, false, "torch"], [Vector2(-21, -9), 0.3, false, "candle"], [Vector2(21, -9), 0.3, false, "candle"]]}
const DECOR_FLAMES := {
	Decor.BRAZIER: [[Vector2(0, -15), 1.0, true, "brazier"]], Decor.LANTERN: [[Vector2(0, -35), 0.35, false, "candle"]],
	Decor.CANDLES: [[Vector2(-8, -11), 0.3, false, "candle"], [Vector2(0, -17), 0.3, false, "candle"], [Vector2(8, -8), 0.3, false, "candle"]],
	Decor.TORCH: [[Vector2(0, -40), 0.6, false, "torch"]], Decor.FIREPLACE: [[Vector2(0, 3), 1.2, true, "hearth"]],
}


## Adds a warm glow around the prop, for torches, braziers, and lanterns,
## and sets its fire burning.
func add_light(strength: float = 0.9, reach: float = 1.6, tint := Color(1.0, 0.82, 0.55)) -> void:
	var flames: Array = (DECOR_FLAMES if _sprite.texture == DECOR else ART_FLAMES).get(_sprite.frame, [])
	for entry: Array in flames:
		var flame := FlameFX.new()
		flame.position = entry[0]
		flame.size = entry[1]
		flame.smoke = entry[2]
		flame.kind = entry[3]
		add_child(flame)
	var light := FlickerLight.new()
	light.texture = LIGHT
	light.texture_scale = reach
	light.energy = strength
	light.base_energy = strength
	light.base_scale = reach
	light.color = tint
	light.position.y = -30.0
	add_child(light)


func set_art(art: Art) -> void:
	_sprite.frame = art


func sprite() -> Sprite2D:
	return _sprite


## Stops this prop being something to interact with.
func disarm() -> void:
	prompt_text = ""
	remove_from_group("props")


func interact(player: Player) -> void:
	if on_interact.is_valid():
		on_interact.call(player)


static func _make_light() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	return texture
