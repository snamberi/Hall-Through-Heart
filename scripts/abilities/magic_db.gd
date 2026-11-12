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


static func spells(school: String) -> Array:
	return SCHOOLS.get(school, {}).get("spells", ["", "", "", ""])


static func school_of(spell_id: String) -> String:
	return AbilityDB.ABILITIES.get(spell_id, {}).get("school", "")
