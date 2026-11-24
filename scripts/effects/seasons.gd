class_name Seasons
extends RefCounted
## The year turns: spring, summer, autumn and winter, DAYS days each. The
## leaves of the broadleaf trees and bushes follow it: fresh green with a
## sprinkle of blossom in spring, full green in summer, gold, orange or red
## in autumn (each tree its own), bare twigs in winter. Pines, dead trees,
## mushrooms and the like keep their look.
##
## Each species' canopy is drawn in four to six tones; its material knows
## where one tone ends and the next begins, and swaps each for the same
## step of the season's ramp, so the shading and the pixel clusters stay
## the artist's and only the colours turn. Near the end of a season the
## leaves change a few at a time, tree by tree.

const NAMES: Array[String] = ["Spring", "Summer", "Autumn", "Winter"]
const DAYS := 6
## The last share of a season over which the leaves turn to the next.
const TURNING := 0.3

## Ramps, darkest to lightest (shadows cool, lights warm).
const RAMPS := {
	"spring": [Color8(34, 66, 28), Color8(54, 104, 38), Color8(88, 146, 52), Color8(132, 190, 70), Color8(196, 232, 120)],
	"summer": [Color8(31, 62, 30), Color8(47, 90, 42), Color8(74, 122, 58), Color8(106, 154, 74), Color8(154, 202, 106)],
	"gold": [Color8(92, 54, 22), Color8(150, 96, 26), Color8(208, 148, 36), Color8(240, 194, 64), Color8(254, 232, 138)],
	"orange": [Color8(74, 36, 18), Color8(138, 68, 32), Color8(192, 106, 42), Color8(232, 152, 58), Color8(248, 200, 104)],
	"red": [Color8(60, 14, 20), Color8(122, 26, 36), Color8(176, 42, 52), Color8(220, 74, 76), Color8(255, 154, 136)],
	"rust": [Color8(64, 34, 22), Color8(104, 56, 30), Color8(146, 84, 40), Color8(186, 120, 56), Color8(222, 170, 98)],
	"twig": [Color8(36, 28, 22), Color8(52, 40, 30), Color8(70, 54, 40), Color8(88, 70, 52), Color8(110, 90, 68)],
}
const BLOSSOM := [Color8(232, 176, 198), Color8(255, 232, 242)]

## What a canopy does in each season: 0 keeps the drawing, 1 spring green
## (with blossom), 2 summer green, 3 autumn (gold, orange or red by tree),
## 4 orange, 5 red, 6 rust, 7 bare twigs.
const KEEP := 0
const SPRING := 1
const SUMMER := 2
const AUTUMN := 3
const ORANGE := 4
const RED := 5
const RUST := 6
const BARE := 7

## Tall sheet index -> [tone boundaries (luma), canopy line (share of the
## picture's height), modes for spring, summer, autumn, winter].
const SPECIES := {
	Flora.Tall.OAK: [Vector4(0.237, 0.337, 0.453, 0.602), 1.0, [SPRING, KEEP, AUTUMN, BARE], true],
	Flora.Tall.OAK_2: [Vector4(0.237, 0.337, 0.453, 0.602), 1.0, [SPRING, KEEP, AUTUMN, BARE], true],
	Flora.Tall.BROAD_OAK: [Vector4(0.237, 0.337, 0.453, 0.602), 1.0, [SPRING, KEEP, AUTUMN, BARE], true],
	Flora.Tall.TALL_OAK: [Vector4(0.237, 0.337, 0.453, 0.602), 1.0, [SPRING, KEEP, AUTUMN, BARE], true],
	Flora.Tall.AUTUMN_OAK: [Vector4(0.255, 0.41, 0.568, 0.723), 0.54, [SPRING, SUMMER, KEEP, BARE]],
	Flora.Tall.RED_MAPLE: [Vector4(0.165, 0.273, 0.394, 0.588), 0.5, [SPRING, SUMMER, KEEP, BARE]],
	Flora.Tall.CHERRY: [Vector4(0.378, 0.544, 0.704, 0.849), 0.54, [KEEP, SUMMER, ORANGE, BARE]],
	Flora.Tall.BUSH: [Vector4(0.237, 0.337, 0.452, 0.6), 1.0, [SPRING, KEEP, RUST, BARE], true],
	Flora.Tall.BERRY_BUSH: [Vector4(0.237, 0.337, 0.452, 0.6), 1.0, [SPRING, KEEP, RUST, BARE], true],
	# The grand broadleaves: painted in the summer greens; only green pixels
	# turn (bark, fruit and blossom keep their colours).
	Flora.Tall.GREAT_OAK: [Vector4(0.237, 0.337, 0.452, 0.6), 1.0, [SPRING, KEEP, AUTUMN, BARE], true],
	Flora.Tall.BIRCH: [Vector4(0.237, 0.337, 0.452, 0.6), 1.0, [SPRING, KEEP, AUTUMN, BARE], true],
	Flora.Tall.APPLE: [Vector4(0.237, 0.337, 0.452, 0.6), 1.0, [SPRING, KEEP, AUTUMN, BARE], true],
	Flora.Tall.BEECH: [Vector4(0.237, 0.337, 0.452, 0.6), 1.0, [SPRING, KEEP, AUTUMN, BARE], true],
	Flora.Tall.GREAT_WILLOW: [Vector4(0.237, 0.337, 0.452, 0.6), 1.0, [SPRING, KEEP, AUTUMN, BARE], true],
}

static var _materials: Dictionary = {}
static var _shader: Shader


## Where in the year a day and hour fall: 0..4, a season a step.
static func position(day: int, time: float) -> float:
	return fmod(float(maxi(day, 1) - 1) + time, float(DAYS * 4)) / float(DAYS)


static func index(day: int, time: float = 0.0) -> int:
	return int(floorf(position(day, time))) % 4


static func name_of(day: int, time: float = 0.0) -> String:
	return NAMES[index(day, time)]


## How far the leaves have turned toward the next season (0 most of the way).
static func turning(day: int, time: float) -> float:
	var through := fmod(position(day, time), 1.0)
	return clampf((through - (1.0 - TURNING)) / TURNING, 0.0, 1.0)


static func is_leafy(tall: int) -> bool:
	return SPECIES.has(tall)


## The material a broadleaf tree or bush wears (it sways like every tree).
static func material_for(tall: int) -> ShaderMaterial:
	if not SPECIES.has(tall):
		return Wind.trees
	if not _materials.has(tall):
		if _shader == null:
			_shader = Shader.new()
			_shader.code = Wind.LEAFY_SHADER
		var entry: Array = SPECIES[tall]
		var material := ShaderMaterial.new()
		material.shader = _shader
		material.set_shader_parameter("cuts", entry[0])
		material.set_shader_parameter("canopy_line", entry[1])
		material.set_shader_parameter("green_only", entry.size() > 3 and entry[3])
		if tall >= Flora.FIRST_GRAND:
			material.set_shader_parameter("reach", 64.0)
		var modes: Array = entry[2]
		material.set_shader_parameter("modes", Vector4(modes[0], modes[1], modes[2], modes[3]))
		for key: String in RAMPS:
			var ramp: Array = RAMPS[key]
			for k in 5:
				material.set_shader_parameter("%s_%d" % [key, k], ramp[k])
		material.set_shader_parameter("blossom_0", BLOSSOM[0])
		material.set_shader_parameter("blossom_1", BLOSSOM[1])
		material.set_shader_parameter("sway_frames", 4)
		Wind.copy_state(material)
		_materials[tall] = material
	return _materials[tall]


static func all_materials() -> Array:
	return _materials.values()


## Moves every leafy material to the hour of the year.
static func update(day: int, time: float) -> void:
	var now := index(day, time)
	var next := (now + 1) % 4
	var blend := turning(day, time)
	for material: ShaderMaterial in _materials.values():
		material.set_shader_parameter("season_a", now)
		material.set_shader_parameter("season_b", next)
		material.set_shader_parameter("season_blend", blend)
