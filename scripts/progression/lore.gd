extends RefCounted
## The story of the world: what lies under it, who built on it, why the
## monsters walk it and what each place you find once was. There is no
## ending to reach; this is the history the player uncovers by living in
## the world. Chapters open as the player's deeds reach them (Codex stats);
## the stories of places open when the player first stands in one; a
## monster's family story opens with its first kill. (Loaded by path.)

## The Telling: the world's history, chapter by chapter. Each opens when a
## Codex stat reaches a count ("" opens at once).
const CHAPTERS: Array[Dictionary] = [
	{"id": "heart", "title": "I. The Heart Beneath", "stat": "", "goal": 0,
		"text": "Under the soil, under the stone, under the roots of the oldest trees, something beats. The first peoples called it the Heart. It warmed the ground, filled the rivers and quickened every living thing. Where its pulse ran strong, grass grew in winter. Every fire you light, every seed you plant, borrows a little of that warmth."},
	{"id": "peoples", "title": "II. The Four Peoples", "stat": "villages", "goal": 1,
		"text": "Four peoples woke to the Heart's warmth. The elves listened to it through the roots and built light houses in the deep woods. The dwarves dug toward it and built hard halls in the high stone. The humans followed the rivers and built wherever bread would grow. The goblins wandered between, trading with all of them, owing nothing, and keeping one law: no goblin strikes first."},
	{"id": "crown", "title": "III. The Crown of the Roads", "stat": "talks", "goal": 10,
		"text": "The humans grew many, and roads grew between their villages. A king rose to keep the roads, and built castles where his road met another. His heirs still ride from castle to castle, for a king who is not seen is soon forgotten. The waystones along the roads are older than any crown: the elves raised them, and the dwarves cut their faces."},
	{"id": "sickening", "title": "IV. The Sickening", "stat": "kills", "goal": 50,
		"text": "Then the Heart faltered. No one agrees why. The elves say it grew old; the dwarves say someone cut into it; the goblins say someone stole from it. Where its warmth drained away, the ground went grey and the dead got up. The husks were the first: farmers who lay down in a cold field and rose empty. The monsters you fight are the Heart's sickness wearing borrowed shapes."},
	{"id": "wound", "title": "V. The Void Wound", "stat": "minibosses", "goal": 1,
		"text": "Far out, the ground tore. Through the wound came the void: not darkness but absence, a hunger with eyes. Its portals still open where the world is thin, and its crystals grow wherever it has touched. The obelisks were raised to watch it; the henges to hold it back. Some still work."},
	{"id": "keepers", "title": "VI. The Keepers of the Hollow Halls", "stat": "dungeons", "goal": 1,
		"text": "Before the Sickening there were halls under the ground where the Heart could be heard most clearly, and keepers who tended them. When the sickness came the keepers sealed themselves in with it, to keep it below. The crypts you open are those halls. What waits inside was once their keepers."},
	{"id": "giants", "title": "VII. The Fallen God", "stat": "colossus_seen", "goal": 1,
		"text": "The colossi you find broken in the fields were statues of the one the first peoples thanked for the Heart. When the Heart faltered they pulled the statues down, each people blaming the god for a different reason. The arches that still stand once led to his temples. Laying a hand on the stones, some say, the warmth can still be felt."},
	{"id": "now", "title": "VIII. The Long Night", "stat": "bosses", "goal": 3,
		"text": "This is the age you were born into: villages that bar their doors at dusk, guards who walk the lanterns, kings who ride with swords drawn. The Heart still beats, slower than it did. Every monster put down gives a little warmth back to the ground where it falls. The story has no ending yet. It is waiting for someone to write the next chapter."},
]

## The peoples, told in their own villages.
const PEOPLES := {
	"human": "Humans build in timber and plaster on a stone footing, with steep roofs against the rain. Every village has a guard, an elder and a fire that never goes out. A few have a castle; fewer have a king inside it.",
	"elf": "Elves grow their houses as much as build them: living posts curve up into leaf-shingled roofs, and the windows hold a soft green light. Bladewardens and Longbow Wardens keep the woods, and a High Sage keeps the wardens.",
	"dwarf": "Dwarves build of dressed stone, banded with iron, with doors that no husk has ever broken. Their forges never cool. A Thane leads each hold, and the hold's guards carry axes because axes also cut firewood.",
	"goblin": "Goblins live in camps of patched hide round a fire, the chief's great tent in the middle. They keep one law: no goblin strikes first. A goblin who breaks it is painted red and driven out: the raiders you meet in the wild are those exiles. The cleverest goblins live alone in houses and will teach anyone polite enough to listen.",
}

## Each monster's family, and the family's story.
const FAMILIES := {
	"husks": {"name": "The Emptied", "members": ["husk", "rotten_corpse", "rot_cultist", "spore_shambler", "dune_mummy"],
		"text": "The first of the Heart's sickness: people who lay down where the ground had gone cold and rose with nothing inside. They walk toward warmth (villages, fires, you) and do not know why."},
	"bones": {"name": "The Unburied", "members": ["bone_archer", "ghost", "ash_wraith", "masked_noble", "matron"],
		"text": "Those the keepers buried with honour, woken by the Heart's last pulses. Bones remember drills; ghosts remember grudges. The masked ones of the Lull Court remember something worse, and smile about it."},
	"rot_beasts": {"name": "The Soured", "members": ["rot_hound", "carrion_bat", "bog_slime", "bog_lurker", "marsh_toad", "giant_spider", "web_spider"],
		"text": "Animals that ate from sick ground and changed. They are not cruel, only hungry in a way that cannot be filled."},
	"wild": {"name": "The Living Wild", "members": ["deer", "wild_hare", "wild_pig", "mountain_goat", "pheasant", "desert_lizard", "snow_fox", "shore_crab", "sheep", "cow", "chicken",
			"bear", "elk", "badger", "hedgehog", "snow_leopard", "musk_ox", "ice_bear", "camel", "sand_cat", "jackal", "river_otter", "moss_tortoise", "swamp_boar",
			"thornback_boar", "crimson_lynx", "salt_antelope", "mountain_ram", "grey_wolf", "alpha_wolf", "frost_wolf", "dire_boar"],
		"text": "Creatures still warm with the Heart. Where they thrive the land is healthy; hunt them and you live off that health. Wolves run in packs behind a white alpha; kill it and they scatter."},
	"fey": {"name": "The Heart's Children", "members": ["moonstag", "frostmane", "dawn_unicorn", "sporeback_deer", "treant", "sunscale_basilisk"],
		"text": "Beasts born where the Heart's pulse broke the surface: strange, old and half made of the land itself. The elves say each one is the Heart dreaming."},
	"embers": {"name": "The Kindled", "members": ["ember_wisp", "cinder_hound", "ember_salamander", "magma_slime", "cinder_imp", "crag_golem"],
		"text": "Where the Heart's warmth leaks up too fast, the ground burns. Things are born in that fire and want only to spread it."},
	"frost": {"name": "The Frozen Watch", "members": ["frost_troll", "storm_harpy", "sand_scorpion", "thorn_stalker"],
		"text": "Hunters of the far lands, made hard by places the Heart barely reaches. They guard their cold country like a hoard."},
	"void": {"name": "The Absent", "members": ["void_stalker", "void_eye", "void_prowler", "void_hare"],
		"text": "Things from the Void Wound, or things that were near it too long. They are hollow where a heart should be, and they look at yours."},
	"heart": {"name": "The Heartbound", "members": ["veinheart", "heartsworn_knight", "crimson_fiend"],
		"text": "Those who tried to take the Heart's warmth for themselves: knights sworn to its blood, fiends grown fat on it. Their own hearts beat too loud now."},
	"goblins": {"name": "The Goblin Camps", "members": ["goblin", "goblin_chief", "goblin_raider"],
		"text": PEOPLES["goblin"]},
}

## What each kind of place was, and is.
const PLACES := {
	"village": "Where people still live. Rest by the fire, take work from the guard, trade at the stall. Every village is built in its people's own way.",
	"ruin": "A village that did not bar its doors in time. Its stones still hum a tune; play it back and the floor opens on what they hid.",
	"shrine": "Small altars to the fallen god, kept by travellers. A prayer still earns a blessing, once a day.",
	"cave": "The dwarves' first diggings toward the Heart, left when the ground turned. Ore remains, and things that like the dark.",
	"lair": "Where a great beast of the Sickening sleeps on what it has taken.",
	"portal": "A place where the Void Wound reaches through. Close it, or step in if you are brave.",
	"dungeon": "One of the keepers' sealed halls. The key is the old kind: earned, not made.",
	"boss": "A battlefield the Heart remembers. Something enormous returns to it, again and again.",
	"camp": "Someone's last camp. They left in a hurry, and left a note.",
	"waystone": "Raised by elves, cut by dwarves, used by everyone. Wake it, and it will remember you.",
	"obelisk": "A watchtower against the void, built of stone that sees. Touch it and it shows you the land around.",
	"merchant": "A trader brave enough to camp between villages. Rare wares; rarer prices.",
	"watchtower": "A king's tower on the old road, held now by whoever took it last.",
	"graveyard": "The keepers' dead, buried with honour. They do not stay buried.",
	"henge": "Standing stones set by elves and goblins together, the one time they agreed. They held the void back once.",
	"farmstead": "A family farm out on its own, stubborn and well fed.",
	"library": "The elves' record of the Heart's beat, kept year by year. Reading it teaches more than it should.",
	"dojo": "A master of an old fighting way waits here for a student worth teaching.",
	"shipwreck": "A ship that tried to sail away from the Sickening. The sea sent it back.",
	"altar": "The Altar of Magic, far out, where the Heart's warmth can be shaped by will.",
	"orphanage": "Saint Lull's House for Foundlings. Warm, clean and very quiet.",
	"bunker": "A grassy hatch in the ground. Somebody planned an escape.",
	"promise_stone": "A stone where promises were cut. Some were kept.",
	"colossus": "A statue of the fallen god, pulled down by the people who carved it.",
	"arches": "The broken gates of the god's temple roads.",
	"goblin_camp": "Goblin tents round a fire, the chief's great tent in the middle. Walk in peace and you will be left in peace.",
	"castle": "A king's castle. His guards stand at the gate; now and then, he is home.",
}


## The family a monster belongs to, or "".
static func family_of(enemy_id: String) -> String:
	for id: String in FAMILIES:
		if enemy_id in FAMILIES[id]["members"]:
			return id
	return ""


## The chapters open to a player with these Codex stats.
static func open_chapters(stats: Dictionary) -> Array[Dictionary]:
	var open: Array[Dictionary] = []
	for chapter: Dictionary in CHAPTERS:
		if chapter["stat"] == "" or int(stats.get(chapter["stat"], 0)) >= int(chapter["goal"]):
			open.append(chapter)
	return open


## Places whose stories the player has opened (Codex stat "lore:<kind>").
static func known_places(stats: Dictionary) -> Array[String]:
	var known: Array[String] = []
	for kind: String in PLACES:
		if int(stats.get("lore:" + kind, 0)) > 0:
			known.append(kind)
	return known
