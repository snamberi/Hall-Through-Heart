class_name QuestBookDB
extends RefCounted
## Every quest in the Quest Book, grouped into chapters. Quests form trees:
## a quest opens once all it "requires" are done, and completes itself the
## moment its objectives are met (see QuestBook for how they are checked).
##
## A quest: {"id", "chapter", "title", "text", "icon", "requires": [ids],
##   "objectives": [{"type", ...}], "rewards": {"xp", "gold", "items"},
##   "big": true for milestones}. Icons are {"atlas": n}, {"item": id} or
##   {"monster": id}.

const CHAPTERS: Array[Dictionary] = [
	{"id": "main", "name": "Main Story", "icon": {"atlas": 41}},
	{"id": "combat", "name": "Combat", "icon": {"atlas": 0}},
	{"id": "magic", "name": "Magic", "icon": {"atlas": 34}},
	{"id": "classes", "name": "Classes", "icon": {"atlas": 6}},
	{"id": "equipment", "name": "Equipment", "icon": {"atlas": 7}},
	{"id": "crafting", "name": "Crafting", "icon": {"atlas": 54}},
	{"id": "mining", "name": "Mining", "icon": {"atlas": 49}},
	{"id": "farming", "name": "Farming", "icon": {"atlas": 44}},
	{"id": "fishing", "name": "Fishing", "icon": {"atlas": 45}},
	{"id": "hunting", "name": "Hunting & Cooking", "icon": {"monster": "deer"}},
	{"id": "exploration", "name": "Exploration", "icon": {"atlas": 9}},
	{"id": "raids", "name": "Raids & Bosses", "icon": {"monster": "crimson_fiend"}},
	{"id": "side", "name": "Side Quests", "icon": {"atlas": 53}},
]

static var _quests: Array[Dictionary] = []
static var _by_id: Dictionary = {}
static var _chapter: String = ""


static func all() -> Array[Dictionary]:
	if _quests.is_empty():
		_build()
	return _quests


static func find(id: String) -> Dictionary:
	if _quests.is_empty():
		_build()
	return _by_id.get(id, {})


static func chapter_name(id: String) -> String:
	for chapter in CHAPTERS:
		if chapter["id"] == id:
			return chapter["name"]
	return id


## A texture for an icon spec.
static func icon_texture(spec: Dictionary) -> Texture2D:
	if spec.has("atlas"):
		return ItemDB.icon(spec["atlas"])
	if spec.has("item"):
		return Item.create(spec["item"]).icon() if ItemDB.ITEMS.has(spec["item"]) else ItemDB.icon(53)
	if spec.has("monster"):
		var atlas := AtlasTexture.new()
		atlas.atlas = EnemyDB.sheet(spec["monster"])
		atlas.region = Rect2(22, 18, 54, 54)
		return atlas
	return ItemDB.icon(53)


static func icon_tint(spec: Dictionary) -> Color:
	if spec.has("item") and ItemDB.ITEMS.has(spec["item"]):
		return Item.create(spec["item"]).icon_tint()
	return Color.WHITE


# --- building the book

static func _rw(tier: float, items: Array = []) -> Dictionary:
	return {"xp": roundi(30.0 * pow(tier, 1.7)), "gold": roundi(12.0 * pow(tier, 1.5)), "items": items}


static func _q(id: String, title: String, text: String, icon: Dictionary, requires: Array, objectives: Array, tier: float, items: Array = [], big: bool = false) -> String:
	var quest := {"id": id, "chapter": _chapter, "title": title, "text": text, "icon": icon, "requires": requires,
		"objectives": objectives, "rewards": _rw(tier, items), "big": big}
	_quests.append(quest)
	_by_id[id] = quest
	return id


## A chain of quests, each needing the one before; the first needs `parent`.
## steps: [[id, title, text, icon, objectives, tier, items]]
static func _chain(parent: String, steps: Array) -> String:
	var last := parent
	for step: Array in steps:
		last = _q(step[0], step[1], step[2], step[3], [last] if last != "" else [], step[4], step[5], step[6] if step.size() > 6 else [])
	return last


static func _o(type: String, extra: Dictionary = {}) -> Dictionary:
	var objective := {"type": type}
	objective.merge(extra)
	return objective


static func _stat(stat: String, count: int, label: String) -> Dictionary:
	return {"type": "stat", "stat": stat, "count": count, "label": label}


static func _build() -> void:
	_quests.clear()
	_by_id.clear()
	_main()
	_combat()
	_magic()
	_classes()
	_equipment()
	_crafting()
	_mining()
	_farming()
	_fishing()
	_hunting()
	_exploration()
	_raids()
	_side()


static func _main() -> void:
	_chapter = "main"
	var root := _q("main_first_step", "The First Step", "You woke in the Sanctuary with nothing. Gather wood, build a table, and make something to swing.",
		{"atlas": 41}, [], [_o("have", {"item": "oak_wood", "count": 8}), _o("craft", {"item": "crafting_table", "count": 1}), _o("craft", {"item": "wooden_club", "count": 1})], 1.0, [["health_potion", 2]], true)
	_q("main_torchlight", "Torchlight", "The nights are long. Make torches to keep them back.", {"item": "torch"}, [root], [_o("craft", {"item": "torch", "count": 1})], 1.0)
	var blade := _q("main_old_blade", "The Old Blade", "A chest in the Sanctuary holds a sword left for whoever woke there. Take it.", {"atlas": 0}, [root], [_o("own", {"item": "sword"})], 1.2)
	var husks := _chain(blade, [
		["main_awakening", "Awakening", "The husks beyond the stones will not leave you be. Put three down.", {"monster": "husk"}, [_o("kill", {"monster": "husk", "count": 3})], 1.5],
		["main_tools", "Tools of the Trade", "There is copper in the grey rocks. Mine some.", {"atlas": 49}, [_o("gather", {"resource": "copper", "count": 3})], 1.8],
		["main_first_forge", "First Forge", "Smelt or forge something at the crafting table.", {"atlas": 46}, [_stat("crafted_blacksmithing", 1, "Craft at the forge")], 2.0],
		["main_wild", "Into the Wild", "The land changes as you walk. See three kinds of country.", {"atlas": 9}, [_stat("biomes", 3, "Discover lands")], 2.4],
	])
	var village := _chain(husks, [
		["main_village", "Faces in the Fog", "There are still people out here. Find a village.", {"atlas": 56}, [_stat("villages", 1, "Visit a village")], 3.0],
		["main_waystone", "Standing Stones", "Lay your hand on a waystone and wake it.", {"item": "boss_trophy"}, [_stat("waystones", 1, "Wake a waystone")], 3.0],
	])
	_q("main_merchant", "Coin and Trade", "Talk to a village merchant and buy something.", {"atlas": 17}, ["main_village"], [_stat("purchases", 1, "Buy from a merchant")], 2.5)
	_q("main_warden", "Work for the Warden", "The warden posts jobs. Finish one.", {"atlas": 53}, ["main_village"], [_o("wardens", {"count": 1})], 3.0)
	var roof := _chain(village, [
		["main_roof", "A Roof Overhead", "Build a house and sleep in a bed: make a home.", {"atlas": 56}, [_stat("houses", 1, "Build a house"), _o("home")], 4.0, [["torch", 5]]],
		["main_elite", "The Hunt", "Some of the dead are stronger, and carry more. Bring down an Elite.", {"monster": "rot_hound"}, [_stat("elites", 1, "Defeat an Elite")], 4.5],
		["main_cave", "Into the Deep", "Find a cave and go down.", {"atlas": 42}, [_stat("caves", 1, "Enter a cave")], 5.0],
		["main_class", "A Path Chosen", "At level 10 you can choose what you will become.", {"atlas": 6}, [_o("level", {"level": 10}), _o("class")], 6.0, [], ],
	])
	var crypt := _chain(roof, [
		["main_ancient", "The Ancient Ones", "Lairs hold mini-bosses older than the husks. Defeat one.", {"monster": "crag_golem"}, [_stat("minibosses", 1, "Defeat an Ancient")], 7.0],
		["main_crypt", "The Sealed Crypt", "Descend into a crypt and clear it to the last room.", {"item": "dungeon_key"}, [_stat("dungeons", 1, "Clear a crypt")], 8.0, [["heart_shard", 2]]],
		["main_portal", "Through the Void", "Step into a void portal and survive its waves.", {"atlas": 16}, [_stat("portals", 1, "Clear a void portal")], 8.5],
	])
	_q("main_bounty", "A Name and a Price", "Take a bounty from a village board and collect it.", {"atlas": 53}, ["main_crypt"], [_stat("bounties", 1, "Collect a bounty")], 7.0)
	var throne := _chain(crypt, [
		["main_kingslayer", "Kingslayer", "Somewhere out there a world boss waits in its arena. Defeat one.", {"monster": "husk"}, [_stat("bosses", 1, "Defeat a world boss")], 10.0, [["heart_shard", 3]]],
		["main_level25", "Seasoned", "Reach level 25.", {"atlas": 35}, [_o("level", {"level": 25})], 9.0],
		["main_voidscar", "The Scar in the World", "Walk the Voidscar, where the world has worn through.", {"atlas": 16}, [_o("biome", {"name": "Voidscar"})], 10.0],
		["main_islands", "Beyond the Black Water", "Build or buy a boat and set foot on an island.", {"atlas": 43}, [_stat("boats", 1, "Launch a boat"), _stat("islands", 1, "Reach an island")], 10.0],
		["main_six", "The Six Thrones", "Defeat all six world bosses.", {"monster": "ash_wraith"}, [_stat("boss_kinds", 6, "World bosses defeated")], 14.0, [["heart_shard", 6]]],
		["main_level50", "Echoes of the Heart", "Reach level 50. Something beneath the world stirs.", {"atlas": 35}, [_o("level", {"level": 50})], 15.0, [], ],
	])
	_quests[-1]["big"] = true
	_by_id["main_six"]["big"] = true
	_by_id["main_crypt"]["big"] = true
	_by_id["main_class"]["big"] = true
	_q("main_level75", "To Be Continued", "The story goes on from here in a later update.", {"atlas": 41}, [throne], [_o("level", {"level": 75})], 18.0)


static func _combat() -> void:
	_chapter = "combat"
	var root := _q("combat_root", "First Blood", "Defeat any monster.", {"atlas": 0}, ["main_awakening"], [_stat("kills", 1, "Defeat monsters")], 1.0, [], true)
	_chain(root, [
		["combat_kills_50", "Monster Slayer", "Defeat 50 monsters.", {"atlas": 0}, [_stat("kills", 50, "Defeat monsters")], 3.0],
		["combat_kills_250", "Butcher's Work", "Defeat 250 monsters.", {"atlas": 1}, [_stat("kills", 250, "Defeat monsters")], 5.0],
		["combat_kills_1000", "A Thousand Dead", "Defeat 1000 monsters.", {"atlas": 22}, [_stat("kills", 1000, "Defeat monsters")], 8.0],
		["combat_kills_5000", "Endless War", "Defeat 5000 monsters.", {"atlas": 23}, [_stat("kills", 5000, "Defeat monsters")], 12.0],
	])
	_chain(root, [
		["combat_elite_10", "Elite Hunter", "Defeat 10 Elites.", {"monster": "rot_hound"}, [_stat("elites", 10, "Defeat Elites")], 4.0],
		["combat_elite_50", "Elite Bane", "Defeat 50 Elites.", {"monster": "rot_hound"}, [_stat("elites", 50, "Defeat Elites")], 7.0],
		["combat_champ_10", "Champion Slayer", "Defeat 10 Champions.", {"monster": "crimson_fiend"}, [_stat("champions", 10, "Defeat Champions")], 8.0],
		["combat_ancient_10", "Ancient Ender", "Defeat 10 Ancient mini-bosses.", {"monster": "crag_golem"}, [_stat("minibosses", 10, "Defeat Ancients")], 10.0],
	])
	_chain(root, [
		["combat_parry_1", "Turn the Blade", "Parry a blow with right mouse.", {"atlas": 5}, [_stat("parries", 1, "Parry")], 2.0],
		["combat_finisher_1", "Coup de Grace", "Land a finisher on a reeling foe.", {"atlas": 26}, [_stat("finishers", 1, "Finisher")], 2.5],
		["combat_parry_50", "The Unbroken", "Parry 50 blows.", {"atlas": 5}, [_stat("parries", 50, "Parry")], 6.0],
		["combat_finisher_50", "Executioner", "Land 50 finishers.", {"atlas": 22}, [_stat("finishers", 50, "Finisher")], 7.0],
	])
	# Weapon mastery, one line per weapon.
	var weapons := {"swords": 0, "greatswords": 1, "axes": 2, "daggers": 3, "spears": 4, "bows": 32}
	for weapon: String in weapons:
		var name: String = WeaponMastery.NAMES[weapon]
		_chain(root, [
			["combat_%s_10" % weapon, "%s Adept" % name, "Train %s to mastery 10." % name.to_lower(), {"atlas": weapons[weapon]}, [_o("mastery", {"weapon": weapon, "level": 10})], 3.0],
			["combat_%s_25" % weapon, "%s Expert" % name, "Train %s to mastery 25." % name.to_lower(), {"atlas": weapons[weapon]}, [_o("mastery", {"weapon": weapon, "level": 25})], 6.0],
			["combat_%s_50" % weapon, "%s Master" % name, "Train %s to mastery 50." % name.to_lower(), {"atlas": weapons[weapon]}, [_o("mastery", {"weapon": weapon, "level": 50})], 10.0],
		])
	# Monster hunts by land.
	var lands := {
		"Fields and Forests": ["husk", "rot_hound", "carrion_bat", "thorn_stalker", "dire_boar", "treant"],
		"Bogs and Fungus": ["bog_slime", "spore_shambler", "bog_lurker", "rot_cultist"],
		"Ash and Cinder": ["ember_wisp", "ash_wraith", "crag_golem", "magma_slime", "cinder_imp", "bone_archer"],
		"Snow and Peaks": ["frost_wolf", "frost_troll", "storm_harpy"],
		"Sand and Salt": ["sand_scorpion", "dune_mummy"],
		"Crimson and Void": ["crimson_fiend", "void_stalker", "void_eye"],
	}
	for land: String in lands:
		var hub := _q("combat_land_" + land.to_snake_case(), "Hunter of " + land, "Learn the monsters of the %s." % land.to_lower(), {"monster": lands[land][0]}, [root],
			[_stat("kills", 20, "Defeat monsters")], 2.0)
		for monster: String in lands[land]:
			var name: String = EnemyDB.ENEMIES[monster]["name"]
			_chain(hub, [
				["combat_%s_10" % monster, name + " Hunter", "Defeat 10 of the %s." % name, {"monster": monster}, [_o("kill", {"monster": monster, "count": 10})], 2.5],
				["combat_%s_50" % monster, name + " Bane", "Defeat 50 of the %s and earn the Hunter's Mark against them." % name, {"monster": monster}, [_o("kill", {"monster": monster, "count": 50})], 5.5],
			])


static func _magic() -> void:
	_chapter = "magic"
	var root := _q("magic_root", "The Spark", "Train staves to mastery 1 by casting a bolt.", {"atlas": 33}, ["main_tools"], [_o("mastery", {"weapon": "staves", "level": 1})], 1.0, [["mana_potion", 3]], true)
	_chain(root, [
		["magic_staves_10", "Apprentice", "Train staves to mastery 10.", {"atlas": 33}, [_o("mastery", {"weapon": "staves", "level": 10})], 3.0],
		["magic_staves_25", "Adept", "Train staves to mastery 25.", {"atlas": 34}, [_o("mastery", {"weapon": "staves", "level": 25})], 6.0],
		["magic_staves_50", "Archmage", "Train staves to mastery 50.", {"atlas": 62}, [_o("mastery", {"weapon": "staves", "level": 50})], 10.0],
	])
	_chain(root, [
		["magic_ability_1", "Words of Power", "Use an ability.", {"atlas": 37}, [_stat("abilities_used", 1, "Use abilities")], 1.5],
		["magic_ability_100", "Practised Caster", "Use abilities 100 times.", {"atlas": 37}, [_stat("abilities_used", 100, "Use abilities")], 4.0],
		["magic_ability_1000", "Spellstorm", "Use abilities 1000 times.", {"atlas": 37}, [_stat("abilities_used", 1000, "Use abilities")], 8.0],
	])
	_chain(root, [
		["magic_mana_potion", "Blue Draught", "Brew a mana potion.", {"item": "mana_potion"}, [_o("craft", {"item": "mana_potion", "count": 1})], 2.0],
		["magic_alchemy_10", "Alchemist", "Reach alchemy 10.", {"atlas": 47}, [_o("profession", {"profession": "alchemy", "level": 10})], 3.5],
		["magic_bloodcap", "Bloodcap Draught", "Brew a bloodcap draught.", {"item": "bloodcap_draught"}, [_o("craft", {"item": "bloodcap_draught", "count": 1})], 5.0],
		["magic_sunroot", "Liquid Sunlight", "Brew a sunroot elixir.", {"item": "sunroot_elixir"}, [_o("craft", {"item": "sunroot_elixir", "count": 1})], 6.5],
		["magic_void_tonic", "Void Tonic", "Brew a void tonic.", {"item": "void_tonic"}, [_o("craft", {"item": "void_tonic", "count": 1})], 8.0],
	])
	var enchant := _chain(root, [
		["magic_dust", "Glittering Dust", "Make enchanted dust.", {"atlas": 52}, [_o("craft", {"item": "enchanted_dust", "count": 1})], 2.0],
		["magic_enchant_1", "First Enchantment", "Enchant a piece of gear.", {"atlas": 52}, [_stat("enchants", 1, "Enchant gear")], 3.0],
		["magic_enchanting_25", "Enchanter", "Reach enchanting 25.", {"atlas": 52}, [_o("profession", {"profession": "enchanting", "level": 25})], 6.0],
		["magic_enchant_25", "Runecarver", "Enchant gear 25 times.", {"atlas": 52}, [_stat("enchants", 25, "Enchant gear")], 8.0],
	])
	var elements := {"flame_sword": "fire", "frost_sword": "frost", "dark_sword": "shadow", "fang": "poison", "ember_staff": "fire"}
	var hub := _q("magic_elements", "The Five Elements", "Find a weapon steeped in an element.", {"atlas": 18}, [root], [_o("own_any", {"items": elements.keys(), "label": "Own an elemental weapon"})], 3.0)
	for item: String in elements:
		_q("magic_own_" + item, ItemDB.ITEMS[item]["name"], "Own %s." % ItemDB.ITEMS[item]["name"], {"item": item}, [hub], [_o("own", {"item": item})], 4.0)
	var gems := _chain(hub, [
		["magic_gem_1", "Cut and Set", "Set a gem into a socket.", {"atlas": 59}, [_stat("gems_socketed", 1, "Socket gems")], 3.0],
		["magic_gem_10", "Jeweller", "Socket 10 gems.", {"atlas": 59}, [_stat("gems_socketed", 10, "Socket gems")], 6.0],
	])
	for grade in range(2, 6):
		var ids: Array = Gems.KINDS.map(func(kind: String) -> String: return "%s_%d" % [kind, grade])
		_q("magic_gem_grade_%d" % grade, "%s Gems" % ["", "", "Flawed", "Fine", "Flawless", "Perfect"][grade], "Combine gems into a grade %d gem." % grade, {"item": "ruby_%d" % grade}, [gems if grade == 2 else "magic_gem_grade_%d" % (grade - 1)],
			[_o("craft_any", {"items": ids, "count": 1, "label": "Combine a grade %d gem" % grade})], 3.0 + grade * 1.5)
	_chain(enchant, [
		["magic_unique_1", "One of a Kind", "Find a unique item.", {"atlas": 60}, [_stat("uniques", 1, "Find unique items")], 8.0],
		["magic_unique_5", "Legend Collector", "Find 5 unique items.", {"atlas": 62}, [_stat("uniques", 5, "Find unique items")], 12.0],
	])


static func _classes() -> void:
	_chapter = "classes"
	var root := _q("classes_root", "Who Will You Be?", "Reach level 5.", {"atlas": 6}, ["main_awakening"], [_o("level", {"level": 5})], 2.0, [], true)
	var chosen := _chain(root, [
		["classes_level10", "Crossroads", "Reach level 10.", {"atlas": 35}, [_o("level", {"level": 10})], 3.0],
		["classes_choose", "The Path Chosen", "Choose a class.", {"atlas": 6}, [_o("class")], 4.0],
	])
	_chain(chosen, [
		["classes_nodes_1", "First Lesson", "Learn something in your class tree.", {"atlas": 28}, [_o("class_nodes", {"count": 1})], 4.0],
		["classes_nodes_4", "Journeyman", "Learn 4 class ranks.", {"atlas": 28}, [_o("class_nodes", {"count": 4})], 6.0],
		["classes_nodes_8", "Veteran", "Learn 8 class ranks.", {"atlas": 28}, [_o("class_nodes", {"count": 8})], 9.0],
		["classes_nodes_14", "Master of the Path", "Learn 14 class ranks.", {"atlas": 28}, [_o("class_nodes", {"count": 14})], 13.0],
	])
	_chain(chosen, [
		["classes_abilities_2", "Two Hands, Two Tricks", "Know 2 abilities.", {"atlas": 27}, [_o("abilities_known", {"count": 2})], 3.0],
		["classes_abilities_4", "A Full Bar", "Know 4 abilities.", {"atlas": 27}, [_o("abilities_known", {"count": 4})], 5.0],
		["classes_abilities_8", "Two Full Sets", "Know 8 abilities and fill both sets.", {"atlas": 27}, [_o("abilities_known", {"count": 8})], 9.0],
	])
	_chain(root, [
		["classes_talent_1", "Awakened Heart", "Learn your first talent.", {"atlas": 35}, [_o("talents", {"count": 1})], 2.0],
		["classes_talent_10", "Opening the Web", "Spend 10 talent points.", {"atlas": 35}, [_o("talents", {"count": 10})], 4.0],
		["classes_talent_20", "Deeper Roots", "Spend 20 talent points.", {"atlas": 35}, [_o("talents", {"count": 20})], 6.0],
		["classes_talent_30", "Keystone", "Spend 30 talent points.", {"atlas": 35}, [_o("talents", {"count": 30})], 9.0],
		["classes_talent_40", "Heartsong", "Spend 40 talent points.", {"atlas": 35}, [_o("talents", {"count": 40})], 12.0],
	])
	for attribute: String in Attributes.NAMES:
		var name: String = Attributes.NAMES[attribute]
		_chain(root, [
			["classes_%s_20" % attribute, "%s 20" % name, "Raise %s to 20." % name.to_lower(), {"atlas": 38}, [_o("attribute", {"attribute": attribute, "count": 20})], 3.0],
			["classes_%s_50" % attribute, "%s 50" % name, "Raise %s to 50." % name.to_lower(), {"atlas": 38}, [_o("attribute", {"attribute": attribute, "count": 50})], 7.0],
			["classes_%s_100" % attribute, "%s 100" % name, "Raise %s to 100." % name.to_lower(), {"atlas": 38}, [_o("attribute", {"attribute": attribute, "count": 100})], 12.0],
		])


static func _equipment() -> void:
	_chapter = "equipment"
	var root := _q("equipment_root", "Dressed for Danger", "Wear something on your head, body, legs and feet.", {"atlas": 7}, ["main_old_blade"],
		[_o("equip_slot", {"slot": "helmet"}), _o("equip_slot", {"slot": "chest"}), _o("equip_slot", {"slot": "legs"}), _o("equip_slot", {"slot": "boots"})], 2.0, [], true)
	var names := ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic"]
	var last := root
	for rarity in range(1, 6):
		last = _q("equipment_rarity_%d" % rarity, "%s Gear" % names[rarity], "Wear a %s item." % names[rarity].to_lower(), {"atlas": [11, 10, 12, 60, 65][rarity - 1]}, [last],
			[_o("equip_rarity", {"rarity": rarity})], 2.0 + rarity * 2.0)
	_q("equipment_shield", "Shield Wall", "Carry something in your off hand.", {"atlas": 5}, [root], [_o("equip_slot", {"slot": "off_hand"})], 2.0)
	_q("equipment_jewels", "Rings and Things", "Wear a necklace and a ring.", {"atlas": 10}, [root], [_o("equip_slot", {"slot": "necklace"}), _o("equip_slot", {"slot": "ring_1"})], 3.0)
	_chain(root, [
		["equipment_upgrade_1", "Sharpened", "Upgrade a piece of gear to +1.", {"atlas": 46}, [_o("upgrade", {"level": 1})], 2.5],
		["equipment_upgrade_5", "Honed", "Upgrade a piece of gear to +5.", {"atlas": 46}, [_o("upgrade", {"level": 5})], 6.0],
		["equipment_upgrade_10", "Masterwork", "Upgrade a piece of gear to +10.", {"atlas": 46}, [_o("upgrade", {"level": 10})], 11.0],
	])
	_chain(root, [
		["equipment_salvage_1", "Breaking Down", "Salvage a piece of gear.", {"atlas": 2}, [_stat("salvages", 1, "Salvage gear")], 2.0],
		["equipment_salvage_25", "Scrapper", "Salvage 25 pieces of gear.", {"atlas": 2}, [_stat("salvages", 25, "Salvage gear")], 5.0],
		["equipment_salvage_100", "Reclaimer", "Salvage 100 pieces of gear.", {"atlas": 2}, [_stat("salvages", 100, "Salvage gear")], 9.0],
	])
	var sets := _chain(root, [
		["equipment_set_found", "Part of a Whole", "Find a piece of a named set.", {"atlas": 7}, [_stat("set_pieces", 1, "Find set pieces")], 5.0],
		["equipment_set_2", "Matched Pair", "Wear 2 pieces of one set.", {"atlas": 7}, [_o("set_worn", {"count": 2})], 7.0],
		["equipment_set_3", "Kit", "Wear 3 pieces of one set.", {"atlas": 7}, [_o("set_worn", {"count": 3})], 9.0],
		["equipment_set_5", "Full Regalia", "Wear all 5 pieces of one set.", {"atlas": 7}, [_o("set_worn", {"count": 5})], 14.0],
	])
	for set_id: String in ItemDB.ITEM_SETS:
		_q("equipment_set_" + set_id, ItemDB.ITEM_SETS[set_id]["name"], "Find a piece of the %s set." % ItemDB.ITEM_SETS[set_id]["name"], {"item": ItemDB.ITEM_SETS[set_id]["pieces"][0]}, ["equipment_set_found"],
			[_o("own_set", {"set": set_id})], 6.0)
	var levels := [10, 20, 30, 50, 65, 80]
	last = root
	for level: int in levels:
		last = _q("equipment_level_%d" % level, "%s Gear" % ItemDB.tier_name(level), "Wear gear of item level %d or more." % level, {"atlas": 46}, [last], [_o("gear_level", {"level": level})], 3.0 + level / 8.0)
	for item: String in ["leather_cap", "leather_vest", "leather_leggings", "leather_boots"]:
		_q("equipment_" + item, ItemDB.ITEMS[item]["name"], "Stitch a %s from leather." % ItemDB.ITEMS[item]["name"].to_lower(), {"item": item}, [root], [_o("craft", {"item": item, "count": 1})], 2.5)


static func _crafting() -> void:
	_chapter = "crafting"
	var root := _q("crafting_root", "Workbench", "Craft a crafting table.", {"atlas": 54}, ["main_first_step"], [_o("craft", {"item": "crafting_table", "count": 1})], 1.0, [], true)
	var home := _chain(root, [
		["crafting_chest", "Somewhere to Put Things", "Craft a storage chest.", {"atlas": 55}, [_o("craft", {"item": "storage_chest", "count": 1})], 2.0],
		["crafting_bed", "A Place to Sleep", "Craft a bed.", {"atlas": 57}, [_o("craft", {"item": "bed", "count": 1})], 2.5],
		["crafting_house", "House Kit", "Craft a house kit.", {"atlas": 56}, [_o("craft", {"item": "house_kit", "count": 1})], 4.0],
		["crafting_house_2", "Room to Grow", "Enlarge a house to the second tier.", {"atlas": 56}, [_o("house_tier", {"count": 2})], 7.0],
		["crafting_house_3", "Lord of the Manor", "Enlarge a house into a manor.", {"atlas": 56}, [_o("house_tier", {"count": 3})], 11.0],
	])
	_by_id["crafting_house_3"]["big"] = true
	var furniture := ["rug", "bookshelf", "potted_plant", "dining_table", "chair", "candles", "wall_banner", "barrel", "crate", "stone_statue", "brazier", "fence", "lantern_post"]
	var hub := _q("crafting_furnish", "Making It Home", "Craft any piece of furniture.", {"item": "rug"}, ["crafting_house"], [_o("craft_any", {"items": furniture, "count": 1, "label": "Craft furniture"})], 3.0)
	for item: String in furniture:
		_q("crafting_" + item, ItemDB.ITEMS[item]["name"], "Craft a %s." % ItemDB.ITEMS[item]["name"].to_lower(), {"item": item}, [hub], [_o("craft", {"item": item, "count": 1})], 2.5)
	var floors := ["floor_plank", "floor_stone", "floor_cobble", "floor_moss", "floor_sand", "floor_snow"]
	var floor_hub := _q("crafting_floors", "Underfoot", "Craft floor tiles.", {"item": "floor_stone"}, ["crafting_house"], [_o("craft_any", {"items": floors, "count": 1, "label": "Craft floor tiles"})], 2.5)
	for item: String in floors:
		_q("crafting_" + item, ItemDB.ITEMS[item]["name"], "Craft %s." % ItemDB.ITEMS[item]["name"].to_lower(), {"item": item}, [floor_hub], [_o("craft", {"item": item, "count": 1})], 2.0)
	_chain(root, [
		["crafting_10", "Handy", "Craft 10 things.", {"atlas": 54}, [_stat("crafted", 10, "Craft things")], 2.0],
		["crafting_100", "Artisan", "Craft 100 things.", {"atlas": 54}, [_stat("crafted", 100, "Craft things")], 5.0],
		["crafting_500", "Master Artisan", "Craft 500 things.", {"atlas": 54}, [_stat("crafted", 500, "Craft things")], 10.0],
	])
	for profession: String in ["building", "blacksmithing"]:
		var name: String = Professions.NAMES[profession]
		_chain(root, [
			["crafting_%s_10" % profession, "%s 10" % name, "Reach %s 10." % name.to_lower(), {"atlas": Professions.ICONS[profession]}, [_o("profession", {"profession": profession, "level": 10})], 4.0],
			["crafting_%s_25" % profession, "%s 25" % name, "Reach %s 25." % name.to_lower(), {"atlas": Professions.ICONS[profession]}, [_o("profession", {"profession": profession, "level": 25})], 7.0],
			["crafting_%s_50" % profession, "%s 50" % name, "Reach %s 50." % name.to_lower(), {"atlas": Professions.ICONS[profession]}, [_o("profession", {"profession": profession, "level": 50})], 11.0],
		])
	_chain(root, [
		["crafting_torches", "Light the Way", "Craft torches.", {"item": "torch"}, [_o("craft", {"item": "torch", "count": 5})], 1.5],
		["crafting_bronze", "Bronze Age", "Smelt bronze.", {"atlas": 46}, [_o("craft", {"item": "bronze_ingot", "count": 1})], 3.0],
		["crafting_boat", "Shipwright", "Build a rowboat.", {"item": "rowboat"}, [_o("craft", {"item": "rowboat", "count": 1})], 5.0],
	])


static func _mining() -> void:
	_chapter = "mining"
	var root := _q("mining_root", "Break Stone", "Mine stone.", {"atlas": 42}, ["main_tools"], [_o("gather", {"resource": "stone", "count": 5})], 1.0, [], true)
	var last := root
	for ore: String in ["copper", "tin", "iron", "silver", "gold", "mithril", "obsidian", "adamantite", "void_crystal", "heartstone"]:
		var item: String = GatherDB.RESOURCES[ore]["item"]
		var name: String = ItemDB.ITEMS[item]["name"]
		last = _q("mining_%s_10" % ore, name, "Mine 10 %s." % name.to_lower(), {"item": item}, [last], [_o("gather", {"resource": ore, "count": 10})], 1.5 + GatherDB.RESOURCES[ore]["level"] / 10.0)
		_q("mining_%s_100" % ore, name + " Seam", "Mine 100 %s." % name.to_lower(), {"item": item}, [last], [_o("gather", {"resource": ore, "count": 100})], 3.0 + GatherDB.RESOURCES[ore]["level"] / 7.0)
	var wood := _q("mining_wood_root", "Timber", "Fell a tree.", {"atlas": 43}, [root], [_o("gather", {"resource": "oak", "count": 5})], 1.0)
	last = wood
	for tree: String in ["pine", "ancient_tree", "spirit_tree"]:
		var item: String = GatherDB.RESOURCES[tree]["item"]
		last = _q("mining_%s" % tree, ItemDB.ITEMS[item]["name"], "Gather 10 %s." % ItemDB.ITEMS[item]["name"].to_lower(), {"item": item}, [last], [_o("gather", {"resource": tree, "count": 10})], 2.0 + GatherDB.RESOURCES[tree]["level"] / 10.0)
	_q("mining_oak_200", "Lumberjack", "Fell 200 oaks.", {"atlas": 50}, [wood], [_o("gather", {"resource": "oak", "count": 200})], 6.0)
	for profession: String in ["mining", "woodcutting"]:
		var name: String = Professions.NAMES[profession]
		_chain(root if profession == "mining" else wood, [
			["mining_prof_%s_10" % profession, "%s 10" % name, "Reach %s 10." % name.to_lower(), {"atlas": Professions.ICONS[profession]}, [_o("profession", {"profession": profession, "level": 10})], 3.5],
			["mining_prof_%s_25" % profession, "%s 25" % name, "Reach %s 25." % name.to_lower(), {"atlas": Professions.ICONS[profession]}, [_o("profession", {"profession": profession, "level": 25})], 6.5],
			["mining_prof_%s_50" % profession, "%s 50" % name, "Reach %s 50." % name.to_lower(), {"atlas": Professions.ICONS[profession]}, [_o("profession", {"profession": profession, "level": 50})], 10.0],
			["mining_prof_%s_75" % profession, "%s 75" % name, "Reach %s 75." % name.to_lower(), {"atlas": Professions.ICONS[profession]}, [_o("profession", {"profession": profession, "level": 75})], 14.0],
		])
	_chain(root, [
		["mining_gem_1", "Something Glints", "Find a gem in an ore vein.", {"atlas": 59}, [_stat("gems_found", 1, "Find gems")], 3.0],
		["mining_gem_25", "Prospector", "Find 25 gems in ore veins.", {"atlas": 59}, [_stat("gems_found", 25, "Find gems")], 8.0],
	])
	_chain(root, [
		["mining_gather_100", "Busy Hands", "Gather 100 times.", {"atlas": 49}, [_stat("gathered", 100, "Gather")], 3.0],
		["mining_gather_1000", "Tireless", "Gather 1000 times.", {"atlas": 49}, [_stat("gathered", 1000, "Gather")], 9.0],
	])


static func _farming() -> void:
	_chapter = "farming"
	var root := _q("farming_root", "Seeds of Hope", "Place a farm plot outdoors.", {"item": "farm_plot"}, ["main_roof"], [_o("place", {"kind": "plot", "count": 1})], 1.5, [["wheat_seeds", 5], ["carrot_seeds", 3]], true)
	var last := root
	for crop: String in Crops.CROPS:
		var data: Dictionary = Crops.CROPS[crop]
		_chain(root, [
			["farming_%s_1" % crop, data["name"], "Harvest %s." % data["name"].to_lower(), {"item": data["item"]}, [_stat("harvest_" + crop, 1, "Harvest " + data["name"].to_lower())], 2.0 + data["days"]],
			["farming_%s_25" % crop, data["name"] + " Harvest", "Harvest 25 crops of %s." % data["name"].to_lower(), {"item": data["item"]}, [_stat("harvest_" + crop, 25, "Harvest " + data["name"].to_lower())], 4.0 + data["days"] * 2.0],
		])
	_chain(root, [
		["farming_scarecrow", "Keeping Watch", "Place a scarecrow.", {"item": "scarecrow"}, [_o("place", {"kind": "scarecrow", "count": 1})], 2.0],
		["farming_plots_6", "A Proper Farm", "Have 6 farm plots.", {"item": "farm_plot"}, [_o("place", {"kind": "plot", "count": 6})], 3.5],
		["farming_harvest_50", "Green Thumb", "Harvest 50 crops.", {"atlas": 44}, [_stat("harvests", 50, "Harvest crops")], 6.0],
		["farming_harvest_250", "Breadbasket", "Harvest 250 crops.", {"atlas": 44}, [_stat("harvests", 250, "Harvest crops")], 10.0],
		["farming_farmer", "Hired Hands", "Have a farmer settle at your home.", {"atlas": 44}, [_o("settler", {"role": "farmer"})], 7.0],
	])
	for dish: String in ["bread", "baked_potato", "carrot_stew", "frostberry_tart", "pumpkin_pie"]:
		_q("farming_cook_" + dish, ItemDB.ITEMS[dish]["name"], "Cook %s." % ItemDB.ITEMS[dish]["name"].to_lower(), {"item": dish}, [root], [_o("craft", {"item": dish, "count": 1})], 2.5)
	var herbs := _q("farming_herbs", "Herbalist", "Gather herbs.", {"atlas": 44}, [root], [_stat("gathered", 10, "Gather")], 1.5)
	for herb: String in ["healing_herb", "poison_mushroom", "mana_flower", "saltweed", "desert_aloe", "frost_lily", "glowshroom", "bloodcap", "emberbloom", "rare_root", "void_bloom", "berry_bush", "thornberry_bush"]:
		var item: String = GatherDB.RESOURCES[herb]["item"]
		_q("farming_herb_" + herb, ItemDB.ITEMS[item]["name"], "Gather %s." % ItemDB.ITEMS[item]["name"].to_lower(), {"item": item}, [herbs], [_o("gather", {"resource": herb, "count": 5})], 1.5 + GatherDB.RESOURCES[herb]["level"] / 10.0)
	_chain(herbs, [
		["farming_herbalism_25", "Herbalism 25", "Reach herbalism 25.", {"atlas": 44}, [_o("profession", {"profession": "herbalism", "level": 25})], 6.0],
		["farming_herbalism_50", "Herbalism 50", "Reach herbalism 50.", {"atlas": 44}, [_o("profession", {"profession": "herbalism", "level": 50})], 10.0],
	])


static func _fishing() -> void:
	_chapter = "fishing"
	var root := _q("fishing_root", "Gone Fishing", "Catch a fish from a fishing spot in the shallows.", {"atlas": 51}, ["main_wild"], [_stat("fish", 1, "Catch fish")], 1.5, [], true)
	var last := root
	for fish: Array in GatherDB.FISH:
		var item: String = fish[0]
		var name: String = ItemDB.ITEMS[item]["name"]
		last = _q("fishing_%s_1" % item, name, "Catch a %s." % name.to_lower(), {"item": item}, [last], [_o("caught", {"item": item, "count": 1})], 1.5 + fish[1] / 8.0)
		_q("fishing_%s_20" % item, name + " Run", "Catch 20 %s." % name.to_lower(), {"item": item}, [last], [_o("caught", {"item": item, "count": 20})], 3.0 + fish[1] / 6.0)
	_by_id["fishing_golden_carp_1"]["big"] = true
	_chain(root, [
		["fishing_25", "Patient", "Catch 25 fish.", {"atlas": 45}, [_stat("fish", 25, "Catch fish")], 3.0],
		["fishing_200", "Angler", "Catch 200 fish.", {"atlas": 45}, [_stat("fish", 200, "Catch fish")], 7.0],
		["fishing_1000", "Lord of the Lakes", "Catch 1000 fish.", {"atlas": 45}, [_stat("fish", 1000, "Catch fish")], 12.0],
	])
	_chain(root, [
		["fishing_prof_10", "Fishing 10", "Reach fishing 10.", {"atlas": 51}, [_o("profession", {"profession": "fishing", "level": 10})], 3.0],
		["fishing_prof_25", "Fishing 25", "Reach fishing 25.", {"atlas": 51}, [_o("profession", {"profession": "fishing", "level": 25})], 6.0],
		["fishing_prof_50", "Fishing 50", "Reach fishing 50.", {"atlas": 51}, [_o("profession", {"profession": "fishing", "level": 50})], 10.0],
		["fishing_prof_75", "Fishing 75", "Reach fishing 75.", {"atlas": 51}, [_o("profession", {"profession": "fishing", "level": 75})], 14.0],
	])
	for dish: String in ["grilled_minnow", "trout_stew", "pike_chowder", "salmon_steak", "eel_pie", "glowfin_soup", "golden_platter"]:
		_q("fishing_cook_" + dish, ItemDB.ITEMS[dish]["name"], "Cook %s." % ItemDB.ITEMS[dish]["name"].to_lower(), {"item": dish}, [root], [_o("craft", {"item": dish, "count": 1})], 2.0 + ItemDB.ITEMS[dish]["material_rarity"] * 2.0)
	_chain(root, [
		["fishing_boat", "Set Sail", "Launch a rowboat.", {"item": "rowboat"}, [_stat("boats", 1, "Launch a boat")], 4.0],
		["fishing_island", "Landfall", "Set foot on an island.", {"atlas": 43}, [_stat("islands", 1, "Reach an island")], 6.0],
	])


static func _hunting() -> void:
	_chapter = "hunting"
	var root := _q("hunting_root", "The Hunter's Way", "Hunt a wild animal: deer, hares, pigs and more roam by day.", {"monster": "deer"}, ["main_awakening"],
		[_o("kill_wild", {"count": 1})], 1.0, [], true)
	var animals := {"deer": ["roast_venison", "jerky"], "wild_hare": ["hare_stew"], "wild_pig": ["grilled_pork", "pork_pie"], "mountain_goat": ["goat_skewer"],
		"pheasant": ["roast_pheasant"], "desert_lizard": ["spiced_lizard"], "snow_fox": [], "shore_crab": ["crab_cakes"], "marsh_toad": ["fried_toad_legs"]}
	for animal: String in animals:
		var name: String = EnemyDB.ENEMIES[animal]["name"]
		var first := _q("hunting_%s_5" % animal, name, "Hunt 5 %s." % name.to_lower(), {"monster": animal}, [root], [_o("kill", {"monster": animal, "count": 5})], 1.5)
		_q("hunting_%s_40" % animal, name + " Stalker", "Hunt 40 %s." % name.to_lower(), {"monster": animal}, [first], [_o("kill", {"monster": animal, "count": 40})], 4.0)
		for dish: String in animals[animal]:
			_q("hunting_cook_" + dish, ItemDB.ITEMS[dish]["name"], "Cook %s." % ItemDB.ITEMS[dish]["name"].to_lower(), {"item": dish}, [first], [_o("craft", {"item": dish, "count": 1})], 2.5)
	_q("hunting_feast", "Hunter's Feast", "Cook a hunter's feast.", {"item": "hunters_feast"}, ["hunting_cook_roast_venison", "hunting_cook_grilled_pork", "hunting_cook_roast_pheasant"],
		[_o("craft", {"item": "hunters_feast", "count": 1})], 9.0, [], true)
	var leather := _chain(root, [
		["hunting_leather", "Tanner", "Tan hides into leather.", {"item": "leather"}, [_o("craft_any", {"items": ["leather", "leather_from_pig", "leather_from_hare"], "count": 1, "label": "Tan leather"})], 2.0],
		["hunting_fur", "Fur Mantle", "Make a fur mantle from snow fox pelts.", {"item": "fur_cloak"}, [_o("craft", {"item": "fur_cloak", "count": 1})], 6.0],
	])
	_chain(root, [
		["hunting_cooking_10", "Cook", "Reach cooking 10.", {"atlas": 48}, [_o("profession", {"profession": "cooking", "level": 10})], 3.0],
		["hunting_cooking_25", "Chef", "Reach cooking 25.", {"atlas": 48}, [_o("profession", {"profession": "cooking", "level": 25})], 6.0],
		["hunting_cooking_50", "Master Chef", "Reach cooking 50.", {"atlas": 48}, [_o("profession", {"profession": "cooking", "level": 50})], 10.0],
	])
	_chain(root, [
		["hunting_meals_10", "Hearty Appetite", "Eat 10 meals.", {"atlas": 48}, [_stat("meals", 10, "Eat meals")], 2.0],
		["hunting_meals_100", "Gourmand", "Eat 100 meals.", {"atlas": 48}, [_stat("meals", 100, "Eat meals")], 6.0],
	])
	var pets := _chain(root, [
		["hunting_treat", "A Tasty Treat", "Cook a taming treat.", {"item": "taming_treat"}, [_o("craft", {"item": "taming_treat", "count": 1})], 2.0],
		["hunting_pet", "A Friend", "Tame a pet.", {"atlas": 39}, [_stat("pets", 1, "Tame pets")], 3.0],
		["hunting_pet_10", "Growing Up", "Raise a pet to level 10.", {"atlas": 39}, [_o("pet_level", {"count": 10})], 5.0],
		["hunting_pet_25", "Loyal Companion", "Raise a pet to level 25.", {"atlas": 39}, [_o("pet_level", {"count": 25})], 8.0],
		["hunting_pets_4", "Menagerie", "Tame 4 pets.", {"atlas": 39}, [_stat("pets", 4, "Tame pets")], 7.0],
	])
	var ride := _q("hunting_ride", "In the Saddle", "Ride a mount. Whistles are sold by village merchants.", {"item": "horse_whistle"}, [root], [_stat("mounts", 1, "Ride a mount")], 4.0)
	for mount: String in Mount.MOUNTS:
		var item := mount + "_whistle"
		_q("hunting_mount_" + mount, Mount.MOUNTS[mount]["name"], "Own a %s whistle." % Mount.MOUNTS[mount]["name"].to_lower(), {"item": item}, [ride], [_o("own", {"item": item})], 3.0 + Mount.MOUNTS[mount]["speed"] * 2.0)


static func _exploration() -> void:
	_chapter = "exploration"
	var root := _q("exploration_root", "Wanderlust", "Discover two kinds of land.", {"atlas": 9}, ["main_wild"], [_stat("biomes", 2, "Discover lands")], 1.5, [], true)
	var natural := ["Withered Fields", "Gloomwood", "Mudflats", "Ashen Waste", "Rotmire", "Mountains", "High Peaks", "Frostfields", "Frostpine", "Pale Flats",
		"Thornheath", "Crimson Moor", "Sporewood", "Tar Mire", "Bone Desert", "Cinderlands", "Voidscar"]
	var last := root
	for index in natural.size():
		var biome: String = natural[index]
		var parent := root if index % 3 == 0 else last
		last = _q("exploration_" + biome.to_snake_case(), biome, "Set foot in the %s." % biome, {"atlas": 9}, [parent], [_o("biome", {"name": biome})], 2.0 + index * 0.3)
	_chain(root, [
		["exploration_lands_8", "Wayfarer", "Discover 8 lands.", {"atlas": 9}, [_stat("biomes", 8, "Discover lands")], 5.0],
		["exploration_lands_14", "Cartographer", "Discover 14 lands.", {"atlas": 9}, [_stat("biomes", 14, "Discover lands")], 9.0],
	])
	for tier: Array in [["waystones", [1, 5, 15, 30], "Waystone", "Wake %d waystones."], ["obelisks", [1, 5, 10], "Obelisk", "Read %d obelisks."],
			["villages", [1, 5, 15], "Village", "Visit %d villages."], ["caves", [1, 10, 30], "Caves", "Enter %d caves."],
			["dungeons", [1, 5, 15], "Crypts", "Clear %d crypts."], ["portals", [1, 5, 15], "Void Portals", "Clear %d void portals."],
			["treasure", [1, 5, 15], "Buried Treasure", "Dig up %d buried caches."], ["notes", [1, 10], "Lost Words", "Read %d notes in abandoned camps."]]:
		var parent := root
		for goal: int in tier[1]:
			parent = _q("exploration_%s_%d" % [tier[0], goal], "%s %d" % [tier[2], goal], tier[3] % goal, {"atlas": {"waystones": 12, "obelisks": 12, "villages": 56, "caves": 42, "dungeons": 55, "portals": 16, "treasure": 53, "notes": 53}[tier[0]]},
				[parent], [_stat(tier[0], goal, tier[3].replace("%d ", "").capitalize())], 2.0 + goal * 0.25 + (2.0 if goal > 1 else 0.0))
	var caves := _q("exploration_cave_themes", "Under the World", "Explore the different kinds of cave.", {"atlas": 42}, ["exploration_caves_1"], [_stat("caves", 3, "Enter caves")], 3.0)
	for theme: String in Instances.CAVE_THEMES:
		_q("exploration_cave_" + theme, Instances.CAVE_THEMES[theme]["title"], "Explore a %s." % (Instances.CAVE_THEMES[theme]["title"] as String).to_lower(), {"atlas": 42}, [caves], [_stat("cave_" + theme, 1, "Explore one")], 3.5)


static func _raids() -> void:
	_chapter = "raids"
	var root := _q("raids_root", "Hold the Line", "Build a palisade to defend your home.", {"item": "palisade_wall"}, ["main_roof"], [_o("place", {"kind": "palisade", "count": 1})], 2.0, [], true)
	_chain(root, [
		["raids_spikes", "Sharp Welcome", "Place 3 spike traps.", {"item": "spike_trap"}, [_o("place", {"kind": "spikes", "count": 3})], 3.0],
		["raids_ballista", "Bolt Thrower", "Place a ballista.", {"item": "ballista"}, [_o("place", {"kind": "ballista", "count": 1})], 5.0],
		["raids_walls", "Fortified", "Place 20 palisades.", {"item": "palisade_wall"}, [_o("place", {"kind": "palisade", "count": 20})], 6.0],
	])
	_chain(root, [
		["raids_1", "Defender", "Repel a raid on your home.", {"monster": "husk"}, [_stat("raids", 1, "Repel raids")], 6.0],
		["raids_5", "Bulwark", "Repel 5 raids.", {"monster": "crimson_fiend"}, [_stat("raids", 5, "Repel raids")], 9.0],
		["raids_15", "Unassailable", "Repel 15 raids.", {"monster": "void_stalker"}, [_stat("raids", 15, "Repel raids")], 13.0],
	])
	_chain(root, [
		["raids_blood_1", "Red Night", "Live through a blood moon.", {"atlas": 36}, [_stat("blood_moons", 1, "Survive blood moons")], 5.0],
		["raids_blood_5", "Moon-Hardened", "Live through 5 blood moons.", {"atlas": 36}, [_stat("blood_moons", 5, "Survive blood moons")], 9.0],
	])
	var settlers := _q("raids_settlers", "Neighbours", "Have a settler move to your home.", {"atlas": 56}, [root], [_stat("settlers", 1, "Settlers")], 4.0)
	for role: String in Settlers.ROLES:
		_q("raids_settler_" + role, Settlers.ROLES[role]["title"], "Have a %s settle at your home." % Settlers.ROLES[role]["title"].to_lower(), {"atlas": 56}, [settlers], [_o("settler", {"role": role})], 5.0)
	var bounties := _chain(root, [
		["raids_bounty_1", "Wanted", "Collect a bounty.", {"atlas": 53}, [_stat("bounties", 1, "Collect bounties")], 4.0],
		["raids_bounty_10", "Bounty Hunter", "Collect 10 bounties.", {"atlas": 53}, [_stat("bounties", 10, "Collect bounties")], 8.0],
		["raids_bounty_30", "Headsman", "Collect 30 bounties.", {"atlas": 53}, [_stat("bounties", 30, "Collect bounties")], 12.0],
	])
	var bosses := _q("raids_boss_root", "Thrones of the World", "Defeat a world boss.", {"monster": "ash_wraith"}, [root], [_stat("bosses", 1, "Defeat world bosses")], 9.0, [], true)
	for boss: String in BossDB.BOSSES:
		var data: Dictionary = BossDB.BOSSES[boss]
		var first := _q("raids_boss_" + boss, data["name"], "Defeat %s." % data["name"], {"monster": data["monster"]}, [bosses], [_o("boss", {"boss": boss, "count": 1})], 10.0)
		_q("raids_boss_%s_5" % boss, data["name"] + ", Again", "Defeat %s five times." % data["name"], {"monster": data["monster"]}, [first], [_o("boss", {"boss": boss, "count": 5})], 13.0)


static func _side() -> void:
	_chapter = "side"
	var root := _q("side_root", "Small Talk", "Talk to someone in a village.", {"atlas": 53}, ["main_village"], [_stat("talks", 1, "Talk to people")], 1.0, [], true)
	_chain(root, [
		["side_buy_10", "Good Customer", "Buy 10 things from merchants.", {"atlas": 17}, [_stat("purchases", 10, "Buy")], 2.5],
		["side_sell_25", "Trader", "Sell 25 times to merchants.", {"atlas": 17}, [_stat("sales", 25, "Sell")], 3.5],
		["side_gold_1000", "Coin Purse", "Hold 1000 gold.", {"atlas": 17}, [_o("gold", {"count": 1000})], 4.0],
		["side_gold_10000", "Strongbox", "Hold 10,000 gold.", {"atlas": 17}, [_o("gold", {"count": 10000})], 8.0],
		["side_gold_100000", "Dragon's Hoard", "Hold 100,000 gold.", {"atlas": 17}, [_o("gold", {"count": 100000})], 13.0],
	])
	_chain(root, [
		["side_warden_5", "Odd Jobs", "Finish 5 warden jobs.", {"atlas": 53}, [_o("wardens", {"count": 5})], 3.5],
		["side_warden_25", "Reliable", "Finish 25 warden jobs.", {"atlas": 53}, [_o("wardens", {"count": 25})], 7.0],
		["side_warden_100", "The Warden's Right Hand", "Finish 100 warden jobs.", {"atlas": 53}, [_o("wardens", {"count": 100})], 12.0],
	])
	_chain(root, [
		["side_achieve_5", "Noteworthy", "Earn 5 achievements.", {"atlas": 41}, [_o("achievements", {"count": 5})], 3.0],
		["side_achieve_15", "Renowned", "Earn 15 achievements.", {"atlas": 41}, [_o("achievements", {"count": 15})], 7.0],
		["side_achieve_30", "Legendary", "Earn 30 achievements.", {"atlas": 41}, [_o("achievements", {"count": 30})], 12.0],
	])
	_chain(root, [
		["side_potions_10", "Bottoms Up", "Drink 10 potions.", {"atlas": 47}, [_stat("potions", 10, "Drink potions")], 2.0],
		["side_notes_3", "Reader", "Read 3 notes in abandoned camps.", {"atlas": 53}, [_stat("notes", 3, "Read notes")], 3.0],
		["side_merchant", "The Wanderer's Wares", "Talk to a wandering merchant out in the wilds.", {"atlas": 17}, [_stat("talk_merchant", 3, "Visit merchants")], 3.0],
	])
