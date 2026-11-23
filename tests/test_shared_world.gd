extends RefCounted
## The shared world's referee: who runs each monster, who hears of what,
## who gets a drop, and where monsters go when a player leaves. Played out
## in one game, as the host (peer 1) with a pretend guest (peer 7).

const GUEST := 7


func _referee(t: TestContext) -> Array:
	var heard: Array = []
	var listen := func(kind: String, data: Variant, from: int) -> void: heard.append([kind, data, from])
	Net.world_msg.connect(listen)
	Net.roster = {1: {"name": "Host"}, GUEST: {"name": "Guest"}}
	Net.rules = {"interest": 1000.0}
	Net.places = {1: {"p": Vector2.ZERO, "i": "", "dead": false}, GUEST: {"p": Vector2(5000, 0), "i": "", "dead": false}}
	var referee := WorldReferee.new()
	t.tree.root.add_child(referee)
	return [referee, heard, listen]


func _done(parts: Array) -> void:
	Net.world_msg.disconnect(parts[2])
	(parts[0] as Node).queue_free()
	Net.roster.clear()
	Net.places.clear()
	Net.rules.clear()


func _kinds(heard: Array) -> Array:
	return heard.map(func(entry: Array) -> String: return entry[0])


func test_a_fixed_monster_is_run_by_one_game(t: TestContext) -> void:
	var parts := _referee(t)
	var referee: WorldReferee = parts[0]
	var heard: Array = parts[1]
	referee.handle("reg", {"id": 100, "key": "lair|boss|0,0", "spec": {"e": "husk"}, "p": Vector2(5000, 10), "i": ""}, GUEST)
	referee.handle("reg", {"id": 200, "key": "lair|boss|0,0", "spec": {"e": "husk"}, "p": Vector2(5000, 10), "i": ""}, 1)
	t.check("reg_no" in _kinds(heard), "the second game's copy of the same lair boss is turned away")
	t.equal(int(referee.enemies[100]["owner"]), GUEST, "the first stays with the game that made it")
	referee.handle("reg", {"id": 300, "key": "wander|1,1", "spec": {"e": "husk"}, "p": Vector2(10, 0), "i": ""}, 1)
	t.check(referee.enemies.has(300), "a different monster is taken")
	_done(parts)


func test_players_hear_only_of_what_is_near(t: TestContext) -> void:
	var parts := _referee(t)
	var referee: WorldReferee = parts[0]
	var heard: Array = parts[1]
	referee.handle("reg", {"id": 101, "key": "", "spec": {"e": "husk"}, "p": Vector2(5000, 0), "i": ""}, GUEST)
	referee._update_interest(1)
	t.check(not "espec" in _kinds(heard), "a monster far away is not told of")
	referee.enemies[101]["p"] = Vector2(300, 0)
	referee._update_interest(1)
	t.check("espec" in _kinds(heard), "one coming near is (with what it is)")
	referee.handle("es", {"l": [[101, 320.0, 0.0, 0, 0, 1, 0.0, 50.0, 60.0, 1.0, 0.0, 1.0, 0.0]]}, GUEST)
	t.check("es" in _kinds(heard), "and then where it goes")
	referee.enemies[101]["p"] = Vector2(4000, 0)
	referee._update_interest(1)
	t.check("forget" in _kinds(heard), "gone far, it is forgotten")
	# Someone in a cave does not hear of the world outside.
	heard.clear()
	referee.enemies[101]["p"] = Vector2(100, 0)
	Net.places[1]["i"] = "Cave@0,90000"
	referee._update_interest(1)
	t.check(not "espec" in _kinds(heard), "a player in a cave hears nothing of the world outside")
	_done(parts)


func test_a_kill_belongs_to_the_last_striker(t: TestContext) -> void:
	var parts := _referee(t)
	var referee: WorldReferee = parts[0]
	var heard: Array = parts[1]
	referee.handle("reg", {"id": 102, "key": "", "spec": {"e": "husk"}, "p": Vector2(10, 0), "i": ""}, GUEST)
	referee.handle("hit", {"id": 102, "a": 10.0}, 1)
	referee.handle("died", {"id": 102, "killer": 1, "info": {"xp": 12}}, GUEST)
	var kill: Array = heard.filter(func(entry: Array) -> bool: return entry[0] == "kill")
	t.equal(kill.size(), 1, "the striker's game is told it made the kill")
	t.equal(int((kill[0][1] as Dictionary)["info"]["xp"]) if not kill.is_empty() else 0, 12, "with what it was worth")
	t.check(not referee.enemies.has(102), "and the monster is off the books")
	_done(parts)


func test_a_drop_goes_to_whoever_reaches_it_first(t: TestContext) -> void:
	var parts := _referee(t)
	var referee: WorldReferee = parts[0]
	var heard: Array = parts[1]
	referee.handle("lreg", {"id": 900, "data": {"gold": 5}, "p": Vector2(10, 0), "i": ""}, GUEST)
	referee.handle("ltake", {"id": 900}, 1)
	referee.handle("ltake", {"id": 900}, GUEST)
	t.check("lyes" in _kinds(heard), "the first to ask gets it")
	t.check(not referee.loot.has(900), "and it is gone for everyone")
	heard.clear()
	referee.handle("ltake", {"id": 900}, 1)
	t.check("lno" in _kinds(heard), "asking again gets nothing")
	_done(parts)


func test_a_leaving_players_monsters_go_to_the_nearest(t: TestContext) -> void:
	var parts := _referee(t)
	var referee: WorldReferee = parts[0]
	var heard: Array = parts[1]
	referee.handle("reg", {"id": 103, "key": "", "spec": {"e": "husk"}, "p": Vector2(200, 0), "i": ""}, GUEST)
	referee.handle("reg", {"id": 104, "key": "", "spec": {"e": "husk"}, "p": Vector2(90000, 0), "i": ""}, GUEST)
	referee.peer_left(GUEST)
	var taken: Array = heard.filter(func(entry: Array) -> bool: return entry[0] == "take")
	t.equal(taken.size(), 1, "the monster near the host goes to the host's game")
	t.equal(int(referee.enemies[103]["owner"]) if referee.enemies.has(103) else 0, 1, "which now runs it")
	t.check(not referee.enemies.has(104), "one near nobody is let go")
	_done(parts)


func test_a_crowd_keeps_the_ground_within_the_hosts_limit(t: TestContext) -> void:
	var parts := _referee(t)
	var referee: WorldReferee = parts[0]
	referee.max_active_chunks = 20
	for index in 6:
		Net.places[100 + index] = {"p": Vector2(index * 20000, 0), "i": "", "dead": false}
	referee._measure()
	t.check(referee.active_chunks() > 20, "six players apart keep much ground active")
	t.check(referee.radius_for(1) < 1000.0, "so each hears of a smaller circle")
	# Rooms past the limit are not shared.
	referee.max_instances = 1
	Net.places[100] = {"p": Vector2.ZERO, "i": "Crypt@0,1", "dead": false}
	Net.places[101] = {"p": Vector2.ZERO, "i": "Cave@0,1", "dead": false}
	referee._measure()
	t.check(referee.shares("Crypt@0,1") != referee.shares("Cave@0,1"), "only one room is shared at a time")
	_done(parts)


func test_server_settings_reach_the_rules(t: TestContext) -> void:
	var problem := Net.host_dedicated({"port": 24799, "max_players": 4, "pvp": true, "enemy_sim_distance": 900, "chunk_sim_distance": 1})
	t.equal(problem, "", "a test server opens")
	t.check(bool(Net.rules.get("pvp", false)), "fighting between players follows the setting")
	t.check(float(Net.rules.get("interest", 0.0)) >= 900.0, "how far players hear follows the monster distance")
	t.check(Net.referee != null, "and the server keeps a referee")
	Net.leave("")
	t.check(Net.referee == null and Net.rules.is_empty(), "closed, nothing is left behind")
