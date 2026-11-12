class_name Gore
extends Node2D
## What flies off a creature when it is struck: blood, bone dust, sap,
## sparks or shadow, by what it is made of. Heavier blows and deaths leave
## a splat on the ground that fades after a while.

## monster id -> [colour, kind]  kind: "blood", "dust", "slime", "smoke", "ember", "stone"
const MATTER := {
	"husk": [Color(0.42, 0.1, 0.12), "blood"], "rot_hound": [Color(0.55, 0.08, 0.1), "blood"], "bone_archer": [Color(0.9, 0.88, 0.8), "dust"],
	"bog_slime": [Color(0.5, 0.85, 0.3), "slime"], "carrion_bat": [Color(0.5, 0.06, 0.1), "blood"], "thorn_stalker": [Color(0.5, 0.8, 0.3), "slime"],
	"spore_shambler": [Color(0.8, 0.5, 0.75), "smoke"], "rot_cultist": [Color(0.5, 0.08, 0.12), "blood"], "ember_wisp": [Color(1.0, 0.6, 0.2), "ember"],
	"ash_wraith": [Color(0.75, 0.8, 0.9), "smoke"], "crag_golem": [Color(0.55, 0.53, 0.6), "stone"], "frost_wolf": [Color(0.6, 0.08, 0.12), "blood"],
	"frost_troll": [Color(0.55, 0.1, 0.14), "blood"], "dire_boar": [Color(0.6, 0.08, 0.1), "blood"], "treant": [Color(0.55, 0.4, 0.2), "stone"],
	"sand_scorpion": [Color(0.6, 0.75, 0.3), "slime"], "dune_mummy": [Color(0.85, 0.78, 0.6), "dust"], "void_stalker": [Color(0.6, 0.35, 0.95), "smoke"],
	"void_eye": [Color(0.7, 0.4, 1.0), "smoke"], "crimson_fiend": [Color(0.6, 0.05, 0.08), "blood"], "magma_slime": [Color(1.0, 0.5, 0.15), "ember"],
	"cinder_imp": [Color(1.0, 0.55, 0.2), "ember"], "bog_lurker": [Color(0.45, 0.65, 0.25), "slime"], "storm_harpy": [Color(0.6, 0.08, 0.1), "blood"],
	"marsh_toad": [Color(0.5, 0.75, 0.3), "slime"], "shore_crab": [Color(0.85, 0.5, 0.4), "slime"],
	"_dust": [Color(0.62, 0.56, 0.46), "smoke"],
	"_wood": [Color(0.74, 0.56, 0.32), "stone"], "_stone": [Color(0.62, 0.62, 0.68), "stone"], "_leaf": [Color(0.42, 0.66, 0.3), "stone"],
}

var _drops: Array = []
var _color := Color.RED
var _kind := "blood"
var _life := 0.0
var _splat_life := 0.0
var _splat: PackedVector2Array


static func spray(parent: Node, at: Vector2, monster: String, direction: Vector2, amount: int, splat: bool) -> void:
	var gore := Gore.new()
	var matter: Array = MATTER.get(monster, [Color(0.55, 0.08, 0.1), "blood"])
	gore._color = matter[0]
	gore._kind = matter[1]
	gore.position = at
	gore.z_index = -4 if splat else 5
	for i in amount:
		var angle := direction.angle() + randf_range(-0.9, 0.9) if direction != Vector2.ZERO else randf() * TAU
		var speed := randf_range(60.0, 170.0)
		gore._drops.append({"pos": Vector2(0, -16), "vel": Vector2.from_angle(angle) * speed + Vector2(0, -randf_range(20, 80)), "size": randf_range(1.2, 2.6), "landed": false})
	gore._life = 0.6
	if splat and matter[1] in ["blood", "slime"]:
		gore._splat_life = 6.0
		for k in 7:
			gore._splat.append(Vector2(randf_range(-12, 12), randf_range(-5, 5)))
	parent.add_child(gore)


func _process(delta: float) -> void:
	_life -= delta
	_splat_life -= delta
	for drop: Dictionary in _drops:
		if drop["landed"]:
			continue
		match _kind:
			"smoke", "ember":
				drop["vel"] *= 1.0 - 3.0 * delta
				drop["vel"].y -= 30.0 * delta
			_:
				drop["vel"].y += 520.0 * delta
		drop["pos"] += drop["vel"] * delta
		if _kind in ["blood", "slime", "dust", "stone"] and drop["pos"].y > 4.0 and drop["vel"].y > 0.0:
			drop["landed"] = true
			drop["pos"].y = 4.0 + randf_range(-3, 3)
	if _life <= 0.0 and _splat_life <= 0.0:
		queue_free()
	queue_redraw()


func _draw() -> void:
	if _splat_life > 0.0:
		var fade := clampf(_splat_life / 2.0, 0.0, 1.0) * 0.55
		draw_set_transform(Vector2(0, 4), 0.0, Vector2(1.0, 0.45))
		for point in _splat:
			draw_circle(point, 4.0, Color(_color.darkened(0.25), fade))
		draw_set_transform(Vector2.ZERO)
	var alpha := clampf(_life / 0.6, 0.0, 1.0)
	for drop: Dictionary in _drops:
		var a := alpha if not drop["landed"] else alpha * 0.8
		match _kind:
			"smoke":
				draw_circle(drop["pos"], drop["size"] * (2.5 - alpha), Color(_color, a * 0.5))
			"ember":
				draw_circle(drop["pos"], drop["size"] * alpha, Color(1.0, 0.85, 0.4, a))
			"stone", "dust":
				draw_rect(Rect2(drop["pos"], Vector2(drop["size"], drop["size"])), Color(_color, a))
			_:
				draw_circle(drop["pos"], drop["size"], Color(_color, a))
