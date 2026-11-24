class_name Codex
extends Node
## Everything the player has done and found: monsters slain (the
## bestiary), things gathered, places seen, and the achievements, titles
## and looks those unlock.

signal changed
signal unlocked(id: String)

## Kills of one kind that reveal more of it in the bestiary.
const REVEAL := {"name": 1, "weakness": 10, "drops": 25, "mark": 50}
## With 50 kills of a kind, hits on it do this much more damage.
const HUNTERS_MARK := 1.05

##   stat:  the counter it watches      goal: how many
##   title: a title it unlocks           skin: a look it unlocks
const ACHIEVEMENTS: Array[Dictionary] = [
	{"id": "first_blood", "name": "First Blood", "text": "Defeat a monster.", "stat": "kills", "goal": 1, "gold": 10},
	{"id": "slayer", "name": "Slayer", "text": "Defeat 100 monsters.", "stat": "kills", "goal": 100, "gold": 100, "title": "Slayer"},
	{"id": "butcher", "name": "The Butcher", "text": "Defeat 1000 monsters.", "stat": "kills", "goal": 1000, "gold": 1000, "title": "the Butcher", "skin": "ashen"},
	{"id": "elite_hunter", "name": "Elite Hunter", "text": "Defeat 25 Elites.", "stat": "elites", "goal": 25, "gold": 150},
	{"id": "champion_bane", "name": "Champion's Bane", "text": "Defeat 10 Champions.", "stat": "champions", "goal": 10, "gold": 250, "title": "Champion's Bane"},
	{"id": "giant_slayer", "name": "Giant Slayer", "text": "Defeat 5 Ancient mini-bosses.", "stat": "minibosses", "goal": 5, "gold": 300},
	{"id": "kingslayer", "name": "Kingslayer", "text": "Defeat a world boss.", "stat": "bosses", "goal": 1, "gold": 500, "title": "Kingslayer"},
	{"id": "first_change", "name": "First Change", "text": "Take the first stage of a race evolution.", "stat": "evolutions", "goal": 1, "gold": 200},
	{"id": "fully_grown", "name": "Fully Grown", "text": "Reach the fourth stage of a race evolution.", "stat": "evolutions", "goal": 4, "gold": 2000, "title": "the Evolved"},
	{"id": "legend_hunter", "name": "Legend Hunter", "text": "Slay 5 named monsters roaming the wilds.", "stat": "named", "goal": 5, "gold": 400, "title": "Legend Hunter"},
	{"id": "deaths_hand", "name": "Death's Hand", "text": "Defeat all thirteen world bosses.", "stat": "boss_kinds", "goal": 13, "gold": 3000, "title": "Death's Hand", "skin": "reaper"},
	{"id": "unbroken", "name": "Unbroken", "text": "Parry 50 blows.", "stat": "parries", "goal": 50, "gold": 200, "title": "the Unbroken"},
	{"id": "executioner", "name": "Executioner", "text": "Land 25 finishers.", "stat": "finishers", "goal": 25, "gold": 200},
	{"id": "no_witnesses", "name": "No Witnesses", "text": "Cut down 15 monsters as they flee to warn their faction.", "stat": "silenced", "goal": 15, "gold": 250, "title": "the Silencer"},
	{"id": "false_name", "name": "A False Name", "text": "Catch 30 monsters off guard with a way of fighting their faction did not expect.", "stat": "off_guard", "goal": 30, "gold": 300, "title": "the Deceiver"},
	{"id": "sorrow", "name": "What Sorrow Teaches", "text": "Kneel at a Sorrow Bloom where you fell.", "stat": "sorrow", "goal": 1, "gold": 100},
	{"id": "resonance", "name": "Resonance", "text": "Wake a ruin with its old song.", "stat": "resonance", "goal": 1, "gold": 300},
	{"id": "white_house", "name": "The White House", "text": "Find Saint Lull's House for Foundlings, out in the wheat.", "stat": "lull_found", "goal": 1, "gold": 100},
	{"id": "over_the_wall", "name": "Over the Wall", "text": "Get the children of Saint Lull's out over the wall and into the woods.", "stat": "foundlings_saved", "goal": 1, "gold": 600, "title": "the Runaway"},
	{"id": "keeper_released", "name": "The Keeper Released", "text": "Face the Matron of Saint Lull's.", "stat": "matron_fallen", "goal": 1, "gold": 500},
	{"id": "the_quarry", "name": "The Quarry", "text": "Last out a hunt in the Lull Court's Reserve.", "stat": "reserve_survived", "goal": 1, "gold": 350},
	{"id": "the_promise", "name": "The Promise", "text": "Read all seven Promise Stones.", "stat": "promise_known", "goal": 1, "gold": 500, "title": "Promise-Breaker"},
	{"id": "porcelain", "name": "Porcelain", "text": "Shatter 10 Court masks.", "stat": "masks_broken", "goal": 10, "gold": 400},
	{"id": "the_maw", "name": "The Maw", "text": "Devour 50 remnants.", "stat": "devoured", "goal": 50, "gold": 300, "title": "the Maw"},
	{"id": "many_echoes", "name": "A Chorus", "text": "Learn 12 echoes.", "stat": "echoes", "goal": 12, "gold": 500},
	{"id": "fused", "name": "Two Become One", "text": "Fuse two echoes into one.", "stat": "fusions", "goal": 1, "gold": 300},
	{"id": "namer", "name": "The Namer", "text": "Give a monster a Name.", "stat": "names_given", "goal": 1, "gold": 200, "title": "the Namer"},
	{"id": "evolved", "name": "Something More", "text": "See a Named companion evolve three times.", "stat": "evolutions", "goal": 3, "gold": 500},
	{"id": "townsfolk", "name": "Monster Town", "text": "Have 5 monsters settle in your town.", "stat": "citizens", "goal": 5, "gold": 600, "title": "Lord of Monsters"},
	{"id": "rising", "name": "The Rising", "text": "Hold the Festival of Rising.", "stat": "festivals", "goal": 1, "gold": 300},
	{"id": "awakened", "name": "The Pact", "text": "Survive the Drowned Chapel and accept the Pact.", "stat": "awakened", "goal": 1, "gold": 300, "title": "the Bearer"},
	{"id": "rites", "name": "Diligence", "text": "Finish the Tenday Road 10 times.", "stat": "rites", "goal": 10, "gold": 500},
	{"id": "penalty", "name": "Atonement", "text": "Survive the Pit of Atonement.", "stat": "penalties", "goal": 1, "gold": 150},
	{"id": "gatebreaker", "name": "Gatebreaker", "text": "Clear 25 gates.", "stat": "gates", "goal": 25, "gold": 800, "title": "Gatebreaker"},
	{"id": "red_gate", "name": "Seen Red", "text": "Come out of a red gate alive.", "stat": "red_gates", "goal": 1, "gold": 400},
	{"id": "sovereign", "name": "Shade Sovereign", "text": "Change your job in the Vigil of Ashes.", "stat": "job_changed", "goal": 1, "gold": 600, "title": "the Shade Sovereign"},
	{"id": "arise", "name": "Arise", "text": "Raise 30 shadows.", "stat": "shadows", "goal": 30, "gold": 500},
	{"id": "kingslayer", "name": "Kingslayer", "text": "Fell a Monarch.", "stat": "monarchs", "goal": 1, "gold": 1500, "title": "Kingslayer"},
	{"id": "peacemaker", "name": "Peacemaker", "text": "Make treaties with 3 factions.", "stat": "treaties", "goal": 3, "gold": 600, "title": "the Peacemaker"},
	{"id": "explorer", "name": "Explorer", "text": "Discover 5 lands.", "stat": "biomes", "goal": 5, "gold": 100},
	{"id": "wayfarer", "name": "Wayfarer", "text": "Discover 12 lands.", "stat": "biomes", "goal": 12, "gold": 600, "title": "Wayfarer", "skin": "verdant"},
	{"id": "seer", "name": "Seer", "text": "Read 3 obelisks.", "stat": "obelisks", "goal": 3, "gold": 150},
	{"id": "stonewalker", "name": "Stonewalker", "text": "Wake 5 waystones.", "stat": "waystones", "goal": 5, "gold": 150},
	{"id": "gatherer", "name": "Gatherer", "text": "Gather 100 times.", "stat": "gathered", "goal": 100, "gold": 100},
	{"id": "angler", "name": "Angler", "text": "Catch 25 fish.", "stat": "fish", "goal": 25, "gold": 150, "title": "Angler"},
	{"id": "artisan", "name": "Artisan", "text": "Craft 50 things.", "stat": "crafted", "goal": 50, "gold": 200, "title": "Artisan"},
	{"id": "homeowner", "name": "Homeowner", "text": "Build a house.", "stat": "houses", "goal": 1, "gold": 100},
	{"id": "lord_of_the_manor", "name": "Lord of the Manor", "text": "Enlarge a house into a manor.", "stat": "manors", "goal": 1, "gold": 500, "title": "Lord of the Manor"},
	{"id": "green_thumb", "name": "Green Thumb", "text": "Harvest 20 crops.", "stat": "harvests", "goal": 20, "gold": 150, "title": "Green Thumb"},
	{"id": "patron", "name": "Patron", "text": "Have 3 settlers living at your home.", "stat": "settlers", "goal": 3, "gold": 300},
	{"id": "defender", "name": "Defender", "text": "Repel a raid on your home.", "stat": "raids", "goal": 1, "gold": 250, "title": "Defender"},
	{"id": "bounty_hunter", "name": "Bounty Hunter", "text": "Collect 5 bounties.", "stat": "bounties", "goal": 5, "gold": 300, "title": "Bounty Hunter"},
	{"id": "crypt_crawler", "name": "Crypt Crawler", "text": "Clear a crypt.", "stat": "dungeons", "goal": 1, "gold": 300},
	{"id": "deep_delver", "name": "Deep Delver", "text": "Clear 5 crypts.", "stat": "dungeons", "goal": 5, "gold": 1000, "title": "Deep Delver"},
	{"id": "treasure_hunter", "name": "X Marks the Spot", "text": "Dig up 3 buried caches.", "stat": "treasure", "goal": 3, "gold": 200},
	{"id": "one_of_a_kind", "name": "One of a Kind", "text": "Find a unique item.", "stat": "uniques", "goal": 1, "gold": 200},
	{"id": "collector", "name": "Collector", "text": "Find 5 pieces of named sets.", "stat": "set_pieces", "goal": 5, "gold": 300},
	{"id": "seasoned", "name": "Seasoned", "text": "Reach level 25.", "stat": "level", "goal": 25, "gold": 300},
	{"id": "dawnbringer", "name": "Dawnbringer", "text": "Reach level 50.", "stat": "level", "goal": 50, "gold": 1500, "title": "Dawnbringer", "skin": "dawn_knight"},
	{"id": "sailor", "name": "Sailor", "text": "Launch a boat.", "stat": "boats", "goal": 1, "gold": 50},
	{"id": "tamer", "name": "Tamer", "text": "Tame a pet.", "stat": "pets", "goal": 1, "gold": 100},
	{"id": "rider", "name": "Rider", "text": "Ride a mount.", "stat": "mounts", "goal": 1, "gold": 100},
]
## One line about each monster, shown once it has been slain.
const LORE := {
	"husk": "What is left when the Heart's pull takes a person and leaves the body walking.",
	"rot_hound": "Dogs of the old farms, gone wild and wrong. They hunt in packs by day.",
	"goblin": "Goblins remember every kindness and every blow. Leave the camp in peace and it leaves you in peace.",
	"goblin_raider": "Cast out of the camps for breaking the peace, raiders paint themselves red so their kin know them on sight.",
	"goblin_chief": "The chief keeps the great tent and the camp's one law: no goblin strikes first.",
	"bone_archer": "A soldier who never stopped standing guard, long after the flesh gave up.",
	"bog_slime": "Living muck. Cut it, and you have two problems.",
	"carrion_bat": "It drinks from the wounded and the dead, and cannot tell the difference.",
	"thorn_stalker": "Its back is a hedge of poisoned spines; it sheds them at anything that moves.",
	"spore_shambler": "A walking mushroom whose breath puts the forest to sleep.",
	"rot_cultist": "They pray to the Heart, and it answers them a little. Never enough.",
	"ember_wisp": "A spark that learned to want. It burns out by burning you.",
	"ash_wraith": "A ghost of the great burning, made of smoke and grudges.",
	"crag_golem": "The mountain's own anger, given legs and a slow, glowing heart.",
	"frost_wolf": "White wolves of the high snows, with ice grown through their fur.",
	"frost_troll": "It heals as fast as you can cut, unless you bring fire.",
	"dire_boar": "Tusks like scythes and a temper to match. It charges first and never thinks.",
	"treant": "Old oaks that woke angry. The forest does not forgive axes.",
	"sand_scorpion": "Buried in the dunes until something warm walks over.",
	"dune_mummy": "Wrapped kings of a buried empire, still collecting their taxes.",
	"void_stalker": "A hound shaped out of nothing. It is there, and then it is behind you.",
	"void_eye": "It watches from the scar in the world. Do not meet its gaze for long.",
	"crimson_fiend": "Imps grown tall on blood and bad intent.",
	"magma_slime": "A slime that crawled through a fire and liked it.",
	"cinder_imp": "Little devils of the ash fields who throw fire for fun.",
	"bog_lurker": "A frog the size of a cart, with a tongue that reaches further than you'd think.",
	"storm_harpy": "Bird-women of the peaks who ride the storm down onto travellers.",
	"deer": "Shy and swift. The forests are full of them, for now.",
	"wild_hare": "Quick, nervous, and good in a stew.",
	"wild_pig": "Mind the temper: it will charge if you hit it.",
	"mountain_goat": "Sure-footed on the cliffs, and it butts back.",
	"pheasant": "A bright bird that bursts from the grass.",
	"desert_lizard": "Sunning on the rocks until something moves.",
	"snow_fox": "A white ghost of the snowfields, prized for its fur.",
	"shore_crab": "Snaps at anything that pokes it.",
	"marsh_toad": "Fat, slow, and singing all night.",
	"sheep": "Flocks gone wild since the farms emptied. Wool, mutton, and no sense at all.",
	"cow": "Slow, patient and worth the chase: beef for a week and a hide besides.",
	"chicken": "It ran from the coop years ago and has been running since.",
	"bear": "Leave it be and it will leave you be. Strike it and you had better finish the job.",
	"grey_wolf": "They hunt the forest roads at night, and never alone.",
	"giant_spider": "It drops on you from the dark with venom on its fangs. Burn it.",
	"web_spider": "It keeps its distance and spits sticky web that drags at your legs.",
	"elk": "The old king of the woods. It lowers those antlers only once.",
	"badger": "Small, striped and furious. Dig near its sett at your peril.",
	"hedgehog": "A ball of spines trundling through the night, eating beetles.",
	"moonstag": "It walks only by moonlight, its antlers lit from within. Hunters say killing one darkens the next night.",
	"snow_leopard": "Grey ghost of the high passes. You will see the tail before you see the teeth.",
	"musk_ox": "A walking haystack of wool and horn that has outlasted every winter.",
	"ice_bear": "White as the snow it sleeps in, and twice the size of its forest cousin.",
	"frostmane": "Wolves the cold got into. Their breath frosts the grass where they run.",
	"camel": "Patient, proud and very, very thirsty. Caravans once crossed the dunes on them.",
	"sand_cat": "A kitten-sized hunter with ears like sails. It hears you long before you see it.",
	"jackal": "They follow the dying across the dunes and laugh at night.",
	"sunscale_basilisk": "A lizard that drank too much sun. Its crest burns like a coal and its stare is worse.",
	"river_otter": "Sleek, playful and always wet. It holds stones in its paws while it sleeps.",
	"moss_tortoise": "So old the bog has grown on its back. It has nowhere to be.",
	"swamp_boar": "A pig the swamp made mean. Caked in mud that dries like armour.",
	"sporeback_deer": "Mushrooms grow where its antlers should be. It leaves a trail of drifting spores.",
	"cinder_hound": "Dogs of the ash fields with embers for manes. They never stop burning, even dead.",
	"ember_salamander": "It swims through hot ash like a fish through water.",
	"thornback_boar": "Thorns grew through its hide and it stopped feeling pain. It stopped feeling anything.",
	"crimson_lynx": "Red as the land it hunts in, with black-tufted ears that catch every sound.",
	"void_prowler": "A great cat whose spots are holes in the world. Look into one and it looks back.",
	"void_hare": "It hops from here to somewhere else. Nobody has caught one twice.",
	"salt_antelope": "It licks the salt flats white and runs faster than anything that chases it.",
	"mountain_ram": "Its horns curl like the mountain roads. It settles every argument with them.",
	"dawn_unicorn": "Seen at first light at the edge of old meadows. To harm one is to be remembered by the land.",
	"veinheart": "A heart that kept beating after its body was gone, and grew veins to walk on.",
	"heartsworn_knight": "Sworn to the Heart's blood, and given more of it than any body can hold.",
	"rotten_corpse": "The graveyard's dead, roots grown through them. They answer to something older underneath.",
	"ghost": "A grudge that outlived the one who held it.",
	"masked_noble": "A courtier of Saint Lull. The mask smiles so the face beneath need not.",
	"matron": "She keeps Saint Lull's house warm, clean and very quiet. She does not like noise.",
	"alpha_wolf": "The white leader of a wolf pack: bigger, older and scarred. Kill it and the pack scatters.",
}

var stats: Dictionary = {}
var kills: Dictionary = {}
var boss_kills: Dictionary = {}
var gathered: Dictionary = {}
var crafted: Dictionary = {}
var caught: Dictionary = {}
## Village centres ("x,y") the player has walked into.
var villages: Dictionary = {}
var biomes: Array = []
var done: Dictionary = {}
var title := ""

var _player: Player


func _ready() -> void:
	SaveGame.register("codex", self)


func setup(player: Player) -> void:
	_player = player
	Events.enemy_killed.connect(_on_kill)
	Events.boss_defeated.connect(func(id: String) -> void:
		boss_kills[id] = boss_kills.get(id, 0) + 1
		count("bosses")
		stats["boss_kinds"] = boss_kills.size()
		_check()
	)
	Events.resource_gathered.connect(func(info: Dictionary) -> void:
		gathered[info["resource"]] = gathered.get(info["resource"], 0) + 1
		count("gathered")
		if GatherDB.RESOURCES.get(info["resource"], {}).get("kind", "") == "fish":
			count("fish")
			caught[info["item"]] = caught.get(info["item"], 0) + int(info.get("count", 1))
	)
	Events.biome_discovered.connect(func(biome: String, _xp: int) -> void:
		if not biome in biomes:
			biomes.append(biome)
		stats["biomes"] = biomes.size()
		_check()
	)
	Events.item_crafted.connect(func(id: String) -> void:
		crafted[id] = crafted.get(id, 0) + 1
		var recipe := RecipeDB.find(id)
		if not recipe.is_empty():
			count("crafted_" + recipe["profession"])
		elif id.begins_with("smelt_"):
			# Ingots from a furnace are the smith's work too.
			count("crafted_blacksmithing")
			count("smelted")
		count("crafted")
	)
	Events.npc_interacted.connect(func(npc: Node) -> void:
		count("talks")
		count("talk_" + str(npc.kind))
	)
	Events.level_up.connect(func(level: int) -> void:
		stats["level"] = maxi(stats.get("level", 0), level)
		_check()
	)
	Events.codex_event.connect(count)
	stats["level"] = maxi(stats.get("level", 0), player.leveling.level)


func count(stat: String, amount: int = 1) -> void:
	stats[stat] = stats.get(stat, 0) + amount
	_check()
	changed.emit()


func set_stat(stat: String, value: int) -> void:
	stats[stat] = maxi(stats.get(stat, 0), value)
	_check()


func _on_kill(info: Dictionary) -> void:
	if info.get("fragment", false):
		return
	kills[info["id"]] = kills.get(info["id"], 0) + 1
	count("kills")
	match info["rank"]:
		"elite":
			count("elites")
		"champion":
			count("champions")
		"miniboss":
			count("minibosses")


func kills_of(id: String) -> int:
	return kills.get(id, 0)


## Damage bonus against a kind the player has hunted to the Hunter's Mark.
func damage_bonus(id: String) -> float:
	return HUNTERS_MARK if kills_of(id) >= REVEAL["mark"] else 1.0


func is_done(id: String) -> bool:
	return done.has(id)


func progress(achievement: Dictionary) -> int:
	return mini(int(stats.get(achievement["stat"], 0)), achievement["goal"])


func titles() -> Array[String]:
	var result: Array[String] = []
	for achievement in ACHIEVEMENTS:
		if done.has(achievement["id"]) and achievement.has("title"):
			result.append(achievement["title"])
	return result


func skins() -> Array[String]:
	var result: Array[String] = ["wanderer"]
	for achievement in ACHIEVEMENTS:
		if done.has(achievement["id"]) and achievement.has("skin"):
			result.append(achievement["skin"])
	return result


func _check() -> void:
	for achievement in ACHIEVEMENTS:
		if done.has(achievement["id"]):
			continue
		if int(stats.get(achievement["stat"], 0)) >= achievement["goal"]:
			done[achievement["id"]] = true
			if _player:
				_player.inventory.add_gold(achievement.get("gold", 0))
			var reward := "+%d gold" % achievement.get("gold", 0)
			if achievement.has("title"):
				reward += ", title \"%s\"" % achievement["title"]
			if achievement.has("skin"):
				reward += ", a new look in the Wardrobe"
			Events.announcement.emit("ACHIEVEMENT: %s" % (achievement["name"] as String).to_upper(), reward)
			Audio.play("level_up", -4.0, 0.0)
			unlocked.emit(achievement["id"])
			SaveGame.request_save()


func save_data() -> Dictionary:
	return {"stats": stats.duplicate(), "kills": kills.duplicate(), "bosses": boss_kills.duplicate(), "gathered": gathered.duplicate(),
		"crafted": crafted.duplicate(), "caught": caught.duplicate(), "villages": villages.duplicate(),
		"biomes": biomes.duplicate(), "done": done.keys(), "title": title}


func load_data(data: Dictionary) -> void:
	for key: String in ["stats", "kills", "bosses", "gathered", "crafted", "caught", "villages"]:
		var saved: Variant = data.get(key, {})
		var target: Dictionary = saved if saved is Dictionary else {}
		match key:
			"stats": stats = target
			"kills": kills = target
			"bosses": boss_kills = target
			"gathered": gathered = target
			"crafted": crafted = target
			"caught": caught = target
			"villages": villages = target
	var saved_biomes: Variant = data.get("biomes", [])
	biomes = saved_biomes if saved_biomes is Array else []
	done.clear()
	for id: Variant in data.get("done", []):
		done[str(id)] = true
	title = str(data.get("title", ""))


var _place_left := 0.0


## Where the player is: villages walked into and islands set foot on.
const LORE_BOOK := preload("res://scripts/progression/lore.gd")


## Opens a story of the world (see Lore), once; `tell` says it aloud too.
func _open_lore(id: String, tell: bool = false) -> void:
	if int(stats.get("lore:" + id, 0)) > 0:
		return
	set_stat("lore:" + id, 1)
	if tell and LORE_BOOK.PLACES.has(id):
		var sites := {"castle": "A KING'S CASTLE", "goblin_camp": "A GOBLIN CAMP"}
		Events.announcement.emit(sites.get(id, str(Structures.SITE_NAMES.get(id, id)).to_upper()), LORE_BOOK.PLACES[id])


## The first time the player stands at a kind of place, its story.
func _check_places(world: World, cell: Vector2i) -> void:
	var structures: Structures = _player.get_parent().get_node_or_null("Structures")
	if structures:
		var site := structures.site_for(Vector2i((Vector2(cell) / World.CHUNK_SIZE).floor()))
		if not site.is_empty() and Vector2(cell - (site["cell"] as Vector2i)).length() < 8.0:
			_open_lore(str(site["kind"]), true)
	var camps: Node = _player.get_parent().get_node_or_null("GoblinCamps")
	if camps:
		var camp: Variant = camps.camp_center(Vector2i((Vector2(cell) / camps.CAMP_REGION).floor()))
		if camp != null and Vector2(cell - (camp as Vector2i)).length() < 10.0:
			_open_lore("goblin_camp", true)
			_open_lore("people_goblin")


func _physics_process(delta: float) -> void:
	_place_left -= delta
	if _place_left > 0.0 or _player == null or _player.indoors:
		return
	_place_left = 1.0
	var world: World = _player.get_parent().get_node_or_null("World")
	if world == null or world.generator == null:
		return
	var cell := world.world_to_cell(_player.global_position)
	var village: Variant = world.generator.village_near(cell)
	if village != null:
		var key := "%d,%d" % [village.x, village.y]
		if not villages.has(key):
			villages[key] = true
			set_stat("villages", villages.size())
			# Each new village by name, and its people's story the first time.
			var people: String = world.generator.village_culture(village)
			var kind := "%s %s" % ["an" if people == "elf" else "a", "elven" if people == "elf" else "dwarven" if people == "dwarf" else "human"]
			Events.announcement.emit(world.generator.village_name(village).to_upper(),
				("The capital, %s city" % kind.substr(kind.find(" ") + 1)) if world.generator.is_capital(village) else "%s village" % kind.capitalize())
			_open_lore("people_" + people)
			_open_lore("village")
		if world.generator.has_castle(village) and Vector2(cell - (village as Vector2i) - Villages.CASTLE_SPOT).length() < 7.0:
			_open_lore("castle", true)
	else:
		_check_places(world, cell)
	if world.generator.is_island(cell) and not stats.has("islands"):
		set_stat("islands", 1)
