class_name NetWorld
extends Node
## The shared world, as this game takes part in it (only in a shared game).
##
## Monsters: each is run by the game of the player nearest it. This game
## runs its own share (with all the usual fighting, aimed at its player),
## and shows copies of the others' monsters. A blow on a copy goes to the
## game that runs it; a kill belongs to whoever struck last, so the
## experience and the drops are theirs. A monster nearer another player
## than this one is handed over to that player's game, and one far from
## everyone is let go. Monsters' swipes, blasts and shots are seen by
## everyone near and can hurt them, each in their own game.
##
## Drops: one drop for everyone; reaching it asks the host, and whoever
## asks first gets it. Chests, crates, things used up and gathering are
## told to everyone, so the world is the same for all. Where fighting
## between players is allowed, blows reach them too.

## How often this game's monsters are told about.
const STATE_EVERY := 0.1
const OWNERSHIP_EVERY := 0.5
## Another player must be this much nearer before a monster goes to them.
const HANDOVER_MARGIN := 80.0
## Monsters this far from every player are let go.
const LET_GO := 3000.0
const FACTS_EVERY := 1.0
## A copy not heard of for this long is taken away.
const QUIET_COPY := 5.0
## Blows between players are softened: a duel, not a slaughter.
const PVP_SHARE := 0.6

static var current: NetWorld

var _player: Player
var _spawner: EnemySpawner
var _loot: Node2D
var _instances: Instances
var _structures: Structures
var _resources: ResourceSpawner

## id -> Enemy this game runs; id -> copy of another game's.
var _owned: Dictionary = {}
var _puppets: Dictionary = {}
## id -> Pickup (this game's drops and copies of others').
var _pickups: Dictionary = {}
var _counter := 0
var _state_left := 0.0
var _own_left := OWNERSHIP_EVERY
var _facts_left := FACTS_EVERY
var _quiet_left := 1.0
var _sent_used: Dictionary = {}
var _sent_broken: Dictionary = {}
var _sent_chests: Dictionary = {}
var _sent_gathered: Dictionary = {}


func setup(player: Player, spawner: EnemySpawner, loot: Node2D, instances: Instances, structures: Structures, resources: ResourceSpawner) -> void:
	_player = player
	_spawner = spawner
	_loot = loot
	_instances = instances
	_structures = structures
	_resources = resources


func _ready() -> void:
	current = self
	Net.world_msg.connect(_on_msg)
	Net.left_game.connect(_on_left)
	_apply_joined_world()
	_snapshot()
	# Monsters already about (a lair's guards, placed as the world loaded).
	for node in get_tree().get_nodes_in_group("enemies"):
		adopt(node as Enemy)
	for node in get_tree().get_nodes_in_group("pickups"):
		share_pickup(node as Pickup)


func _exit_tree() -> void:
	if current == self:
		current = null


## The shared game is over: copies go, and this game's own monsters and
## drops are simply its own again.
func _on_left(_reason: String) -> void:
	for id: int in _puppets:
		if is_instance_valid(_puppets[id]):
			(_puppets[id] as Node).queue_free()
	for id: int in _pickups:
		var drop: Pickup = _pickups[id]
		if not is_instance_valid(drop):
			continue
		if drop.net_replica:
			drop.queue_free()
		else:
			drop.net_id = 0
			drop.visible = true
			drop._claiming = false
	for id: int in _owned:
		if is_instance_valid(_owned[id]):
			(_owned[id] as Enemy).net_id = 0
	_puppets.clear()
	_pickups.clear()
	_owned.clear()
	if current == self:
		current = null
	queue_free()


func _new_id() -> int:
	_counter = (_counter + 1) % 1048576
	return (Net.my_id() & 0x7FFFFFF) * 1048576 + _counter


## Where this game's player is: "" out in the world, or the room's key (the
## same room entered from the same door is the same for everyone).
func instance_key() -> String:
	if not _instances.is_inside():
		return ""
	return "%s@%d,%d" % [_instances.room.title, roundi(Room.ORIGIN.x), roundi(Room.ORIGIN.y)]


func _my_distance(at: Vector2) -> float:
	if _player.is_dead():
		return INF
	return _player.global_position.distance_to(at)


## The other player nearest `at` in this place, and how far: [peer, distance].
func _nearest_other(at: Vector2) -> Array:
	var best := 0
	var nearest := INF
	var here := instance_key()
	for peer: int in Net.places:
		if peer == Net.my_id() or not Net.roster.has(peer):
			continue
		var place: Dictionary = Net.places[peer]
		if str(place["i"]) != here or bool(place.get("dead", false)):
			continue
		var distance := (place["p"] as Vector2).distance_to(at)
		if distance < nearest:
			nearest = distance
			best = peer
	return [best, nearest]


## Whether this game's player is the nearest to `at` (so stirs it up).
func nearest_to(at: Vector2) -> bool:
	return _my_distance(at) <= float(_nearest_other(at)[1])


# --- monsters

## A monster made in this game: this game runs it, and tells the host.
func adopt(enemy: Enemy) -> void:
	if enemy == null or enemy.net_puppet or enemy.net_id != 0 or enemy.state == Enemy.State.DEAD:
		return
	enemy.net_id = _new_id()
	_own(enemy)
	var at := enemy.global_position
	var key := "%s|%d|%s|%s|%s|%d,%d" % [enemy.enemy_id, enemy.rank, enemy.boss_id, enemy.named_id, instance_key(), roundi(at.x / 11.0), roundi(at.y / 11.0)]
	Net.sync_ask("reg", {"id": enemy.net_id, "key": key, "spec": enemy.net_spec(), "p": at, "i": instance_key()})


func _own(enemy: Enemy) -> void:
	_owned[enemy.net_id] = enemy
	var leaving := _on_owned_leaving.bind(enemy)
	if not enemy.tree_exiting.is_connected(leaving):
		enemy.tree_exiting.connect(leaving)


func _on_owned_leaving(enemy: Enemy) -> void:
	if _owned.get(enemy.net_id) != enemy:
		return
	_owned.erase(enemy.net_id)
	if enemy.state != Enemy.State.DEAD:
		Net.sync_ask("gone", {"id": enemy.net_id})


func _watch_copy(enemy: Enemy) -> void:
	var leaving := _on_copy_leaving.bind(enemy)
	if not enemy.tree_exiting.is_connected(leaving):
		enemy.tree_exiting.connect(leaving)


func _on_copy_leaving(enemy: Enemy) -> void:
	if _puppets.get(enemy.net_id) == enemy:
		_puppets.erase(enemy.net_id)


## Makes a monster from what another game says it is: a copy, or (taking
## it over) the real one.
func _make_enemy(id: int, spec: Dictionary, line: Array, puppet: bool) -> Enemy:
	var enemy: Enemy = _spawner.enemy_scene.instantiate()
	enemy.net_id = id
	enemy.net_puppet = puppet
	if line.size() >= 3:
		enemy.position = Vector2(float(line[1]), float(line[2]))
	enemy.boss_id = str(spec.get("b", ""))
	enemy.named_id = str(spec.get("n", ""))
	enemy.custom_name = str(spec.get("c", ""))
	enemy.is_fragment = bool(spec.get("f", false))
	enemy.faction = str(spec.get("fa", ""))
	var mods: Array[String] = []
	for modifier: Variant in spec.get("m", []):
		if Enemy.MODIFIERS.has(str(modifier)):
			mods.append(str(modifier))
	enemy.modifiers = mods
	if spec.get("lh") is Vector2:
		enemy.lair_home = spec["lh"]
	enemy.configure(int(spec.get("lv", 1)), int(spec.get("r", 0)) as Enemy.Rank, str(spec.get("e", "husk")))
	enemy.target = null if puppet else _player
	_spawner.add_child(enemy)
	if line.size() >= 13:
		enemy.hear_state(line)
	enemy._net_heard = Time.get_ticks_msec() / 1000.0
	if puppet:
		_puppets[id] = enemy
		_watch_copy(enemy)
	else:
		_own(enemy)
	return enemy


func _hand_over(enemy: Enemy, peer: int) -> void:
	var full := enemy.net_full()
	_owned.erase(enemy.net_id)
	enemy.become_puppet()
	_puppets[enemy.net_id] = enemy
	_watch_copy(enemy)
	Net.sync_ask("handover", {"id": enemy.net_id, "to": peer, "full": full})


## A blow on a copy: shown here at once, and sent to the game that runs it.
func strike_copy(enemy: Enemy, amount: float, knockback: Vector2, critical: bool, weapon_type: String, element: String) -> float:
	if amount <= 0.0:
		return 0.0
	Net.sync_ask("hit", {"id": enemy.net_id, "a": amount, "kb": knockback, "c": critical, "w": weapon_type, "el": element})
	var color := Elements.color(element) if element != "" else (Color(1.0, 0.8, 0.25) if critical else Color(0.95, 0.9, 0.75))
	DamageNumber.spawn(enemy.get_parent(), enemy.global_position + Vector2(randf_range(-6, 6), 0), amount, color, critical)
	if element == "":
		Audio.play("hit", -4.0)
		HitSpark.spawn(enemy.get_parent(), enemy.global_position + Vector2(0, -16), Color(1.0, 0.85, 0.4) if critical else Color(1.0, 0.95, 0.85), critical)
		enemy._flash()
		enemy._animator.flinch(knockback)
	enemy._since_hurt = 0.0
	return amount


## A status, stun or parry on a copy: to the game that runs it.
func forward(enemy: Enemy, kind: String, data: Dictionary) -> void:
	data["id"] = enemy.net_id
	Net.sync_ask(kind, data)


## One of this game's monsters has fallen: everyone's copy falls, and the
## kill goes to whoever struck last. Returns whether that is this game.
func enemy_fell(enemy: Enemy, info: Dictionary) -> bool:
	var killer := enemy.net_last_peer if enemy.net_last_peer != 0 else Net.my_id()
	_owned.erase(enemy.net_id)
	Net.sync_ask("died", {"id": enemy.net_id, "killer": killer, "info": info})
	return killer == Net.my_id()


## A swipe, blast or poison cloud of one of this game's monsters: everyone
## near sees it, and it can hurt them in their own game.
func share_strike(enemy: Enemy, shape: Dictionary) -> void:
	if enemy.net_puppet or enemy.net_id == 0:
		return
	var effects: Array = [enemy._data.get("touch", {}), enemy._attack.get("status", {}) if not enemy._attack["kind"] in ["shoot", "spit"] else {}]
	for modifier in enemy.modifiers:
		effects.append(Enemy.MODIFIERS[modifier].get("touch", {}))
	shape["p"] = enemy.global_position
	shape["d"] = enemy._direction
	shape["dmg"] = enemy._current_damage()
	shape["lv"] = enemy.level
	shape["el"] = Elements.attack_element(enemy.enemy_id)
	shape["fx"] = effects.filter(func(effect: Variant) -> bool: return effect is Dictionary and not (effect as Dictionary).is_empty())
	shape["kb"] = float(enemy._attack.get("knockback", 0.0))
	Net.sync_near("sk", shape, enemy.global_position, instance_key())


func share_shot(enemy: Enemy, at: Vector2, direction: Vector2, speed: float, damage: float, attack: Dictionary) -> void:
	if enemy.net_puppet or enemy.net_id == 0:
		return
	Net.sync_near("sp", {"p": at, "d": direction, "s": speed, "dmg": damage, "lv": enemy.level, "st": attack.get("status", {}),
		"spr": int(attack["sprite"]), "col": attack.get("color", Color.WHITE), "el": Elements.attack_element(enemy.enemy_id)}, at, instance_key())


## This player's arrow or bolt: seen flying in the others' games.
func share_bolt(at: Vector2, direction: Vector2, config: Dictionary) -> void:
	var shown := {}
	for key: String in ["sprite", "speed", "range", "color", "explode", "radius"]:
		if config.has(key):
			shown[key] = config[key]
	Net.sync_near("pp", {"p": at, "d": direction, "c": shown}, at, instance_key(), false)


## Something a monster did in another game, felt here.
func _feel_strike(shape: Dictionary) -> void:
	var at: Vector2 = shape.get("p", Vector2.ZERO)
	var direction: Vector2 = shape.get("d", Vector2.RIGHT)
	var reach := float(shape.get("r", 60.0))
	var color: Color = shape.get("c", Color(1.0, 0.6, 0.3))
	var hit := false
	match str(shape.get("k", "")):
		"swipe":
			ClawSwipe.spawn(_spawner, at, direction, reach, float(shape.get("a", 110.0)), color, int(shape.get("cl", 3)))
			Audio.play("swing", -10.0, 0.2)
			var offset := _player.global_position - at
			hit = offset.length() <= reach + 12.0 and (offset.length() <= 21.0 or absf(direction.angle_to(offset)) <= deg_to_rad(float(shape.get("a", 110.0))) / 2.0)
		"blast":
			RingBurst.spawn(_spawner, at, color, reach)
			HitSpark.spawn(_spawner, at + Vector2(0, -10), color, true)
			hit = _player.global_position.distance_to(at) < reach
			if hit:
				_player.shake_camera(7.0)
		"cloud":
			# The cloud hurts this game's player by itself if they stand in it.
			var status: Dictionary = shape.get("st", {}) if shape.get("st") is Dictionary else {}
			HazardZone.spawn(_spawner, at, _player, reach, float(shape.get("l", 4.0)), color, status, float(shape.get("dmg", 5.0)))
			return
	if not hit or _player.is_dead():
		return
	var amount := float(shape.get("dmg", 5.0))
	if not _player.take_damage(amount, at, int(shape.get("lv", 1)), str(shape.get("el", ""))):
		return
	for effect: Variant in shape.get("fx", []):
		if effect is Dictionary and (effect as Dictionary).has("status"):
			var power: float = float(effect["power"]) if effect["status"] == "chill" else float(effect["power"]) * amount
			_player.apply_status(str(effect["status"]), float(effect["duration"]), power)
	var shove := float(shape.get("kb", 0.0))
	if shove > 0.0:
		_player.velocity = (direction if shape.get("k") == "swipe" else at.direction_to(_player.global_position)) * shove


# --- drops

## A drop made in this game: one drop for everyone near.
func share_pickup(pickup: Pickup) -> void:
	if pickup == null or not is_instance_valid(pickup) or pickup.net_id != 0 or pickup.net_replica or not pickup.is_inside_tree():
		return
	pickup.net_id = _new_id()
	_pickups[pickup.net_id] = pickup
	pickup.tree_exiting.connect(_on_pickup_leaving.bind(pickup))
	var at := pickup.landing if pickup.landing != Vector2.INF else pickup.global_position
	Net.sync_ask("lreg", {"id": pickup.net_id, "data": {"item": pickup.item.to_dict() if pickup.item else null, "gold": pickup.gold}, "p": at, "i": instance_key()})


func _on_pickup_leaving(pickup: Pickup) -> void:
	if _pickups.get(pickup.net_id) != pickup:
		return
	_pickups.erase(pickup.net_id)
	# Left lying until it faded: gone for everyone.
	if not pickup.net_granted and not pickup.net_replica:
		Net.sync_ask("lgone", {"id": pickup.net_id})


func claim_pickup(pickup: Pickup) -> void:
	Net.sync_ask("ltake", {"id": pickup.net_id})


## Takes a drop away here without telling anyone (it went elsewhere).
func _drop_quietly(id: int) -> void:
	var pickup: Pickup = _pickups.get(id)
	_pickups.erase(id)
	if is_instance_valid(pickup):
		pickup.net_id = 0
		pickup.queue_free()


func _granted(id: int) -> void:
	var pickup: Pickup = _pickups.get(id)
	_pickups.erase(id)
	if not is_instance_valid(pickup):
		return
	pickup.net_granted = true
	pickup.visible = true
	pickup._collect()
	if is_instance_valid(pickup) and not pickup.is_queued_for_deletion():
		# It would not fit after all: back on the ground, for anyone.
		pickup._claiming = false
		pickup.net_granted = false
		pickup.net_replica = false
		pickup.net_id = 0
		pickup.landing = Vector2.INF
		share_pickup(pickup)


# --- fighting between players

func strike_rival(rival: RemotePlayer, damage: float, critical: bool, _weapon_type: String) -> void:
	if not Net.rules.get("pvp", false) or damage <= 0.0:
		return
	DamageNumber.spawn(rival.get_parent(), rival.global_position, damage * PVP_SHARE, Color(1.0, 0.8, 0.25) if critical else Color(0.95, 0.9, 0.75), critical)
	HitSpark.spawn(rival.get_parent(), rival.global_position + Vector2(0, -16), Color(1.0, 0.9, 0.8), critical)
	Net.sync_to(rival.peer, "pvp", {"d": damage, "c": critical, "lv": _player.leveling.level, "p": _player.global_position})


# --- the world's own changes

## What this game already has, so only new changes are told.
func _snapshot() -> void:
	_sent_used = _structures.used.duplicate()
	_sent_broken = Prop.broken.duplicate()
	_sent_chests.clear()
	for key: String in _structures.chests:
		_sent_chests[key] = hash(_structures.chests[key])
	_sent_gathered.clear()
	for cell: Vector2i in _resources.gathered_ages():
		_sent_gathered[cell] = true


## A joining guest: what the host's world has gathered lately.
func _apply_joined_world() -> void:
	if not Net.is_guest():
		return
	var sections: Dictionary = Net.world.get("sections", {}) if Net.world.get("sections") is Dictionary else {}
	var gathered: Dictionary = sections.get("gathered", {}) if sections.get("gathered") is Dictionary else {}
	var now := Time.get_unix_time_from_system()
	for key: String in gathered:
		_resources.fell(_cell_of(key), now - float(gathered[key]))


static func _cell_of(key: String) -> Vector2i:
	return Vector2i(int(key.get_slice(",", 0)), int(key.get_slice(",", 1)))


func _send_facts() -> void:
	for key: String in _structures.used:
		if not _sent_used.has(key):
			_sent_used[key] = true
			Net.sync_all("fact", {"k": "used", "key": key})
	for key: String in Prop.broken:
		if not _sent_broken.has(key):
			_sent_broken[key] = true
			Net.sync_all("fact", {"k": "broken", "key": key})
	for key: String in _structures.chests:
		var now := hash(_structures.chests[key])
		if int(_sent_chests.get(key, 0)) != now:
			_sent_chests[key] = now
			Net.sync_all("fact", {"k": "chest", "key": key, "v": _structures.chests[key]})
	var ages := _resources.gathered_ages()
	var clock := Time.get_unix_time_from_system()
	for cell: Vector2i in ages:
		if not _sent_gathered.has(cell):
			_sent_gathered[cell] = true
			Net.sync_all("fact", {"k": "gathered", "key": "%d,%d" % [cell.x, cell.y], "v": clock - float(ages[cell])})
	for cell: Vector2i in _sent_gathered.keys():
		if not ages.has(cell):
			_sent_gathered.erase(cell)


func _apply_fact(data: Dictionary) -> void:
	var key := str(data.get("key", ""))
	match str(data.get("k", "")):
		"used":
			_structures.used[key] = true
			_sent_used[key] = true
		"broken":
			Prop.broken[key] = true
			_sent_broken[key] = true
			for node in get_tree().get_nodes_in_group("breakables"):
				var prop := node as Prop
				if prop and prop.break_key() == key:
					prop.shatter_quietly()
		"chest":
			var items: Array = data.get("v", []) if data.get("v") is Array else []
			if _structures.chests.has(key):
				# In place, so a chest someone has open here shows the change.
				var held: Array = _structures.chests[key]
				held.clear()
				held.append_array(items)
				for node in get_tree().get_nodes_in_group("storage_menus"):
					var menu := node as StorageMenu
					if menu and menu.visible and is_same(menu.chest.get("items"), held):
						menu.refresh()
			else:
				_structures.chests[key] = items.duplicate(true)
			_sent_chests[key] = hash(_structures.chests[key])
		"gathered":
			var cell := _cell_of(key)
			_resources.fell(cell, Time.get_unix_time_from_system() - float(data.get("v", 0.0)))
			_sent_gathered[cell] = true


# --- news

func _on_msg(kind: String, data: Variant, from: int) -> void:
	if not data is Dictionary:
		return
	var message: Dictionary = data
	var id := int(message.get("id", 0))
	match kind:
		"es":
			for line: Variant in message.get("l", []):
				if line is Array and (line as Array).size() >= 13:
					var copy: Enemy = _puppets.get(int(line[0]))
					if is_instance_valid(copy):
						copy.hear_state(line)
		"espec":
			if _puppets.has(id) or _owned.has(id):
				return
			_make_enemy(id, message.get("spec", {}), message.get("s", []), true)
		"forget":
			var copy: Enemy = _puppets.get(id)
			if is_instance_valid(copy):
				_puppets.erase(id)
				copy.queue_free()
			var drop: Pickup = _pickups.get(id)
			if is_instance_valid(drop) and drop.net_replica:
				_drop_quietly(id)
		"edie":
			var copy: Enemy = _puppets.get(id)
			if is_instance_valid(copy):
				_puppets.erase(id)
				copy.puppet_die()
		"kill":
			var info: Dictionary = message.get("info", {})
			if info.has("xp"):
				var at: Vector2 = info.get("position", _player.global_position)
				DamageNumber.spawn_text(_spawner, at + Vector2(0, -24), "+%d XP" % int(info["xp"]), Color(0.45, 0.7, 1.0), 12)
				Events.enemy_killed.emit(info)
		"take":
			var full: Dictionary = message.get("full", {})
			var copy: Enemy = _puppets.get(id)
			if is_instance_valid(copy) and copy.state != Enemy.State.DEAD:
				_puppets.erase(id)
				copy.become_owned(full, _player)
				_own(copy)
			elif not _owned.has(id) and full.get("spec") is Dictionary:
				var made := _make_enemy(id, full["spec"], full.get("s", []), false)
				made.become_owned(full, _player)
		"reg_no":
			# The same fixed monster is already run by another game.
			var twin: Enemy = _owned.get(id)
			_owned.erase(id)
			if is_instance_valid(twin):
				twin.net_id = 0
				twin.queue_free()
		"hit":
			var mine: Enemy = _owned.get(id)
			if is_instance_valid(mine) and mine.state != Enemy.State.DEAD:
				mine.net_last_peer = from
				mine.take_damage(float(message.get("a", 0.0)), message.get("kb", Vector2.ZERO), bool(message.get("c", false)), str(message.get("w", "")), str(message.get("el", "")))
				if is_instance_valid(mine) and mine.state != Enemy.State.DEAD:
					mine.net_last_peer = 0
		"status":
			var mine: Enemy = _owned.get(id)
			if is_instance_valid(mine):
				mine.apply_status(str(message.get("s", "")), float(message.get("d", 1.0)), float(message.get("w", 0.0)), str(message.get("t", "")))
		"stun":
			var mine: Enemy = _owned.get(id)
			if is_instance_valid(mine):
				mine.stun(float(message.get("d", 1.0)))
		"expose":
			var mine: Enemy = _owned.get(id)
			if is_instance_valid(mine):
				mine.expose(float(message.get("d", 1.0)))
		"sk":
			_feel_strike(message)
		"sp":
			EnemyProjectile.fire_copy(_spawner, message.get("p", Vector2.ZERO), message.get("d", Vector2.RIGHT), _player, float(message.get("s", 400.0)),
				float(message.get("dmg", 5.0)), int(message.get("lv", 1)), message.get("st", {}) if message.get("st") is Dictionary else {},
				int(message.get("spr", 0)), message.get("col", Color.WHITE), str(message.get("el", "")))
		"pp":
			Projectile.fire_copy(_player.get_parent(), message.get("p", Vector2.ZERO), message.get("d", Vector2.RIGHT), message.get("c", {}) if message.get("c") is Dictionary else {})
		"lspec":
			if _pickups.has(id):
				return
			var info: Dictionary = message.get("data", {}) if message.get("data") is Dictionary else {}
			var item: Item = Item.from_dict(info["item"]) if info.get("item") is Dictionary else null
			var drop := Pickup.create(_player, item, int(info.get("gold", 0)))
			drop.net_id = id
			drop.net_replica = true
			drop.position = message.get("p", _player.global_position)
			_pickups[id] = drop
			drop.tree_exiting.connect(_on_pickup_leaving.bind(drop))
			_loot.add_child(drop)
		"lyes":
			_granted(id)
		"lno", "lgone":
			_drop_quietly(id)
		"fact":
			_apply_fact(message)
		"pvp":
			if Net.rules.get("pvp", false) and not _player.is_dead():
				_player.take_damage(float(message.get("d", 0.0)) * PVP_SHARE, message.get("p", _player.global_position), int(message.get("lv", 1)))


func _process(delta: float) -> void:
	if not Net.online():
		return
	_state_left -= delta
	if _state_left <= 0.0:
		_state_left = STATE_EVERY
		var lines: Array = []
		for id: int in _owned:
			var enemy: Enemy = _owned[id]
			if is_instance_valid(enemy) and enemy.state != Enemy.State.DEAD and enemy.is_inside_tree():
				lines.append(enemy.net_state())
		if not lines.is_empty():
			Net.sync_ask("es", {"l": lines}, false)
	_own_left -= delta
	if _own_left <= 0.0:
		_own_left = OWNERSHIP_EVERY
		_settle_owners()
	_facts_left -= delta
	if _facts_left <= 0.0:
		_facts_left = FACTS_EVERY
		_send_facts()
	_quiet_left -= delta
	if _quiet_left <= 0.0:
		_quiet_left = 1.0
		var now := Time.get_ticks_msec() / 1000.0
		for id: int in _puppets.keys():
			var copy: Enemy = _puppets[id]
			if not is_instance_valid(copy):
				_puppets.erase(id)
			elif copy.state != Enemy.State.DEAD and now - copy._net_heard > QUIET_COPY:
				_puppets.erase(id)
				copy.queue_free()


## Each of this game's monsters goes to the nearest player's game, or is let
## go when nobody is near.
func _settle_owners() -> void:
	for id: int in _owned.keys():
		var enemy: Enemy = _owned[id]
		if not is_instance_valid(enemy) or enemy.state == Enemy.State.DEAD:
			continue
		var mine := _my_distance(enemy.global_position)
		var other: Array = _nearest_other(enemy.global_position)
		var nearest := float(other[1])
		if int(other[0]) != 0 and nearest + HANDOVER_MARGIN < mine and not enemy.state in [Enemy.State.WINDUP, Enemy.State.LUNGE]:
			_hand_over(enemy, int(other[0]))
		elif mine > LET_GO and nearest > LET_GO:
			_owned.erase(id)
			Net.sync_ask("gone", {"id": id})
			enemy.queue_free()


## The world as it stands, for the host to give a joining player.
func world_sections() -> Dictionary:
	var gathered := {}
	var clock := Time.get_unix_time_from_system()
	var ages := _resources.gathered_ages()
	for cell: Vector2i in ages:
		gathered["%d,%d" % [cell.x, cell.y]] = clock - float(ages[cell])
	return {"structures": _structures.save_data(), "gathered": gathered}
