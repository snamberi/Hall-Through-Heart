class_name Livestock
extends CharacterBody2D
## A farm animal of your own: a sheep, cow or chicken won over with food.
##
## Feed a wild one (wheat; chickens take seeds too) and it follows you for
## a while. Lead it near your Farmhouse and it settles there for good,
## wandering the farm and leaving its produce in the farmhouse (wool, milk,
## eggs). Feed two settled adults of a kind and they make a baby, which
## grows up in time. The farmhouse record keeps the animals.

const SPECIES := {
	"sheep": {"name": "Sheep", "baby": "lamb", "baby_name": "Lamb", "food": ["wheat"], "produce": "wool", "every": 300.0, "speed": 70.0, "size": 1.0},
	"cow": {"name": "Cow", "baby": "calf", "baby_name": "Calf", "food": ["wheat"], "produce": "milk", "every": 360.0, "speed": 60.0, "size": 1.15},
	"chicken": {"name": "Chicken", "baby": "chick", "baby_name": "Chick", "food": ["wheat", "wheat_seeds"], "produce": "egg", "every": 240.0, "speed": 80.0, "size": 0.8},
}
## Seconds a baby takes to grow up; how long love and following last.
const GROW_SECONDS := 600.0
const LOVE_SECONDS := 30.0
const BREED_COOLDOWN := 300.0
const FOLLOW_SECONDS := 120.0
## How far from its farmhouse an animal roams, and how near one joins it.
const FARM_RADIUS := 280.0
## Unattended, the farm works at this share of its usual pace.
const AWAY_PACE := 0.5

var species := "sheep"
## This animal's saved state: {"species", "baby", "age", "x", "y", "next", "bred"}.
var state: Dictionary = {}
## The farmhouse record it lives at, or empty while it roams.
var farm: Dictionary = {}
var following: Player
var _follow_left := 0.0
var _love_left := 0.0
var _wander_to := Vector2.ZERO
var _wander_left := 0.0
var _sprite: AnimatedSprite2D
var _time := 0.0
var _save_left := 1.0


static func is_farm_animal(id: String) -> bool:
	return SPECIES.has(id)


func setup(p_species: String, p_state: Dictionary, p_farm: Dictionary = {}) -> Livestock:
	species = p_species
	state = p_state
	state["species"] = species
	farm = p_farm
	return self


func info() -> Dictionary:
	return SPECIES[species]


func is_baby() -> bool:
	return state.get("baby", false)


func display_name() -> String:
	return info()["baby_name"] if is_baby() else info()["name"]


func _ready() -> void:
	add_to_group("livestock")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 0
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 9.0
	shape.shape = circle
	add_child(shape)
	_sprite = AnimatedSprite2D.new()
	_sprite.position = Vector2(0, -23)
	add_child(_sprite)
	_dress()
	_wander_to = global_position


func _dress() -> void:
	var sheet := EnemyDB.sheet(info()["baby"] if is_baby() else species)
	_sprite.sprite_frames = SheetAnimations.build(sheet, 96, EnemyAnimator.ROWS)
	_sprite.scale = Vector2.ONE * float(info()["size"]) * (1.0 if is_baby() else 1.0)
	_sprite.play("idle")


func _physics_process(delta: float) -> void:
	_time += delta
	_follow_left = maxf(_follow_left - delta, 0.0)
	_love_left = maxf(_love_left - delta, 0.0)
	state["bred"] = maxf(float(state.get("bred", 0.0)) - delta, 0.0)
	var speed: float = info()["speed"]
	var goal := global_position
	if following and is_instance_valid(following) and _follow_left > 0.0:
		var distance := global_position.distance_to(following.global_position)
		if distance > 900.0:
			_stop_following()
		elif distance > 70.0:
			goal = following.global_position
			speed *= 2.2 if distance > 200.0 else 1.6
		if farm.is_empty():
			_try_join_farm()
	else:
		if following:
			_stop_following()
		_wander_left -= delta
		if _wander_left <= 0.0:
			_wander_left = randf_range(3.0, 7.0)
			var home := _home()
			var roam := FARM_RADIUS * 0.8 if not farm.is_empty() else 120.0
			_wander_to = home + Vector2.from_angle(randf() * TAU) * randf_range(0.0, roam) if randf() < 0.7 else global_position
		goal = _wander_to
	var to_goal := goal - global_position
	velocity = to_goal.normalized() * speed if to_goal.length() > 8.0 else Vector2.ZERO
	move_and_slide()
	if absf(velocity.x) > 1.0:
		_sprite.flip_h = velocity.x < 0.0
	var walking := velocity.length() > 5.0
	if _sprite.animation != ("walk" if walking else "idle"):
		_sprite.play("walk" if walking else "idle")
	_grow(delta)
	_produce(delta)
	if _love_left > 0.0:
		_seek_partner()
	_save_left -= delta
	if _save_left <= 0.0:
		_save_left = 1.0
		state["x"] = global_position.x
		state["y"] = global_position.y
	queue_redraw()


func _home() -> Vector2:
	if not farm.is_empty():
		return Vector2(farm["x"], farm["y"]) + Vector2(0, 90)
	return Vector2(state.get("home_x", global_position.x), state.get("home_y", global_position.y))


func _draw() -> void:
	# Hearts over an animal in love, or following you for its food.
	if _love_left > 0.0 or (following and _follow_left > 0.0):
		var bob := sin(_time * 4.0) * 2.0
		var at := Vector2(0, -52.0 * float(info()["size"]) + bob)
		var color := Color(1.0, 0.4, 0.5) if _love_left > 0.0 else Color(1.0, 0.75, 0.8, 0.8)
		draw_circle(at + Vector2(-2.2, 0), 2.6, color)
		draw_circle(at + Vector2(2.2, 0), 2.6, color)
		draw_colored_polygon(PackedVector2Array([at + Vector2(-4.6, 0.8), at + Vector2(4.6, 0.8), at + Vector2(0, 6)]), color)


## Food in hand: follow, fall in love, or grow faster. Returns what
## happened, for the player to read.
func feed(player: Player) -> String:
	var food := ""
	for id: String in info()["food"]:
		if player.inventory.count_of(id) > 0:
			food = id
			break
	if food == "":
		return "%s wants %s." % [display_name(), ItemDB.ITEMS[info()["food"][0]]["name"].to_lower()]
	if farm.is_empty():
		player.inventory.take(food, 1)
		following = player
		_follow_left = FOLLOW_SECONDS
		player.ego.humble("harvest")
		return "The %s follows you. Lead it to your farmhouse." % display_name().to_lower()
	if is_baby():
		player.inventory.take(food, 1)
		state["age"] = float(state.get("age", 0.0)) + 60.0
		return "The %s eats happily and grows a little." % display_name().to_lower()
	if float(state.get("bred", 0.0)) > 0.0:
		return "The %s needs a rest before another young one." % display_name().to_lower()
	player.inventory.take(food, 1)
	_love_left = LOVE_SECONDS
	player.ego.humble("harvest")
	return "The %s is in love. Feed another %s nearby." % [display_name().to_lower(), info()["name"].to_lower()]


func _stop_following() -> void:
	following = null
	_follow_left = 0.0
	state["home_x"] = global_position.x
	state["home_y"] = global_position.y


## Near a farmhouse while following: settles there for good.
func _try_join_farm() -> void:
	for node in get_tree().get_nodes_in_group("farmhouses"):
		var house := node as Node2D
		if house.global_position.distance_to(global_position) < FARM_RADIUS:
			farm = house.get_meta("record")
			state["next"] = info()["every"]
			(farm["animals"] as Array).append(state)
			following = null
			_follow_left = 0.0
			Events.codex_event.emit("livestock", 1)
			DamageNumber.spawn_text(get_parent(), global_position + Vector2(0, -50), "%s joined your farm" % display_name(), Color(0.7, 1.0, 0.6), 13)
			SaveGame.request_save()
			return


func _grow(delta: float) -> void:
	if not is_baby():
		return
	state["age"] = float(state.get("age", 0.0)) + delta
	if float(state["age"]) >= GROW_SECONDS:
		state["baby"] = false
		state["next"] = info()["every"]
		_dress()
		DamageNumber.spawn_text(get_parent(), global_position + Vector2(0, -50), "The %s has grown up" % info()["baby_name"].to_lower(), Color(0.7, 1.0, 0.6), 13)


func _produce(delta: float) -> void:
	if farm.is_empty() or is_baby():
		return
	state["next"] = float(state.get("next", info()["every"])) - delta
	if float(state["next"]) > 0.0:
		return
	state["next"] = info()["every"] * randf_range(0.9, 1.1)
	Livestock.store(farm, info()["produce"], 1)


## Puts produce into a farmhouse, if it has room.
static func store(record: Dictionary, item_id: String, count: int) -> void:
	var items: Array = record["items"]
	for saved: Dictionary in items:
		if saved["id"] == item_id:
			saved["count"] = int(saved["count"]) + count
			return
	if items.size() < Buildings.CHEST_SLOTS:
		items.append({"id": item_id, "count": count})


func _seek_partner() -> void:
	for node in get_tree().get_nodes_in_group("livestock"):
		var other := node as Livestock
		if other == self or other.species != species or other.is_baby() or other._love_left <= 0.0 or other.farm != farm:
			continue
		if other.global_position.distance_to(global_position) < 160.0:
			_breed(other)
			return


func _breed(partner: Livestock) -> void:
	_love_left = 0.0
	partner._love_left = 0.0
	state["bred"] = BREED_COOLDOWN
	partner.state["bred"] = BREED_COOLDOWN
	var at := (global_position + partner.global_position) / 2.0
	var baby_state := {"species": species, "baby": true, "age": 0.0, "x": at.x, "y": at.y}
	(farm["animals"] as Array).append(baby_state)
	var baby := Livestock.new().setup(species, baby_state, farm)
	baby.position = at
	get_parent().add_child(baby)
	RingBurst.spawn(get_parent(), at + Vector2(0, -16), Color(1.0, 0.5, 0.6), 50.0)
	DamageNumber.spawn_text(get_parent(), at + Vector2(0, -50), "A %s is born!" % info()["baby_name"].to_lower(), Color(1.0, 0.7, 0.8), 14)
	Events.codex_event.emit("animals_bred", 1)
	SaveGame.request_save()


## What a farm made while nobody watched: produce from the adults, growth
## for the young. Called once when the farmhouse comes into being.
static func catch_up(record: Dictionary) -> void:
	var now := Time.get_unix_time_from_system()
	var last := float(record.get("last", now))
	record["last"] = now
	var away := maxf(now - last, 0.0) * AWAY_PACE
	if away < 1.0:
		return
	for animal: Dictionary in record["animals"]:
		var data: Dictionary = SPECIES.get(animal.get("species", ""), {})
		if data.is_empty():
			continue
		if animal.get("baby", false):
			animal["age"] = float(animal.get("age", 0.0)) + away
			if float(animal["age"]) >= GROW_SECONDS:
				animal["baby"] = false
		else:
			var made := mini(int(away / data["every"]), 10)
			if made > 0:
				store(record, data["produce"], made)
