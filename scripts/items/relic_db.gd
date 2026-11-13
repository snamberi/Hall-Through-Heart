class_name RelicDB
extends RefCounted
## Relics: rare treasures won from bosses. A relic has no level; its
## rarity sets how strong its boons are (see RARITY_POWER). Each also
## grants one ability, used with the relic key (G) while it is the
## relic in focus. Up to 15 wait in the relic bag; one can be worn,
## more with a good belt (see Relics).

## How much stronger each rarity makes a relic's boons: common .. mythic.
const RARITY_POWER: Array[float] = [1.0, 1.2, 1.45, 1.75, 2.1, 2.6]
const BAG_SIZE := 15

## id -> {"name", "icon" (item icon), "text", "mods" (at common), "ability":
## {"id", "name", "text", "cooldown"}}.
const RELICS := {
	"hearthstone": {"name": "Hearthstone Shard", "icon": 102, "text": "A chip of a hearth that never went cold.",
		"mods": {"physical_damage": {"percent": 0.08}},
		"ability": {"id": "homeward", "name": "Homeward", "text": "Step home: return to where you last rested.", "cooldown": 120.0}},
	"tidewalker": {"name": "Tidewalker's Scale", "icon": 103, "text": "Still wet, years from any sea.",
		"mods": {"move_speed": {"percent": 0.06}, "health_regen": {"flat": 1.0}},
		"ability": {"id": "tidestride", "name": "Tidestride", "text": "For 12 seconds swim as fast as you walk and dodge in water, starting with a surge.", "cooldown": 45.0}},
	"ember_heart": {"name": "Ember Heart", "icon": 104, "text": "It beats, slowly, and it is warm.",
		"mods": {"fire_damage": {"flat": 4.0}, "physical_damage": {"percent": 0.04}},
		"ability": {"id": "flare", "name": "Flare", "text": "A burst of fire round you: heavy damage and burning.", "cooldown": 25.0}},
	"frostbound_eye": {"name": "Frostbound Eye", "icon": 105, "text": "It does not blink. Nothing near it moves much either.",
		"mods": {"critical_chance": {"flat": 0.04}, "critical_damage": {"percent": 0.1}},
		"ability": {"id": "stillness", "name": "Stillness", "text": "Freeze every enemy near you for about 3 seconds.", "cooldown": 35.0}},
	"bloodvine": {"name": "Bloodvine Locket", "icon": 106, "text": "A vine of red glass curls round a lock of hair.",
		"mods": {"life_steal": {"flat": 0.025}, "max_health": {"percent": 0.04}},
		"ability": {"id": "transfusion", "name": "Transfusion", "text": "Heal a third of your health at once.", "cooldown": 60.0}},
	"gale_feather": {"name": "Gale Feather", "icon": 107, "text": "It will not lie still on a table.",
		"mods": {"attack_speed": {"percent": 0.06}},
		"ability": {"id": "gust", "name": "Gust", "text": "Ride the wind: a long dash that cannot be hit.", "cooldown": 12.0}},
	"ironroot": {"name": "Ironroot Seed", "icon": 108, "text": "Planted, it would grow an iron oak. Carried, it grows you.",
		"mods": {"armor": {"percent": 0.1}, "max_health": {"percent": 0.06}},
		"ability": {"id": "bulwark", "name": "Bulwark", "text": "For 6 seconds take about half the damage (even less with rarer relics).", "cooldown": 40.0}},
	"void_lens": {"name": "Void Lens", "icon": 109, "text": "Through it, the world is thinner.",
		"mods": {"magic_power": {"percent": 0.1}, "max_mana": {"percent": 0.08}},
		"ability": {"id": "blink", "name": "Blink", "text": "Vanish and reappear where you point, up to a short way off.", "cooldown": 10.0}},
	"gilded_idol": {"name": "Gilded Idol", "icon": 110, "text": "Someone prayed to it for money. It worked.",
		"mods": {"gold_find": {"flat": 0.2}, "magic_find": {"flat": 0.1}},
		"ability": {"id": "fortune", "name": "Fortune", "text": "For 45 seconds enemies drop twice the gold.", "cooldown": 120.0}},
	"stormheart": {"name": "Stormheart Coil", "icon": 111, "text": "Copper wound round a stone that hums before rain.",
		"mods": {"physical_damage": {"percent": 0.05}, "attack_speed": {"percent": 0.03}},
		"ability": {"id": "thunder_call", "name": "Thunder Call", "text": "Lightning strikes up to five enemies near you.", "cooldown": 20.0}},
	"moonlit_bell": {"name": "Moonlit Bell", "icon": 112, "text": "It rings only for those who should not hear it.",
		"mods": {"dodge_efficiency": {"flat": 0.12}, "move_speed": {"percent": 0.03}},
		"ability": {"id": "night_veil", "name": "Night Veil", "text": "For 6 seconds enemies lose sight of you, and you move faster.", "cooldown": 50.0}},
	"grave_lantern": {"name": "Grave Lantern", "icon": 113, "text": "Its light is cold, and the dead come to it.",
		"mods": {"shadow_damage": {"flat": 3.0}, "critical_damage": {"percent": 0.08}, "magic_find": {"flat": 0.05}},
		"ability": {"id": "soul_harvest", "name": "Soul Harvest", "text": "Draw the life out of every enemy near you, healing for each.", "cooldown": 30.0}},
}


## A relic's boons at a rarity.
static func mods_at(relic_id: String, rarity: int) -> Dictionary:
	var power: float = RARITY_POWER[clampi(rarity, 0, RARITY_POWER.size() - 1)]
	var result := {}
	var base: Dictionary = RELICS[relic_id]["mods"]
	for stat: String in base:
		result[stat] = {}
		for kind: String in base[stat]:
			result[stat][kind] = float(base[stat][kind]) * power
	return result


## A new relic item of a kind (random if ""), at a rarity.
static func make(relic_id: String = "", rarity: int = 2) -> Item:
	if relic_id == "":
		var ids := RELICS.keys()
		relic_id = ids[randi() % ids.size()]
	var item := Item.create("relic_" + relic_id)
	item.rarity = clampi(rarity, 0, 5)
	return item


## Rarity for a relic won from a foe of this rank.
static func roll_rarity(rank: String, magic_find: float) -> int:
	var bonus := 4.0 if rank == "boss" else 2.0
	return clampi(maxi(LootGenerator.roll_rarity(magic_find, bonus), 2 if rank == "boss" else 1), 0, 5)
