class_name VillagerLife
extends RefCounted
## Who lives in a village: names, trades, looks, what they carry and say,
## and the small jobs they ask of a passing stranger.

const NAMES: Array[String] = ["Aldo", "Bree", "Cael", "Dara", "Edda", "Fenn", "Gwen", "Hale", "Ilse", "Joss", "Kett", "Lark",
	"Mira", "Nell", "Oren", "Pell", "Quill", "Rook", "Senna", "Tamsin", "Ulric", "Vesna", "Wren", "Yara", "Zev", "Brann",
	"Corra", "Dunn", "Elsk", "Fara", "Grim", "Hesk", "Ivo", "Jory", "Kira", "Lio", "Maren", "Noll", "Odda", "Piet",
	"Rana", "Sorrel", "Tilda", "Una", "Vale", "Wim", "Ysolde", "Bram", "Cress", "Dov", "Esk", "Fleur", "Gant", "Hild"]
## Who might live here, and how likely each is.
const RACES := {"human": 46.0, "elf": 9.0, "dwarf": 10.0, "beastkin": 7.0, "goblin": 5.0, "orc": 6.0, "lizardfolk": 4.0,
	"stoneborn": 3.0, "merfolk": 3.0, "fairy": 2.0, "demonkin": 2.0, "undead": 1.0}
## Skin tones that look like people rather than slimes, for humans and elves.
const PLAIN_SKINS: Array[int] = [0, 1, 2, 3, 4, 17]
## A trade: its title, what it carries, what it asks for and pays with,
## how it spends the day, and what it says.
## "fetch": [item, count] asked for; "cull": true if they ask for monsters
## dealt with; "pays": [item, count] or ["@gear", rarity].
const JOBS := {
	"farmer": {"title": "Farmer", "carry": "wheat", "fetch": [["wheat", 6], ["carrot", 5], ["potato", 5], ["oak_wood", 8]],
		"pays": [["bread", 3], ["wheat_seeds", 5], ["carrot_seeds", 4], ["pumpkin_seeds", 3], ["cheese", 2]],
		"lines": ["The soil's tired, but it still gives.", "Crows took half the wheat. Husks took the scarecrow.", "Rain soon. My knees say so."]},
	"woodcutter": {"title": "Woodcutter", "carry": "worn_hatchet", "fetch": [["oak_wood", 12], ["pine_wood", 8]], "cull": true,
		"pays": [["torch", 5], ["jerky", 3], ["might_elixir", 1], ["leather", 2]],
		"lines": ["Oak splits clean if you read the grain.", "Something big has been scratching the trees east of here.", "Never cut a spirit tree at night."]},
	"fisher": {"title": "Fisher", "carry": "fishing_rod", "fetch": [["minnow", 4], ["trout", 3], ["perch", 3]],
		"pays": [["grilled_minnow", 4], ["trout_stew", 2], ["salmon_steak", 2]],
		"lines": ["The fish bite best at dusk.", "There's a golden carp in deep water. I've seen it twice.", "Black water past the shore. Don't swim it."]},
	"miner": {"title": "Miner", "carry": "worn_pickaxe", "fetch": [["copper_ore", 6], ["tin_ore", 6], ["coal", 6], ["iron_ore", 4]],
		"pays": [["copper_ingot", 3], ["iron_ingot", 2], ["coal", 8], ["emerald_1", 1]],
		"lines": ["Coal burns in a furnace, ore goes in after. One ore, one ingot.", "Caves go deeper than anyone's mapped.", "Heartstone hums if you put your ear to it."]},
	"hunter": {"title": "Hunter", "carry": "bow", "fetch": [["leather", 3], ["deer_hide", 2], ["venison", 3], ["hare_pelt", 3]], "cull": true,
		"pays": [["jerky", 4], ["roast_venison", 2], ["leather", 3], ["taming_treat", 2]],
		"lines": ["Wolves hunt in threes. Watch the flanks.", "Deer won't come near the graveyard. Smart deer.", "Lure a beast with food it likes and it'll follow you home."]},
	"herbalist": {"title": "Herbalist", "carry": "healing_herb", "fetch": [["healing_herb", 4], ["mana_flower", 3], ["wild_berries", 6], ["poison_mushroom", 3]],
		"pays": [["health_potion", 2], ["mana_potion", 2], ["aloe_salve", 1], ["bandage", 4]],
		"lines": ["Bloodcap heals, but it tastes like a coin.", "Glowshrooms only grow where the ground is sick.", "Bring me herbs and I'll keep you breathing."]},
	"baker": {"title": "Baker", "carry": "bread", "fetch": [["wheat", 8], ["egg", 4], ["milk", 2], ["wild_berries", 6]],
		"pays": [["bread", 4], ["sweet_roll", 3], ["custard_tart", 2], ["berry_tart", 2]],
		"lines": ["Fresh bread at dawn, if the flour holds.", "A full belly fights better. Eat before you go.", "Eggs, milk, wheat. That's all a tart needs. And love."]},
	"guard": {"title": "Guard", "carry": "spear", "fetch": [["bandage", 3], ["iron_ingot", 2]], "cull": true, "night_watch": true,
		"pays": [["health_potion", 2], ["might_elixir", 1], ["@gear", 1], ["dungeon_key", 1]],
		"lines": ["I keep the watch. Someone has to.", "Husks come thicker under a red moon.", "If you hear the bell, run for the fire."]},
	"elder": {"title": "Elder", "carry": "", "fetch": [["bone", 8], ["candles", 2], ["heartwood", 1]], "cull": true, "slow": true,
		"pays": [["@gear", 2], ["treasure_map", 1], ["enchanted_dust", 3], ["heart_shard", 1]],
		"lines": ["Nine bosses, nine pieces, one blade. Or so the song goes.", "The dead in the graveyards don't rest. They never did.", "There's a heart beneath the world. We all feel it beat."]},
	"child": {"title": "Child", "carry": "", "fetch": [["wild_berries", 5], ["feather", 3], ["egg", 2]], "small": true,
		"pays": [["taming_treat", 2], ["sweet_roll", 2], ["topaz_1", 1]],
		"lines": ["Are you an adventurer? Have you killed a dragon?", "I'm not scared of ghosts. Much.", "Mum says not to go past the lanterns."]},
}
## What each trade tends to wear (indices into Appearance's lists).
const WEAR := {
	"farmer": {"hat": [3, 2], "neck": [1]}, "woodcutter": {"hat": [9, 8], "neck": [1]}, "fisher": {"hat": [9, 3, 10], "neck": [1]},
	"miner": {"hat": [8, 2], "neck": [5]}, "hunter": {"hat": [7], "cape": [1, 3], "neck": [2]}, "herbalist": {"hat": [5, 1], "neck": [3, 4]},
	"baker": {"hat": [2], "neck": [3]}, "guard": {"cape": [1, 2], "neck": [5]}, "elder": {"hat": [1, 4], "neck": [3, 4], "cape": [2]},
	"child": {"hat": [5, 9]},
}
## Shared remarks, by the hour.
const MORNING: Array[String] = ["Morning. Mind the mud.", "Up early? Good. Work's waiting.", "The night's done. We made it again."]
const DUSK: Array[String] = ["Getting dark. Best be indoors soon.", "Lanterns are lit. Stay close.", "Hear that? Probably nothing."]
const NIGHT: Array[String] = ["What are you doing out? Get inside!", "Keep your voice down.", "They're out there. Can you hear them?"]


## Rolls one villager of a village: name, trade, look. The same village
## always has the same people.
static func make(village: Vector2i, index: int, world_seed: int) -> Dictionary:
	var random := RandomNumberGenerator.new()
	random.seed = hash(Vector4i(village.x, village.y, index, world_seed + 17))
	var jobs: Array = JOBS.keys()
	# The first is always on watch; the rest follow their own trades.
	var job: String = "guard" if index == 0 else jobs[random.randi() % jobs.size()]
	var race := _pick_race(random)
	var look := Appearance.for_race(race)
	for row in Appearance.OPTIONS:
		if row[0] in ["hair", "clothes", "trousers", "eyes"]:
			look[row[0]] = random.randi() % Appearance.list(row[2]).size()
	if race in ["human", "elf", "dwarf"]:
		look["skin"] = PLAIN_SKINS[random.randi() % PLAIN_SKINS.size()]
	if random.randf() < 0.85:
		var styles := Appearance.hair_styles_with_hair()
		look["hair_style"] = styles[random.randi() % styles.size()]
	if job != "child" and random.randf() < 0.3:
		look["beard"] = random.randi() % Appearance.BEARDS.size()
	if job == "elder":
		look["hair"] = 4
	# Dressed for the work: a hat, maybe something round the neck.
	var wear: Dictionary = WEAR.get(job, {})
	if wear.has("hat") and random.randf() < 0.75:
		look["hat"] = (wear["hat"] as Array)[random.randi() % (wear["hat"] as Array).size()]
	if wear.has("neck") and random.randf() < 0.5:
		look["neck"] = (wear["neck"] as Array)[random.randi() % (wear["neck"] as Array).size()]
	if wear.has("cape") and random.randf() < 0.5:
		look["cape"] = (wear["cape"] as Array)[random.randi() % (wear["cape"] as Array).size()]
	if random.randf() < 0.12:
		look["accessory"] = [1, 3, 4, 5][random.randi() % 4]
	look["dye"] = random.randi() % Appearance.DYES.size()
	look["height"] = clampi(int(look.get("height", 2)) + random.randi_range(-1, 1), 0, Appearance.HEIGHTS.size() - 1)
	look["build"] = random.randi() % Appearance.BUILDS.size()
	# Names step through the list from a village's own start, so no two
	# neighbours share one.
	var first := posmod(hash(Vector3i(village.x, village.y, world_seed)), NAMES.size())
	return {"name": NAMES[(first + index * 7) % NAMES.size()], "job": job, "look": look, "key": "villager:%d,%d:%d" % [village.x, village.y, index]}


static func _pick_race(random: RandomNumberGenerator) -> String:
	var total := 0.0
	for race: String in RACES:
		total += RACES[race]
	var roll := random.randf() * total
	for race: String in RACES:
		roll -= RACES[race]
		if roll <= 0.0 and Appearance.RACES.has(race):
			return race
	return "human"


## What people say about each kind of place.
const RUMOURS := {
	"graveyard": "There's a graveyard %s of here. Go near and the dead climb out.",
	"boss": "Something huge waits in an arena %s of here. Leave it be.",
	"dojo": "A master lives in a dojo %s of here. Teaches the old fighting ways, for a price.",
	"dungeon": "There's a sealed crypt %s of here. You'll want a key.",
	"lair": "A lair %s of here. Ancient things sleep in it.",
	"cave": "There's a cave %s of here. Ore down there, and worse.",
	"portal": "A tear in the world opened %s of here. Things come through.",
	"library": "An old library stands %s of here. Full of dust and secrets.",
	"merchant": "A trader camps %s of here. Rare wares, rarer prices.",
	"shrine": "There's a shrine %s of here. Pray and you'll feel stronger.",
	"waystone": "A waystone stands %s of here. Wake it and you can travel back.",
	"watchtower": "An old watchtower %s of here. Bandits used it once.",
	"henge": "Standing stones %s of here. Lay a hand on the capstone.",
	"farmstead": "There's a farmstead %s of here. Good folk.",
	"village": "Another village lies %s of here. Follow the road.",
	"ruin": "Ruins %s of here. Chests, if the husks left any.",
	"camp": "Somebody's camp lies %s of here. Abandoned. Nobody knows why.",
	"obelisk": "There's an obelisk %s of here. It hums at night.",
	"shipwreck": "A wreck washed up %s of here.",
	"altar": "The Altar of Magic lies %s of here, far out. Magic's taught there.",
}


## Something to say when spoken to: about the hour, their work, or what
## lies near.
static func line(job: String, hour: String, rumours: Array[String]) -> String:
	var options: Array[String] = []
	options.append_array(JOBS[job]["lines"])
	options.append_array(rumours)
	options.append_array(rumours)
	match hour:
		"morning":
			options.append_array(MORNING)
		"dusk":
			options.append_array(DUSK)
		"night":
			options.append_array(NIGHT)
	return options.pick_random()


## A short remark said aloud as the player passes.
static func passing_remark(job: String, name: String, friend: bool) -> String:
	var options: Array[String] = ["Hello there.", "Safe roads.", "Hm?", "Busy day.", "Nice weather. For once."]
	if friend:
		options.append_array(["Good to see you again!", "Back so soon, friend?", "Thanks again for the help."])
	if job == "child":
		options = ["Hi!", "Watch this!", "Are you strong?", "Tag, you're it!"]
	if job == "guard":
		options.append_array(["Move along.", "Eyes open out there."])
	return options.pick_random()
