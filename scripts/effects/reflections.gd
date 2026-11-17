class_name Reflections
extends Node2D
## Still water holds what stands at its edge: the trees on the bank, the
## houses, the player and whoever else walks or swims there, upside down
## below their feet, dimmed and cooled by the water, and cut into shivering
## rows by the ripples. The sky in the water (clouds, stars, the moon) is
## WaterSurface's; these are the things.
##
## Each reflected thing gets a mirror copy of its sprites (the same
## pictures, frames, colours and wind), kept in step every frame and flipped
## about the line of its feet. The copies are drawn into a view of their
## own that follows the camera; that picture is then laid on the world
## through the water's shape, each row of it shifted a pixel this way or
## that as the ripples pass, the odd row faded, the whole dimmed and cooled.

## How the water dims what it holds (and lets the water through).
const TINT := Color(0.62, 0.74, 0.86, 0.46)
## Things further than this from the player are not looked at.
const REACH := 760.0
const MOST := 36
## How far below its feet water must lie for a thing to be reflected.
const LOOK_DOWN := [10.0, 40.0, 76.0]
const SHADER := """
shader_type canvas_item;
uniform sampler2D land_mask : filter_linear;
uniform sampler2D noise : repeat_enable, filter_linear;
uniform vec2 mask_origin = vec2(0.0);
uniform vec2 mask_size = vec2(1.0);
uniform float wave_time = 0.0;
uniform vec4 tint : source_color = vec4(1.0);
// Screen pixels to a world unit, and the picture's size in screen pixels.
uniform float zoom = 2.0;
uniform vec2 picture_size = vec2(1280.0, 720.0);
varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 cell = floor(world / 2.0);
	vec2 px = cell * 2.0 + 1.0;
	vec2 uv = (px - mask_origin) / mask_size;
	vec2 texel = 1.0 / vec2(textureSize(land_mask, 0));
	float land = texture(land_mask, uv).r;
	float own = texture(land_mask, (floor(uv / texel) + 0.5) * texel).r;
	float d = (0.5 - land) * 44.0 + (texture(noise, px / 300.0).r - 0.5) * 6.0;
	// Open water only: clear of the banks' ragged edges.
	bool water = own < 0.5 && (land < 0.002 || d > 12.0);
	vec4 c = vec4(0.0);
	if (water) {
		// Each row slides a whole pixel this way or that as ripples pass.
		float wobble = texture(noise, vec2(cell.y * 0.19, wave_time * 0.11)).r;
		float shift = floor((wobble - 0.5) * 3.2 + 0.5) * 2.0;
		c = texture(TEXTURE, UV + vec2(shift * zoom / picture_size.x, 0.0));
		// Some rows broken up by the ripples.
		float ripple = texture(noise, vec2(px.x / 58.0 + wave_time * 0.045, cell.y * 0.37)).r;
		float keep = ripple > 0.68 ? 0.2 : 1.0;
		c = vec4(c.rgb * tint.rgb, c.a * tint.a * keep);
	}
	COLOR = c;
}
"""

## Groups whose members may stand at the water's edge.
const GROUPS: Array[String] = ["player", "remote_players", "npcs", "enemies", "critters", "livestock", "summons", "resource_nodes", "reflects", "props", "occluders"]

var _player: Player
var _world: World
var _ground: GroundFX
var _material: ShaderMaterial
var _view: SubViewport
var _view_camera: Camera2D
var _holder: Node2D
var _picture_rect := Rect2()
## root -> {"pairs": [[source, copy], ...]}
var _mirrored: Dictionary = {}
var _look_left := 0.0
var _wave_time := 0.0


func setup(player: Player, world: World, ground: GroundFX) -> void:
	_player = player
	_world = world
	_ground = ground
	z_as_relative = false
	z_index = -9
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var shader := Shader.new()
	shader.code = SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.set_shader_parameter("noise", WaterSurface.shared_material().get_shader_parameter("noise"))
	_material.set_shader_parameter("tint", TINT)
	material = _material
	# The copies live in a view of their own, seen through a camera that
	# keeps pace with the game's.
	_view = SubViewport.new()
	_view.transparent_bg = true
	_view.disable_3d = true
	_view.snap_2d_transforms_to_pixel = true
	_view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_view)
	_view_camera = Camera2D.new()
	_view.add_child(_view_camera)
	_view_camera.make_current()
	_holder = Node2D.new()
	_view.add_child(_holder)


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var on := not _player.indoors and GameSettings.shader_level() > 0
	visible = on
	if not on:
		if not _mirrored.is_empty():
			_clear()
		return
	_wave_time = fmod(_wave_time + delta, 600.0)
	_material.set_shader_parameter("wave_time", _wave_time)
	var mask := _ground.mask_texture()
	if mask:
		_material.set_shader_parameter("land_mask", mask)
		_material.set_shader_parameter("mask_origin", _ground.mask_rect().position)
		_material.set_shader_parameter("mask_size", _ground.mask_rect().size)
	# The view follows the game's camera exactly, pixel for pixel.
	var camera := get_viewport().get_camera_2d()
	var screen := Vector2i(get_viewport().get_visible_rect().size)
	if _view.size != screen:
		_view.size = screen
	var zoom := camera.zoom if camera else Vector2.ONE
	var centre := camera.get_screen_center_position() if camera else _player.global_position
	_view_camera.zoom = zoom
	_view_camera.global_position = centre
	var span := Vector2(screen) / zoom
	_picture_rect = Rect2(centre - span / 2.0, span)
	_material.set_shader_parameter("zoom", zoom.x)
	_material.set_shader_parameter("picture_size", Vector2(screen))
	_look_left -= delta
	if _look_left <= 0.0:
		_look_left = 0.3
		_look()
	_follow()
	queue_redraw()


func _draw() -> void:
	if not _mirrored.is_empty():
		draw_texture_rect(_view.get_texture(), _picture_rect, false)


## Who stands by the water now: reflected from now on; who has walked off
## stops being.
func _look() -> void:
	var wanted: Array = []
	var seen := {}
	for group in GROUPS:
		for node in get_tree().get_nodes_in_group(group):
			# Occluders are the pictures of props and trees: reflect their owner.
			var thing := (node.get_parent() if group == "occluders" else node) as Node2D
			if thing == null or seen.has(thing) or not thing.is_visible_in_tree():
				continue
			seen[thing] = true
			if thing.global_position.distance_to(_player.global_position) > REACH:
				continue
			if _by_water(thing.global_position):
				wanted.append(thing)
	wanted.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_squared_to(_player.global_position) < b.global_position.distance_squared_to(_player.global_position))
	wanted.resize(mini(wanted.size(), MOST))
	for root: Variant in _mirrored.keys():
		if not is_instance_valid(root) or not root in wanted:
			_drop(root)
	for root: Node2D in wanted:
		if not _mirrored.has(root):
			_mirror(root)
	# Further back first, so the nearer reflections lie over them.
	var order := _mirrored.keys()
	order.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.global_position.y < b.global_position.y)
	var index := 0
	for root: Node2D in order:
		for pair: Array in _mirrored[root]["pairs"]:
			_holder.move_child(pair[1], index)
			index += 1


func _by_water(foot: Vector2) -> bool:
	for down: float in LOOK_DOWN:
		if TerrainTiles.is_water(_world.tile_type_at_position(foot + Vector2(0, down))):
			return true
	return false


func _mirror(root: Node2D) -> void:
	var pairs: Array = []
	_collect(root, pairs, 0)
	if pairs.is_empty():
		return
	_mirrored[root] = {"pairs": pairs}


## Every picture under a thing, but not shadows, lights or effects.
func _collect(node: Node, pairs: Array, depth: int) -> void:
	if depth > 5:
		return
	for child in node.get_children():
		if child is Camera2D or child is CanvasLayer or child is SunShadow:
			continue
		if child is CanvasItem and not (child as CanvasItem).z_as_relative:
			continue
		if child is Sprite2D or child is AnimatedSprite2D:
			var source := child as Node2D
			if source.material == SunShadow.shared or source.name.to_lower().contains("shadow"):
				continue
			if child is Sprite2D and (child as Sprite2D).texture == Prop.LIGHT:
				continue
			var copy: Node2D = Sprite2D.new() if child is Sprite2D else AnimatedSprite2D.new()
			copy.material = _material_of(source)
			if copy is AnimatedSprite2D:
				(copy as AnimatedSprite2D).sprite_frames = (source as AnimatedSprite2D).sprite_frames
			_holder.add_child(copy)
			pairs.append([source, copy])
		_collect(child, pairs, depth + 1)


## The material a sprite is really drawn with (it may borrow its parent's).
func _material_of(item: CanvasItem) -> Material:
	var at := item
	while at and at.use_parent_material and at.get_parent() is CanvasItem:
		at = at.get_parent() as CanvasItem
	return at.material if at else null


func _drop(root: Variant) -> void:
	for pair: Array in _mirrored[root]["pairs"]:
		if is_instance_valid(pair[1]):
			(pair[1] as Node).queue_free()
	_mirrored.erase(root)


func _clear() -> void:
	for root: Variant in _mirrored.keys():
		_drop(root)


## Keeps every copy in step with its picture, turned over at the feet.
func _follow() -> void:
	for root: Variant in _mirrored.keys():
		if not is_instance_valid(root):
			_drop(root)
			continue
		var foot: float = (root as Node2D).global_position.y
		var flip := Transform2D(Vector2(1, 0), Vector2(0, -1), Vector2(0, 2.0 * foot))
		var tint := (root as CanvasItem).modulate
		for pair: Array in _mirrored[root]["pairs"]:
			var copy: Node2D = pair[1]
			# A picture can go before its owner does (a dropped weapon).
			if not is_instance_valid(pair[0]):
				copy.visible = false
				continue
			var source: Node2D = pair[0]
			copy.visible = source.is_visible_in_tree()
			if not copy.visible:
				continue
			copy.transform = flip * source.global_transform
			copy.modulate = tint * source.modulate
			copy.self_modulate = source.self_modulate
			if source is Sprite2D:
				var a := source as Sprite2D
				var b := copy as Sprite2D
				b.texture = a.texture
				b.region_enabled = a.region_enabled
				b.region_rect = a.region_rect
				b.hframes = a.hframes
				b.vframes = a.vframes
				b.frame = a.frame
				b.flip_h = a.flip_h
				b.flip_v = a.flip_v
				b.offset = a.offset
				b.centered = a.centered
			else:
				var a := source as AnimatedSprite2D
				var b := copy as AnimatedSprite2D
				if b.sprite_frames != a.sprite_frames:
					b.sprite_frames = a.sprite_frames
				if b.animation != a.animation:
					b.animation = a.animation
				b.frame = a.frame
				b.flip_h = a.flip_h
				b.flip_v = a.flip_v
				b.offset = a.offset
				b.centered = a.centered
			copy.material = _material_of(source)
