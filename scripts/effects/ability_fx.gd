extends Node2D
## Each ability's own look, drawn in whole pixels: flames that lick up in a
## ring, frost shards and snow crystals, forked sparks, shadow pulled in to
## a point, a pillar of light with a halo, sprayed blood and a sigil, bony
## hands and soul-wisps from cracked ground, a turning ring of runes, thrown
## rock and cracks, plates of a shield closing round, the rings of a roar,
## gusting crescents, green motes of mending.
##
## Two ways each: "aura" gathers round the caster (rising, or drawn in, the
## way an absorbing aura pulls power to itself) and "burst" breaks outward
## at a point. AbilityUser picks the style from the ability (style_for).
## (Loaded by path, no class name.)

const STYLES: Array[String] = ["flame", "frost", "storm", "shadow", "holy", "blood", "grave", "arcane",
	"earth", "bulwark", "roar", "wind", "life"]

## The colours of each style, light to dark.
const PALETTE := {
	"flame": [Color("fff2a0"), Color("ffb030"), Color("e8501e"), Color("8a2414")],
	"frost": [Color("ffffff"), Color("b8f0ff"), Color("5ab8e8"), Color("2a6aa8")],
	"storm": [Color("ffffff"), Color("fff27a"), Color("7ad0ff"), Color("3a6ad0")],
	"shadow": [Color("d8a8ff"), Color("8a4ad0"), Color("4a2080"), Color("1a0c2a")],
	"holy": [Color("ffffff"), Color("fff4c0"), Color("f0c860"), Color("b08a30")],
	"blood": [Color("ff8a8a"), Color("e02a3a"), Color("9a1424"), Color("4a0a12")],
	"grave": [Color("d8ffd0"), Color("8af07a"), Color("e8e2c8"), Color("5a5648")],
	"arcane": [Color("f0e0ff"), Color("b88aff"), Color("6a5ae8"), Color("2a2a7a")],
	"earth": [Color("d8c8a0"), Color("a08660"), Color("6e5a3e"), Color("3a2e20")],
	"bulwark": [Color("ffffff"), Color("d8e0ea"), Color("8e9aaa"), Color("4a5260")],
	"roar": [Color("ffffff"), Color("ffe0a0"), Color("e8a040"), Color("8a4a1a")],
	"wind": [Color("ffffff"), Color("d8f4e8"), Color("8ad0b0"), Color("4a8a70")],
	"life": [Color("f0fff0"), Color("9af08a"), Color("4ab85a"), Color("1e6a2e")],
}

var style := "arcane"
var mode := "burst"
var radius := 60.0
var tint := Color.WHITE
## The caster, for an aura that keeps with them.
var follow: Node2D = null
var life := 0.7
var _time := 0.0
## Each effect's own scatter: [angle, distance share, speed share, phase].
var _bits: Array[Vector4] = []


## Plays a style at a point. `mode` is "aura" (round the caster, following
## them if `follow` is given) or "burst" (outward from `at`).
static func play(parent: Node, at: Vector2, style_name: String, mode_name: String, color: Color, reach: float = 60.0, follow_node: Node2D = null) -> void:
	if parent == null:
		return
	var fx: Node2D = load("res://scripts/effects/ability_fx.gd").new()
	fx.style = style_name if PALETTE.has(style_name) else "arcane"
	fx.mode = mode_name
	fx.radius = clampf(reach, 18.0, 220.0)
	fx.tint = color
	fx.follow = follow_node
	fx.life = 0.95 if mode_name == "aura" else 0.65
	fx.position = at.round()
	fx.z_index = 55
	parent.add_child(fx)


## The look for an ability: its own if named here, else from what it does
## to those it strikes, its school of magic, or the words in its name.
static func style_for(id: String, ability: Dictionary) -> String:
	if ability.has("fx"):
		return str(ability["fx"])
	match str(ability.get("status", "")):
		"burn":
			return "flame"
		"chill":
			return "frost"
		"bleed":
			return "blood"
		"poison":
			return "grave"
	match str(ability.get("school", "")):
		"fire":
			return "flame"
		"frost":
			return "frost"
		"lightning":
			return "storm"
		"dark":
			return "shadow"
		"light":
			return "holy"
	var words := (id + " " + str(ability.get("name", ""))).to_lower()
	var keys := [
		[["fire", "flame", "ember", "meteor", "inferno", "cataclysm"], "flame"],
		[["frost", "ice", "glacial", "blizzard", "rime", "chill"], "frost"],
		[["lightning", "spark", "thunder", "storm", "arc_lash", "shock", "echo"], "storm"],
		[["shadow", "umbral", "void", "dark", "smoke", "phase", "rift", "death", "backstab", "veil", "hex"], "shadow"],
		[["holy", "radiant", "smite", "bless", "sanctuary", "aegis"], "holy"],
		[["blood", "heart", "rend", "execution", "impale", "pact"], "blood"],
		[["bone", "raise", "army", "corpse", "grave", "dead", "familiar"], "grave"],
		[["arcane", "mana", "astral", "rune", "sigil", "ward", "spellsunder", "enchant", "elemental", "blink"], "arcane"],
		[["earth", "ground", "stomp", "shatter", "slam", "titan", "quake", "leap", "breaker", "shaker"], "earth"],
		[["iron", "shield", "bastion", "resolve", "skin", "guard", "wall"], "bulwark"],
		[["cry", "roar", "rally", "haste", "surge", "mark"], "roar"],
		[["second_wind", "heal", "mend", "regrow"], "life"],
		[["whirl", "wind", "blade", "knife", "cut", "flurry", "dance", "step", "dash", "volley", "arrow", "shot", "cleav", "sweep"], "wind"],
	]
	for pair: Array in keys:
		for word: String in pair[0]:
			if word in words:
				return pair[1]
	return "arcane"


func _ready() -> void:
	var count := 24 if mode == "burst" else 20
	for i in count:
		_bits.append(Vector4(randf() * TAU, randf(), randf_range(0.6, 1.0), randf()))


func _process(delta: float) -> void:
	_time += delta
	if _time >= life:
		queue_free()
		return
	if follow and is_instance_valid(follow):
		global_position = follow.global_position.round()
	queue_redraw()


func _px(at: Vector2, c: Color, size: int = 1) -> void:
	draw_rect(Rect2(at.floor(), Vector2(size, size)), c)


func _col(i: int, alpha: float) -> Color:
	var c: Color = PALETTE[style][clampi(i, 0, 3)]
	# A touch of the ability's own colour, so two flame moves still differ.
	return Color(c.lerp(tint, 0.15), alpha)


## A ring of pixels, squashed for the ground.
func _ring(r: float, c: Color, gaps: float = 0.0, squash: float = 0.6) -> void:
	var steps := maxi(10, int(TAU * r * 0.8))
	for i in steps:
		var a := TAU * i / steps
		if gaps > 0.0 and fmod(a * 5.0 + _time * 3.0, 1.0) < gaps:
			continue
		_px(Vector2(cos(a), sin(a) * squash) * r, c)
		_px(Vector2(cos(a), sin(a) * squash) * (r - 1.0), Color(c, c.a * 0.6))


func _draw() -> void:
	var t := _time / life
	var fade := 1.0 - pow(t, 2.0)
	var r := radius
	call("_draw_" + style, t, fade, r)


func _draw_flame(t: float, fade: float, r: float) -> void:
	var at := r * (0.35 + 0.65 * (1.0 - pow(1.0 - t, 2.0))) if mode == "burst" else r * 0.45
	var tongues := clampi(int(r / 5.0), 8, 28)
	for i in tongues:
		var a := TAU * i / tongues + _bits[i % _bits.size()].x * 0.2
		var base := Vector2(cos(a), sin(a) * 0.6) * at
		var tall := int((8.0 + 8.0 * _bits[i % _bits.size()].y) * fade * (1.0 + 0.3 * sin(_time * 20.0 + i)))
		for k in tall:
			var shade := 0 if k > tall - 2 else 1 if k > tall / 2 else 2
			var wobble := roundf(sin(_time * 18.0 + i + k * 0.7))
			var wide := 3 if k < tall / 3 else 2 if k < tall * 2 / 3 else 1
			for w in wide:
				_px(base + Vector2(wobble + w - wide / 2, -k), _col(3 - shade if w == wide / 2 else 3 - mini(shade + 1, 3), fade))
	# Embers rising.
	for b in _bits:
		var e := Vector2(cos(b.x), sin(b.x) * 0.6) * at * b.y + Vector2(sin(_time * 6.0 + b.w * 9.0) * 2.0, -t * 40.0 * b.z)
		_px(e, _col(0 if b.w > 0.5 else 1, fade))


func _draw_frost(t: float, fade: float, r: float) -> void:
	var reach := r * (1.0 - pow(1.0 - minf(t * 1.6, 1.0), 3.0))
	if mode == "aura":
		reach = r * 0.55
	# Shards: lines of ice stabbing out, bright at the tip.
	for i in 12:
		var b := _bits[i]
		var a := TAU * i / 12.0 + b.x * 0.15
		var dir := Vector2(cos(a), sin(a) * 0.6)
		var length := int(reach * (0.5 + 0.5 * b.y))
		var start := int(length * 0.35)
		var side := Vector2(-dir.y, dir.x).round()
		for k in range(start, length):
			_px(dir * k, _col(2 if k < length - 3 else 1, fade))
			if k < length - 2:
				_px(dir * k + side, _col(3, fade))
		_px(dir * length, _col(0, fade), 2)
	# Snow crystals: little crosses with bright hearts.
	for i in range(12, _bits.size()):
		var b := _bits[i]
		var p := Vector2(cos(b.x), sin(b.x) * 0.6) * reach * b.y + Vector2(0, -t * 10.0 * b.z)
		for d: Vector2 in [Vector2.ZERO, Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			_px(p + d, _col(0 if d == Vector2.ZERO else 1, fade))
	_ring(reach * 0.9, _col(1, fade * 0.6), 0.5)


func _draw_storm(t: float, fade: float, r: float) -> void:
	# Forked sparks that jump anew a few times a second.
	var flicker := int(_time * 24.0)
	var seed_rng := RandomNumberGenerator.new()
	var bolts := 6 if mode == "burst" else 4
	for i in bolts:
		seed_rng.seed = hash(Vector2i(i, flicker))
		var a := _bits[i].x + _time * (0.0 if mode == "burst" else 3.0)
		var p := Vector2(cos(a), sin(a) * 0.6) * (4.0 if mode == "burst" else r * 0.45)
		var dir := Vector2(cos(a), sin(a) * 0.6).normalized()
		var length := r * (0.6 + 0.4 * _bits[i].y) * (1.0 if mode == "burst" else 0.4)
		var walked := 0.0
		while walked < length:
			_px(p, _col(0 if seed_rng.randf() < 0.3 else 1, fade))
			_px(p + Vector2(1, 0), _col(2, fade * 0.8))
			p += (dir + Vector2(seed_rng.randf_range(-0.9, 0.9), seed_rng.randf_range(-0.9, 0.9))).round()
			walked += 1.0
	if mode == "aura":
		_ring(r * 0.45, _col(2, fade * 0.7), 0.6)


func _draw_shadow(t: float, fade: float, r: float) -> void:
	# Darkness pulled in from all round to a point (or, as an aura, drawn
	# into the caster), then a black heart that closes.
	for b in _bits:
		var pull := 1.0 - fmod(t * 1.6 + b.w, 1.0)
		var a := b.x + (1.0 - pull) * 2.0
		var p := Vector2(cos(a), sin(a) * 0.6) * r * pull * (0.6 + 0.4 * b.y)
		_px(p, _col(1 if pull > 0.5 else 2, fade * (0.4 + 0.6 * (1.0 - pull))), 2 if pull < 0.4 else 1)
		_px(p + Vector2(cos(a), sin(a)).round(), _col(3, fade * 0.6))
	var core := int(6.0 * (1.0 - absf(t * 2.0 - 1.0))) + 1
	for y in range(-core, core + 1):
		for x in range(-core, core + 1):
			if x * x + y * y * 2 <= core * core and (x + y) % 2 == 0:
				_px(Vector2(x, y), _col(3, fade))
	_ring(r * (1.0 - t) * 0.8, _col(2, fade * 0.6), 0.4)


func _draw_holy(t: float, fade: float, r: float) -> void:
	# A pillar of light, a halo, and motes and feathers drifting up.
	var wide := int(lerpf(10.0, 3.0, t))
	var tall := int(60.0 * minf(t * 3.0, 1.0))
	for y in tall:
		for x in range(-wide, wide + 1):
			if absf(x) < wide - 1 or (x + y) % 2 == 0:
				_px(Vector2(x, -y), _col(1 if absf(x) < wide * 0.4 else 2, fade * 0.35 * (1.0 - float(y) / 70.0)))
	if mode == "aura":
		var halo := Vector2(0, -34)
		for i in 20:
			var a := TAU * i / 20.0
			_px(halo + Vector2(cos(a) * 7.0, sin(a) * 2.0), _col(0, fade))
	else:
		# Rays in a cross, and a ring of light on the ground.
		for d: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2(0, 0.6), Vector2(0, -0.6)]:
			for k in int(r * minf(t * 2.0, 1.0)):
				if k % 3 != 2:
					_px(d * k, _col(0 if k < 8 else 1, fade))
		_ring(r * (0.4 + 0.6 * t), _col(2, fade), 0.3)
	for b in _bits:
		var p := Vector2(cos(b.x) * r * 0.5 * b.y, -t * 50.0 * b.z - 4.0 + sin(b.w * 9.0) * 4.0)
		_px(p, _col(0, fade))
		if b.w > 0.7:
			# A feather: a short slanted stroke.
			_px(p + Vector2(1, 1), _col(1, fade))
			_px(p + Vector2(2, 2), _col(2, fade))


func _draw_blood(t: float, fade: float, r: float) -> void:
	if mode == "aura":
		# Blood drawn in from all round to the heart: the absorbing aura.
		for b in _bits:
			var pull := 1.0 - fmod(t * 1.4 + b.w, 1.0)
			var p := Vector2(cos(b.x), sin(b.x) * 0.6) * r * 0.8 * pull + Vector2(0, -14)
			_px(p, _col(1, fade), 2)
			_px(p + Vector2(cos(b.x), sin(b.x) * 0.6).round(), _col(2, fade))
	else:
		# Droplets sprayed out and falling.
		for b in _bits:
			var speed := r * 1.4 * b.z
			var p := Vector2(cos(b.x), sin(b.x) * 0.6) * speed * t + Vector2(0, 90.0 * t * t)
			_px(p, _col(1, fade), 2)
			_px(p + Vector2(0, -1), _col(0, fade))
	# A sigil: a ring with four marks, turning.
	var sr := r * 0.5
	_ring(sr, _col(2, fade * 0.8), 0.0)
	for i in 4:
		var a := TAU * i / 4.0 + _time * 1.5
		var p := Vector2(cos(a), sin(a) * 0.6) * sr
		for k in 4:
			_px(p + Vector2(cos(a), sin(a) * 0.6) * -k, _col(1, fade))


func _draw_grave(t: float, fade: float, r: float) -> void:
	# Cracks spreading through the ground.
	for i in 7:
		var b := _bits[i]
		var p := Vector2.ZERO
		var dir := Vector2(cos(b.x), sin(b.x) * 0.6)
		for k in int(r * 0.7 * minf(t * 2.5, 1.0)):
			p += dir + Vector2(0, (1 if k % 4 == 0 else 0) * sign(sin(b.w * 10.0 + k)))
			_px(p, Color(0.1, 0.12, 0.08, fade * 0.8))
	# Bony hands and shards pushing up out of it.
	for i in range(7, 13):
		var b := _bits[i]
		var at := Vector2(cos(b.x), sin(b.x) * 0.6) * r * 0.5 * b.y
		var rise := int(9.0 * minf(t * 2.5, 1.0) * (1.0 - maxf(0.0, t - 0.7) / 0.3))
		for k in rise:
			_px(at + Vector2(0, -k), _col(2, fade))
		if rise > 5:
			for f in [-2, 0, 2]:
				_px(at + Vector2(f, -rise - 1), _col(2, fade))
				_px(at + Vector2(f, -rise - 2), _col(3, fade))
	# Soul-wisps spiralling up, green.
	for i in range(13, _bits.size()):
		var b := _bits[i]
		var up := fmod(t * 1.5 + b.w, 1.0)
		var p := Vector2(cos(b.x + up * 6.0) * 10.0 * b.y, -up * 46.0)
		_px(p, _col(1, fade * (1.0 - up)), 2)
		_px(p + Vector2(0, 2), _col(0, fade * (1.0 - up) * 0.6))


func _draw_arcane(t: float, fade: float, r: float) -> void:
	# A ring of runes turning, a second one inside turning back, motes drawn
	# inward along spirals.
	var outer := r * (0.55 if mode == "aura" else 0.3 + 0.7 * (1.0 - pow(1.0 - t, 2.0)))
	for ring_index in 2:
		var rr := outer * (1.0 if ring_index == 0 else 0.62)
		var turn := _time * (1.6 if ring_index == 0 else -2.4)
		_ring(rr, _col(2, fade * 0.8), 0.0)
		var marks := 8 if ring_index == 0 else 6
		for i in marks:
			var a := TAU * i / marks + turn
			var p := Vector2(cos(a), sin(a) * 0.6) * rr
			# A small glyph: three pixels in an L or a T, by its place.
			_px(p, _col(0, fade))
			_px(p + Vector2(0, -1), _col(1, fade))
			_px(p + (Vector2(1, 0) if i % 2 == 0 else Vector2(-1, -1)), _col(1, fade))
	for b in _bits:
		var pull := 1.0 - fmod(t * 1.3 + b.w, 1.0)
		var a := b.x + pull * 3.0
		_px(Vector2(cos(a), sin(a) * 0.6) * outer * pull, _col(0 if pull < 0.3 else 1, fade))


func _draw_earth(t: float, fade: float, r: float) -> void:
	# Cracks radiating, rocks thrown up and falling back, dust.
	for i in 8:
		var b := _bits[i]
		var dir := Vector2(cos(b.x), sin(b.x) * 0.6)
		var p := Vector2.ZERO
		for k in int(r * 0.8 * minf(t * 3.0, 1.0)):
			p += dir
			if k % 5 == 4:
				p += Vector2(signf(sin(b.w * 20.0 + k)), 0)
			_px(p, _col(3, fade))
	for i in range(8, 20):
		var b := _bits[i]
		var flat := Vector2(cos(b.x), sin(b.x) * 0.6) * r * 0.8 * b.y * t
		var hop := -sin(minf(t * 1.3, 1.0) * PI) * 28.0 * b.z
		var p := flat + Vector2(0, hop)
		var size := 3 if b.w > 0.6 else 2
		_px(p, _col(2, fade), size)
		_px(p, _col(1, fade))
	for i in range(20, _bits.size()):
		var b := _bits[i]
		var p := Vector2(cos(b.x), sin(b.x) * 0.6) * r * (0.4 + 0.6 * t) * b.y
		for d: Vector2 in [Vector2.ZERO, Vector2(1, 0), Vector2(0, -1), Vector2(-1, 0)]:
			_px(p + d * (1.0 + t * 3.0), _col(0, fade * 0.35))


func _draw_bulwark(t: float, fade: float, r: float) -> void:
	# Six plates of a shield sliding in to close round the caster, a glint
	# sweeping across them once they meet.
	var close := minf(t * 2.5, 1.0)
	var rr := r * 0.45 + (1.0 - close) * 20.0
	for i in 6:
		var a := TAU * i / 6.0 + PI / 6.0
		var b := TAU * (i + 1) / 6.0 + PI / 6.0
		var pa := Vector2(cos(a), sin(a) * 0.75) * rr + Vector2(0, -12)
		var pb := Vector2(cos(b), sin(b) * 0.75) * rr + Vector2(0, -12)
		var steps := int(pa.distance_to(pb))
		for k in steps:
			var p := pa.lerp(pb, float(k) / steps)
			var lit := absf(fmod(t * 2.0, 1.0) - float(i * steps + k) / (6.0 * steps)) < 0.05 and close >= 1.0
			_px(p, _col(0 if lit else 1, fade), 2)
			_px(p + (Vector2(0, -12) - p).normalized().round(), _col(3, fade * 0.7))


func _draw_roar(t: float, fade: float, r: float) -> void:
	# Rings of sound, one after another, and lines of force flying out.
	for k in 3:
		var tt := clampf(t * 1.5 - k * 0.2, 0.0, 1.0)
		if tt <= 0.0 or tt >= 1.0:
			continue
		var rr := r * tt
		var steps := maxi(10, int(TAU * rr * 0.6))
		for i in steps:
			if i % 3 == 0:
				continue
			var a := TAU * i / steps
			_px(Vector2(cos(a), sin(a) * 0.6) * rr + Vector2(0, -12 * (1.0 - tt)), _col(1 + k, fade * (1.0 - tt)))
	for b in _bits:
		var dir := Vector2(cos(b.x), sin(b.x) * 0.6)
		var from := r * (0.2 + t * 0.9) * b.y
		for k in 4:
			_px(dir * (from + k), _col(0, fade * 0.8))


func _draw_wind(t: float, fade: float, r: float) -> void:
	# Crescents of air whirling round, and leaves caught up in them.
	for i in 4:
		var start := TAU * i / 4.0 + _time * 9.0
		var rr := r * (0.4 + 0.6 * t) * (0.7 + 0.3 * _bits[i].y)
		for k in 14:
			var a := start + k * 0.09
			_px(Vector2(cos(a), sin(a) * 0.6) * (rr - k * 0.4), _col(1 if k < 4 else 2, fade * (1.0 - k / 16.0)))
	for i in range(4, 12):
		var b := _bits[i]
		var a := b.x + _time * 7.0
		var p := Vector2(cos(a), sin(a) * 0.6) * r * 0.6 * b.y + Vector2(0, -t * 12.0)
		_px(p, Color("6ab04a", fade))
		_px(p + Vector2(1, 0), Color("3a7a2a", fade))


func _draw_life(t: float, fade: float, r: float) -> void:
	# Little green crosses of mending rising, a soft ring at the feet.
	_ring(r * 0.45, _col(2, fade * 0.7), 0.25)
	for b in _bits:
		var up := fmod(t * 1.2 + b.w, 1.0)
		var p := Vector2(cos(b.x) * r * 0.4 * b.y, -4.0 - up * 40.0)
		var c := _col(0 if b.z > 0.8 else 1, fade * (1.0 - up))
		for d: Vector2 in [Vector2.ZERO, Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			_px(p + d, c)
