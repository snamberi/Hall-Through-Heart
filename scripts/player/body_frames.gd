class_name BodyFrames
extends RefCounted
## Written by tools/generate_people.py: do not edit by hand.
##
## The body has a sheet per height and build (people/body_h<h>_b<b>.png);
## layers are drawn for the average one. A layer worn on the head or
## body moves up by `lift(height)` pixels; one held in a hand also moves
## out by `arm_out(build)`. Frames turned for rolls and falls turn that
## shift with them (`turns`: quarter turns clockwise per frame).

const AVERAGE_HEIGHT := 2
const AVERAGE_BUILD := 1
const HEIGHT_ROWS: Array[int] = [2, 3, 4, 5, 6]
const ARM_OUT: Array[int] = [-1, 0, 1]
const TURNS := {"idle": [0, 0, 0, 0], "walk": [0, 0, 0, 0, 0, 0, 0, 0], "run": [0, 0, 0, 0, 0, 0, 0, 0], "attack": [0, 0, 0, 0, 0, 0], "heavy": [0, 0, 0, 0, 0, 0, 0, 0], "dodge": [0, 1, 2, 3, 0, 0, 0], "hurt": [0, 0, 0], "death": [0, 0, 0, 0, 0, 3, 3, 3], "rebirth": [3, 3, 0, 0, 0, 0, 0, 0], "ride": [0, 0, 0, 0], "thrust": [0, 0, 0, 0, 0, 0], "smash": [0, 0, 0, 0, 0, 0, 0], "shoot": [0, 0, 0, 0, 0, 0], "cast": [0, 0, 0, 0, 0, 0], "idle_warrior": [0, 0, 0, 0], "idle_guardian": [0, 0, 0, 0], "idle_ranger": [0, 0, 0, 0], "idle_assassin": [0, 0, 0, 0], "idle_mage": [0, 0, 0, 0], "idle_spellblade": [0, 0, 0, 0], "idle_necromancer": [0, 0, 0, 0], "idle_spellcaster": [0, 0, 0, 0], "idle_back": [0, 0, 0, 0], "idle_side": [0, 0, 0, 0], "walk_back": [0, 0, 0, 0, 0, 0, 0, 0], "run_back": [0, 0, 0, 0, 0, 0, 0, 0], "walk_side": [0, 0, 0, 0, 0, 0, 0, 0], "run_side": [0, 0, 0, 0, 0, 0, 0, 0]}


## Pixels a layer moves up for a height (taller legs lift everything).
static func lift(height: int) -> int:
	return HEIGHT_ROWS[clampi(height, 0, HEIGHT_ROWS.size() - 1)] - HEIGHT_ROWS[AVERAGE_HEIGHT]


## Pixels a held thing moves outward for a build.
static func arm_out(build: int) -> int:
	return ARM_OUT[clampi(build, 0, ARM_OUT.size() - 1)]


## A shift in the frame's own turn: (x, y) turned `turns` quarters clockwise.
static func turned(shift: Vector2i, turns: int) -> Vector2i:
	var out := shift
	for i in posmod(turns, 4):
		out = Vector2i(-out.y, out.x)
	return out
