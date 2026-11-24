class_name MonsterTown
extends Node
## Your town of monsters: Named companions who have settled by your home.
## Each works a job (foraging, mining, hunting, keeping watch, or keeping
## the lore), bringing what they find to the town's store each morning.
## The town grows a level for each citizen and each festival held; its
## spirit gives you a little health, and its scholars a little wisdom.
##
## A citizen speaks for its kind: with one of a faction's own living here,
## a treaty can be made with that faction (see Factions), whose gifts then
## come to the store too. Once a week the town may hold the Festival of
## Rising: every citizen grows five levels at once (Named ones may evolve
## on the spot), the town shines with lanterns, and you are Risen for a day.

const JOBS := {
	"forager": {"title": "Forager", "text": "Brings wood, herbs and berries from the wilds.", "color": Color("8ad06a")},
	"miner": {"title": "Miner", "text": "Brings stone and ore up from below; more and better as the town grows.", "color": Color("b0acb8")},
	"hunter": {"title": "Hunter", "text": "Hunts its own kind's haunts and brings back what they drop.", "color": Color("e0905a")},
	"guard": {"title": "Guard", "text": "Keeps watch: strikes any monster that comes near your home.", "color": Color("8ab0f0")},
	"scholar": {"title": "Scholar", "text": "Keeps the lore of its kind: you learn faster (+3% experience each).", "color": Color("c8a0f0")},
}
const FESTIVAL_DAYS := 7
const FESTIVAL_LEVELS := 5
const FESTIVAL_COST := 150
const SHOW_DISTANCE := 1500.0
const GUARD_REACH := 320.0
const STORE_LIMIT := 60

signal changed

## [{pet record..., "job"}]
var citizens: Array = []
## Saved item dicts waiting to be collected.
var store: Array = []
var festivals := 0
var last_festival_day := -99

var _player: Player
var _settlers: Settlers
var _day_night: DayNight
var _shown: Dictionary = {}
var _check_left := 0.0
var _guard_left := 0.0
var _festival_decor: Array = []


func _ready() -> void:
	add_to_group("monster_town")
	SaveGame.register("monster_town", self)


func setup(player: Player, settlers: Settlers, day_night: DayNight) -> void:
	_player = player
	_settlers = settlers
	_day_night = day_night
	day_night.day_changed.connect(_on_morning)
	_apply()


func level() -> int:
	return 1 + citizens.size() + festivals


## Whether one of a faction's own kind, Named, lives here (to speak for it).
func has_speaker(faction: String) -> bool:
	return citizens.any(func(c: Dictionary) -> bool: return Factions.of(str(c["species"])) == faction)


## Moves a Named companion from your pets into the town. Returns "" or why not.
func settle(pet_index: int) -> String:
	var pets: Pets = _player.pets
	if pet_index < 0 or pet_index >= pets.pets.size():
		return ""
	var pet: Dictionary = pets.pets[pet_index]
	if not pet.get("named", false):
		return "Only a Named monster will settle and work."
	if _settlers.home_point() == null:
		return "You need a home first: a house, or a bed of your own."
	var citizen := pet.duplicate(true)
	citizen["job"] = _first_job(citizen)
	citizens.append(citizen)
	pets.release(pet_index)
	Events.codex_event.emit("citizens", 1)
	Voices.heart(get_tree(), "%s settles in your town." % citizen["name"], "Your town is level %d now." % level())
	_apply()
	changed.emit()
	SaveGame.request_save()
	return ""


## A sensible first job: guards from fighters, hunters from beasts.
func _first_job(citizen: Dictionary) -> String:
	var taken := citizens.map(func(c: Dictionary) -> String: return str(c["job"]))
	for job: String in ["guard", "forager", "miner", "hunter", "scholar"]:
		if not job in taken:
			return job
	return "forager"


func set_job(index: int, job: String) -> void:
	if index < 0 or index >= citizens.size() or not JOBS.has(job):
		return
	citizens[index]["job"] = job
	_apply()
	changed.emit()
	SaveGame.request_save()


## Takes a citizen back as a pet that follows you.
func call_back(index: int) -> String:
	if index < 0 or index >= citizens.size():
		return ""
	if _player.pets.pets.size() >= Pets.MAX_PETS:
		return "You have as many pets as you can keep."
	var pet: Dictionary = citizens[index].duplicate(true)
	pet.erase("job")
	citizens.remove_at(index)
	_player.pets.pets.append(pet)
	_player.pets.changed.emit()
	var shown: Variant = _shown.get(int(pet["id"]))
	if is_instance_valid(shown):
		(shown as Node).queue_free()
	_shown.erase(int(pet["id"]))
	_apply()
	changed.emit()
	SaveGame.request_save()
	return ""


## The town's gifts on you: health from its spirit, wisdom from its scholars.
func _apply() -> void:
	if _player == null:
		return
	var scholars := citizens.filter(func(c: Dictionary) -> bool: return c["job"] == "scholar").size()
	_player.stats.set_modifiers("monster_town", {
		"max_health": {"percent": 0.01 * mini(level() - 1, 20)},
		"xp_gain": {"flat": 0.03 * scholars},
	} if not citizens.is_empty() else {})


## Each morning: what the citizens found, and gifts from factions at peace.
func _on_morning(_day: int) -> void:
	if citizens.is_empty():
		return
	var lvl := level()
	for citizen: Dictionary in citizens:
		var growth := 1 + int(citizen["level"]) / 15
		match str(citizen["job"]):
			"forager":
				_put(["oak_wood", "pine_wood", "healing_herb", "wild_berries"].pick_random(), randi_range(2, 3 + growth))
				if randf() < 0.4:
					_put("healing_herb", randi_range(1, 2))
			"miner":
				var ores := ["stone", "stone", "copper_ore", "coal"]
				if lvl >= 4:
					ores.append("iron_ore")
				if lvl >= 7:
					ores.append("silver_ore")
				if lvl >= 10:
					ores.append("gold_ore")
				_put(ores.pick_random(), randi_range(2, 3 + growth))
			"hunter":
				var table: Dictionary = ItemDB.LOOT_TABLES.get(str(citizen["species"]), {})
				for drop: Dictionary in table.get("materials", []):
					if randf() < minf(float(drop["chance"]) * 2.5, 0.9):
						_put(str(drop["id"]), randi_range(1, growth))
				_put("gold_coins", randi_range(5, 12) * growth)
	# Factions at peace send something of theirs.
	var factions: Factions = get_tree().get_first_node_in_group("factions")
	if factions:
		for faction: String in factions.treaties:
			var members: Array = Factions.LIST[faction]["members"]
			var table: Dictionary = ItemDB.LOOT_TABLES.get(str(members.pick_random()), {})
			var drops: Array = table.get("materials", [])
			if not drops.is_empty():
				_put(str((drops.pick_random() as Dictionary)["id"]), randi_range(1, 3))
	_clear_festival_decor()
	changed.emit()
	SaveGame.request_save()


func _put(item_id: String, count: int) -> void:
	if not ItemDB.ITEMS.has(item_id) or count <= 0 or store.size() >= STORE_LIMIT:
		return
	for saved: Dictionary in store:
		if saved.get("id", "") == item_id and int(saved.get("count", 1)) + count <= ItemDB.MAX_STACK:
			saved["count"] = int(saved.get("count", 1)) + count
			return
	store.append(Item.create(item_id, count).to_dict())


## Opens the store to take things from.
func open_store() -> void:
	Events.loot_opened.emit({"items": store, "title": "The town's store", "take_only": true})


# --- the Festival of Rising

func festival_problem() -> String:
	if citizens.size() < 2:
		return "A festival needs at least two citizens."
	if _day_night.day - last_festival_day < FESTIVAL_DAYS:
		return "The last festival was too recent. (%d more days)" % (FESTIVAL_DAYS - (_day_night.day - last_festival_day))
	if _player.inventory.gold < festival_cost():
		return "A festival costs %d gold for food and lanterns." % festival_cost()
	return ""


func festival_cost() -> int:
	return FESTIVAL_COST * level()


func hold_festival() -> String:
	var problem := festival_problem()
	if problem != "":
		return problem
	_player.inventory.add_gold(-festival_cost())
	festivals += 1
	last_festival_day = _day_night.day
	var pets: Pets = _player.pets
	var evolved := 0
	for citizen: Dictionary in citizens:
		var before := int(citizen.get("stage", 0))
		citizen["level"] = mini(int(citizen["level"]) + FESTIVAL_LEVELS, Pets.MAX_LEVEL)
		pets._evolve_check(citizen)
		if int(citizen.get("stage", 0)) > before:
			evolved += 1
	var following := pets.current()
	if not following.is_empty():
		following["level"] = mini(int(following["level"]) + FESTIVAL_LEVELS, Pets.MAX_LEVEL)
		pets._evolve_check(following)
		pets._refresh_look()
	_player.buffs.add("risen", "Risen", 600.0, {"physical_damage": {"percent": 0.1}, "magic_power": {"percent": 0.1}, "xp_gain": {"flat": 0.1}})
	Events.codex_event.emit("festivals", 1)
	Voices.heart(get_tree(), "The Festival of Rising.", "Every citizen grows. %s Your town is level %d." % ["%d evolved!" % evolved if evolved > 0 else "", level()])
	_dress_for_festival()
	_apply()
	for node: Variant in _shown.values():
		if is_instance_valid(node):
			(node as Citizen).refresh()
	changed.emit()
	SaveGame.request_save()
	return ""


## Lanterns and banners round your home until morning.
func _dress_for_festival() -> void:
	_clear_festival_decor()
	var home: Variant = _settlers.home_point()
	if home == null:
		return
	var colours := [Color("f2c14e"), Color("c8a0f0"), Color("8ad06a"), Color("e0905a")]
	for k in 10:
		var spot: Vector2 = home + Vector2.from_angle(TAU * k / 10.0) * 150.0
		var decor := Prop.create_decor(Prop.Decor.LANTERN if k % 2 == 0 else Prop.Decor.BANNER, spot, 0.0)
		if k % 2 == 0:
			decor.add_light(0.8, 1.2, colours[k / 2 % colours.size()])
		else:
			decor.sprite().modulate = colours[k / 2 % colours.size()]
		_player.get_parent().add_child(decor)
		_festival_decor.append(decor)
	var sky := FestivalSky.new()
	sky.day_night = _day_night
	sky.position = home
	_player.get_parent().add_child(sky)
	_festival_decor.append(sky)


func _clear_festival_decor() -> void:
	for node: Variant in _festival_decor:
		if is_instance_valid(node):
			(node as Node).queue_free()
	_festival_decor.clear()


# --- the citizens, out by your home

func _physics_process(delta: float) -> void:
	if _player == null:
		return
	_check_left -= delta
	_guard_left -= delta
	if _check_left > 0.0:
		return
	_check_left = 1.0
	var home: Variant = _settlers.home_point()
	var near := home != null and not _player.indoors and (home as Vector2).distance_to(_player.global_position) < SHOW_DISTANCE
	for index in citizens.size():
		var citizen: Dictionary = citizens[index]
		var key := int(citizen["id"])
		var shown: Variant = _shown.get(key)
		if near and not is_instance_valid(shown):
			var spot: Vector2 = home + Vector2.from_angle(TAU * index / maxf(citizens.size(), 1.0) + 1.3) * 110.0
			var node := Citizen.new()
			node.setup(self, citizen, spot)
			_player.get_parent().add_child(node)
			_shown[key] = node
		elif not near and is_instance_valid(shown):
			(shown as Node).queue_free()
			_shown.erase(key)
	if near and _guard_left <= 0.0:
		_guard_left = 1.6
		_keep_watch()


## Guards strike at monsters that come near.
func _keep_watch() -> void:
	for citizen: Dictionary in citizens:
		if citizen["job"] != "guard":
			continue
		var node: Variant = _shown.get(int(citizen["id"]))
		if not is_instance_valid(node):
			continue
		var guard := node as Citizen
		var target: Enemy = null
		var best := GUARD_REACH
		for other in get_tree().get_nodes_in_group("enemies"):
			var enemy := other as Enemy
			if enemy and not enemy.health.is_dead() and not enemy.is_wild() and enemy.global_position.distance_to(guard.global_position) < best:
				best = enemy.global_position.distance_to(guard.global_position)
				target = enemy
		if target:
			guard.strike(target, _player.pets.damage(citizen))


func save_data() -> Dictionary:
	return {"citizens": citizens.duplicate(true), "store": store, "festivals": festivals, "last_festival_day": last_festival_day}


func load_data(data: Dictionary) -> void:
	citizens.clear()
	for saved: Variant in data.get("citizens", []):
		if saved is Dictionary and EnemyDB.ENEMIES.has(str(saved.get("species", ""))):
			citizens.append(saved)
	store = data.get("store", []) if data.get("store") is Array else []
	festivals = int(data.get("festivals", 0))
	last_festival_day = int(data.get("last_festival_day", -99))
	for node: Variant in _shown.values():
		if is_instance_valid(node):
			(node as Node).queue_free()
	_shown.clear()
	_apply()


## A citizen out by your home: its own monster figure at its native size,
## pottering about its spot, its name and job over its head in its job's
## colour, the mark of its Name above. Talking to it opens the town.
class Citizen:
	extends Prop

	var data: Dictionary
	var _town: MonsterTown
	var _sprite_node: AnimatedSprite2D
	var _home := Vector2.ZERO
	var _goal := Vector2.ZERO
	var _wait := 0.0
	var _lunge := 0.0

	func setup(town: MonsterTown, citizen: Dictionary, at: Vector2) -> void:
		_town = town
		data = citizen
		_home = at
		position = at
		_goal = at
		reach = 70.0
		prompt_text = "Talk to %s" % citizen["name"]
		on_interact = func(player: Player) -> void:
			player.get_parent().get_node("Menus").open("town")

	func _ready() -> void:
		_sprite_node = AnimatedSprite2D.new()
		_sprite_node.sprite_frames = SheetAnimations.build(EnemyDB.sheet(str(data["species"])), EnemyDB.frame_size(EnemyDB.sheet(str(data["species"]))), EnemyAnimator.ROWS)
		_sprite_node.position = Vector2(0, -23)
		_sprite_node.play("idle")
		add_child(_sprite_node)
		refresh()

	func refresh() -> void:
		if _sprite_node:
			_sprite_node.modulate = Pets.STAGES[int(data.get("stage", 0))][2]
		queue_redraw()

	func strike(target: Enemy, damage: float) -> void:
		_lunge = 0.3
		_goal = global_position.lerp(target.global_position, 0.3)
		Uniques._bolt(_town._player, global_position + Vector2(0, -20), target.global_position, MonsterTown.JOBS["guard"]["color"])
		target.take_damage(damage, (target.global_position - global_position).normalized() * 160.0)

	func _process(delta: float) -> void:
		_wait -= delta
		_lunge = maxf(_lunge - delta, 0.0)
		var way := _goal - position
		if way.length() > 4.0:
			position += way.normalized() * minf(way.length(), (140.0 if _lunge > 0.0 else 40.0) * delta)
			if _sprite_node.sprite_frames.has_animation("walk") and _sprite_node.animation != "walk":
				_sprite_node.play("walk")
			_sprite_node.flip_h = way.x < 0.0
		else:
			if _sprite_node.animation != "idle":
				_sprite_node.play("idle")
			if _wait <= 0.0:
				_wait = randf_range(2.0, 6.0)
				_goal = _home + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 60.0)
		queue_redraw()

	func _draw() -> void:
		var job: Dictionary = MonsterTown.JOBS[str(data["job"])]
		var font := UITheme.get_theme().default_font
		var top := -66.0
		var line := "%s  ·  %s" % [data["name"], job["title"]]
		draw_string_outline(font, Vector2(-80, top), line, HORIZONTAL_ALIGNMENT_CENTER, 160.0, 12, 3, Color(0, 0, 0, 0.8))
		draw_string(font, Vector2(-80, top), line, HORIZONTAL_ALIGNMENT_CENTER, 160.0, 12, job["color"])
		var gem := Vector2(0, top - 14.0)
		draw_colored_polygon(PackedVector2Array([gem + Vector2(0, -4), gem + Vector2(3, 0), gem + Vector2(0, 4), gem + Vector2(-3, 0)]), Color(1.0, 0.82, 0.4))
		draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, 14.0, Color(0, 0, 0, 0.22))
		draw_set_transform(Vector2.ZERO)


## Festival fireworks over your home by night: rockets that rise and burst
## into rings of pixels in the town's colours.
class FestivalSky:
	extends Node2D

	var day_night: DayNight
	var _rockets: Array = []
	var _next := 0.0

	func _ready() -> void:
		z_index = 20

	func _process(delta: float) -> void:
		_next -= delta
		var dark := day_night == null or day_night.is_night_outside()
		if _next <= 0.0 and dark:
			_next = randf_range(0.6, 1.6)
			_rockets.append({"from": Vector2(randf_range(-120, 120), 0), "height": randf_range(120, 200), "age": 0.0,
				"colour": [Color("f2c14e"), Color("c8a0f0"), Color("8ad06a"), Color("e0905a"), Color("f06a6a")].pick_random()})
		for rocket: Dictionary in _rockets:
			rocket["age"] = float(rocket["age"]) + delta
		_rockets = _rockets.filter(func(r: Dictionary) -> bool: return float(r["age"]) < 2.4)
		queue_redraw()

	func _draw() -> void:
		for rocket: Dictionary in _rockets:
			var age := float(rocket["age"])
			var from: Vector2 = rocket["from"]
			var colour: Color = rocket["colour"]
			if age < 0.8:
				var at := (from + Vector2(0, -float(rocket["height"]) * (age / 0.8))).round()
				draw_rect(Rect2(at, Vector2(2, 2)), Color(1.0, 0.9, 0.7))
				draw_rect(Rect2(at + Vector2(0, 3), Vector2(1, 3)), Color(1.0, 0.6, 0.3, 0.6))
			else:
				var burst := (age - 0.8) / 1.6
				var middle := from + Vector2(0, -float(rocket["height"]))
				for k in 16:
					var spot := (middle + Vector2.from_angle(TAU * k / 16.0) * (8.0 + 46.0 * burst) + Vector2(0, burst * burst * 20.0)).round()
					draw_rect(Rect2(spot, Vector2(2, 2)), Color(colour, 1.0 - burst))
