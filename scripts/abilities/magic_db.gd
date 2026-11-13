class_name MagicDB
extends RefCounted
## Schools of magic. Each has four spells (abilities with "school", kept in
## AbilityDB). A school is taken up at the Altar of Magic, which stands
## about ALTAR_DISTANCE tiles from where the world begins; with a magic
## weapon in the magic slot (slot 1) in hand, the ability keys cast the
## school's four spells instead of the usual abilities. Spells unlock by
## character level and rank up with it.

const ALTAR_DISTANCE := 500.0
const SCHOOLS := {
	"fire": {"name": "Pyromancy", "short": "Fire", "color": Color("f08a2e"), "icon": 18,
		"text": "Burning bolts, rings of flame, falling stars and a cloak of fire.",
		"spells": ["spell_fire_bolt", "spell_flame_ring", "spell_meteor", "spell_inferno_cloak"]},
	"lightning": {"name": "Stormcalling", "short": "Lightning", "color": Color("8ad0ff"), "icon": 37,
		"text": "Quick sparks, lightning that leaps between foes, thunder and a storm-fast rush.",
		"spells": ["spell_spark", "spell_chain_lightning", "spell_thunderclap", "spell_storm_rush"]},
	"dark": {"name": "Shadowcraft", "short": "Dark", "color": Color("9a6cf0"), "icon": 20,
		"text": "Rotting shadow, bursts of the dark, a rift that drags at the living, and a pact that trades safety for power.",
		"spells": ["spell_shadow_bolt", "spell_umbral_burst", "spell_void_rift", "spell_dark_pact"]},
	"light": {"name": "Radiance", "short": "Light", "color": Color("ffe8a0"), "icon": 63,
		"text": "Piercing lances of light, a burst that heals, judgement from above, and a blessing.",
		"spells": ["spell_holy_lance", "spell_radiant_burst", "spell_smite", "spell_blessing"]},
	"frost": {"name": "Cryomancy", "short": "Frost", "color": Color("a8e0ff"), "icon": 19,
		"text": "Shards and rings of ice that slow, a spike from below, and armour of frost.",
		"spells": ["spell_ice_shard", "spell_frost_ring", "spell_glacial_spike", "spell_ice_armor"]},
}


## Mana each bolt from the hand costs.
const BOLT_MANA := 3.0


## How the hand attacks with a school of magic: a bolt in the school's colour
## that burns, chills, pierces or drains by its kind.
static func bolt_profile(school: String) -> Dictionary:
	var info: Dictionary = SCHOOLS.get(school, SCHOOLS["fire"])
	var projectile := {"sprite": 1, "speed": 620.0, "radius": 12.0, "range": 470.0, "color": info["color"], "knockback": 160.0}
	match school:
		"fire":
			projectile["status"] = {"status": "burn", "duration": 2.5, "power": 0.25}
		"frost":
			projectile["status"] = {"status": "chill", "duration": 2.0, "power": 0.4}
		"lightning":
			projectile["pierce"] = true
			projectile["speed"] = 820.0
		"dark":
			projectile["status"] = {"status": "poison", "duration": 3.0, "power": 0.25}
		"light":
			projectile["explode"] = 50.0
	return {"type": "staves", "range": 470.0, "arc": 0.0, "cooldown": 0.45, "knockback": 160.0, "magic": true, "projectile": projectile}


static func spells(school: String) -> Array:
	return SCHOOLS.get(school, {}).get("spells", ["", "", "", ""])


static func school_of(spell_id: String) -> String:
	return AbilityDB.ABILITIES.get(spell_id, {}).get("school", "")
