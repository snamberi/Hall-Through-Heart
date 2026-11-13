class_name WeaponMoves
extends RefCounted
## Every weapon's own four moves (see AbilityDB, which turns each into an
## ability "wm_<weapon>_<n>"). A move is either a copy of a shared ability
## (its id) or a move of its own. The first two are ready as soon as the
## weapon is in hand; the third opens at mastery 10 and the fourth at 25
## with that kind of weapon.

const UNLOCK: Array[int] = [1, 1, 10, 25]

const FIRE := Color(1.0, 0.55, 0.2)
const FROST := Color(0.6, 0.9, 1.0)
const DARK := Color(0.7, 0.45, 1.0)
const STORM := Color(0.75, 0.9, 1.0)
const HOLY := Color(1.0, 0.92, 0.6)
const BLOOD := Color(1.0, 0.3, 0.4)
const POISON := Color(0.55, 0.95, 0.4)

static var MOVES: Dictionary = _moves()


static func arc(name: String, icon_from: String, damage: float, cooldown: float, degrees: float, reach: float, knockback: float, text: String, extra: Dictionary = {}) -> Dictionary:
	var move := {"name": name, "shape": "arc", "icon_from": icon_from, "damage": damage, "stamina": 12.0 + damage * 5.0, "cooldown": cooldown,
		"arc": degrees, "reach": reach, "knockback": knockback, "text": text}
	move.merge(extra, true)
	return move


static func spin(name: String, icon_from: String, damage: float, cooldown: float, radius: float, hits: int, text: String, extra: Dictionary = {}) -> Dictionary:
	var move := {"name": name, "shape": "spin", "icon_from": icon_from, "damage": damage, "stamina": 18.0 + hits * 4.0, "cooldown": cooldown,
		"radius": radius, "hits": hits, "knockback": 280.0, "text": text}
	move.merge(extra, true)
	return move


static func slam(name: String, icon_from: String, damage: float, cooldown: float, radius: float, distance: float, text: String, extra: Dictionary = {}) -> Dictionary:
	var move := {"name": name, "shape": "slam", "icon_from": icon_from, "damage": damage, "stamina": 24.0, "cooldown": cooldown,
		"radius": radius, "distance": distance, "knockback": 600.0, "text": text}
	move.merge(extra, true)
	return move


static func dash(name: String, icon_from: String, damage: float, cooldown: float, distance: float, text: String, extra: Dictionary = {}) -> Dictionary:
	var move := {"name": name, "shape": "dash", "icon_from": icon_from, "damage": damage, "stamina": 18.0, "cooldown": cooldown,
		"distance": distance, "radius": 46.0, "knockback": 160.0, "text": text}
	move.merge(extra, true)
	return move


static func leap(name: String, icon_from: String, damage: float, cooldown: float, radius: float, distance: float, text: String, extra: Dictionary = {}) -> Dictionary:
	var move := {"name": name, "shape": "leap", "icon_from": icon_from, "damage": damage, "stamina": 28.0, "cooldown": cooldown,
		"radius": radius, "distance": distance, "knockback": 560.0, "text": text}
	move.merge(extra, true)
	return move


static func flurry(name: String, icon_from: String, damage: float, cooldown: float, hits: int, text: String, extra: Dictionary = {}) -> Dictionary:
	var move := {"name": name, "shape": "flurry", "icon_from": icon_from, "damage": damage, "stamina": 16.0 + hits * 2.0, "cooldown": cooldown,
		"hits": hits, "reach": 1.15, "arc": 100.0, "knockback": 80.0, "text": text}
	move.merge(extra, true)
	return move


static func shot(name: String, icon_from: String, damage: float, cooldown: float, count: int, spread: float, text: String, projectile: Dictionary = {}, extra: Dictionary = {}) -> Dictionary:
	var config := {"sprite": 0, "speed": 820.0, "radius": 11.0, "range": 620.0, "knockback": 220.0}
	config.merge(projectile, true)
	var move := {"name": name, "shape": "shot", "icon_from": icon_from, "damage": damage, "stamina": 14.0 + count * 3.0, "cooldown": cooldown,
		"count": count, "spread": spread, "projectile": config, "text": text}
	move.merge(extra, true)
	return move


static func buff(name: String, icon_from: String, cooldown: float, duration: float, mods: Dictionary, color: Color, text: String) -> Dictionary:
	return {"name": name, "shape": "buff", "icon_from": icon_from, "stamina": 18.0, "cooldown": cooldown, "duration": duration, "mods": mods,
		"color": color, "text": text}


static func burn(power: float = 0.3) -> Dictionary:
	return {"status": {"status": "burn", "duration": 3.0, "power": power}, "color": FIRE}


static func chill(power: float = 0.5) -> Dictionary:
	return {"status": {"status": "chill", "duration": 3.0, "power": power}, "color": FROST}


static func bleed(power: float = 0.25) -> Dictionary:
	return {"status": {"status": "bleed", "duration": 4.0, "power": power}, "color": BLOOD}


static func poison(power: float = 0.3) -> Dictionary:
	return {"status": {"status": "poison", "duration": 4.0, "power": power}, "color": POISON}


static func _moves() -> Dictionary:
	var magic := {"mana": 18.0, "stamina": 0.0, "magic": true}
	return {
		"club": [arc("Skull Knock", "palm_strike", 2.2, 4.0, 80.0, 1.1, 700.0, "A crack on the head that leaves the foe dazed.", {"stun": 1.2}),
			spin("Club Spin", "whirlwind", 1.1, 7.0, 80.0, 2, "Swing round twice, battering everything close."),
			"rapid_blows", slam("Pound", "ground_breaker", 2.4, 8.0, 80.0, 50.0, "Bring the club down so hard the ground jumps.")],
		"sword": ["heavy_slash", arc("Riposte", "heavy_slash", 1.8, 3.0, 90.0, 1.2, 300.0, "A quick answering cut that finds the gap."),
			dash("Lunge", "shadow_dash", 1.6, 5.0, 170.0, "Drive forward point-first through whoever is in the way."), "whirlwind"],
		"flame_sword": [arc("Searing Cut", "heavy_slash", 2.0, 3.5, 130.0, 1.25, 400.0, "A wide cut that sets what it touches alight.", burn()),
			spin("Ring of Embers", "frost_nova", 1.3, 8.0, 110.0, 1, "A ring of fire bursts from the blade.", burn(0.4)),
			dash("Flame Trail", "shadow_dash", 1.6, 6.0, 200.0, "Rush through foes, leaving them burning.", burn()),
			slam("Pyre", "meteor", 3.2, 12.0, 120.0, 80.0, "Plunge the blade down and raise a pillar of flame.", burn(0.5))],
		"frost_sword": [arc("Rime Slash", "heavy_slash", 1.9, 3.5, 120.0, 1.25, 350.0, "A cold cut that slows what it touches.", chill()),
			shot("Ice Lance", "piercing_arrow", 1.8, 5.0, 1, 0.0, "Fling a shard of the blade's frost.", {"pierce": true}, chill(0.6)),
			spin("Frozen Circle", "frost_nova", 1.4, 9.0, 120.0, 1, "Frost spreads from your feet, slowing all around.", chill(0.7)),
			"blade_dance"],
		"dark_sword": [arc("Night Cut", "backstab", 2.1, 3.5, 100.0, 1.2, 300.0, "A cut that drinks a little of the life it spills.", {"color": DARK, "heal": 0.03}),
			dash("Shadow Stride", "shadow_step", 1.5, 5.0, 220.0, "Step through the dark and out behind your foes.", {"color": DARK}),
			spin("Umbral Whirl", "whirlwind", 1.3, 8.0, 100.0, 3, "Shadow spins out in three rings.", {"color": DARK}),
			slam("Black Hole", "spell_void_rift", 3.0, 12.0, 120.0, 90.0, "Tear the ground open into the dark.", {"color": DARK})],
		"katana": [arc("Iaido", "execution", 2.6, 4.0, 60.0, 1.4, 250.0, "One draw, one cut, long and true."),
			flurry("Petal Storm", "blade_flurry", 0.6, 6.0, 5, "Five cuts too fast to see, like falling petals."),
			dash("Wind Step", "shadow_dash", 1.8, 5.0, 240.0, "Pass through foes in a blink, cutting as you go."),
			arc("Moon Arc", "heavy_slash", 3.2, 9.0, 200.0, 1.3, 500.0, "A full silver crescent of a cut.")],
		"stormcaller": [arc("Thunder Cut", "storm_blade", 2.0, 3.5, 110.0, 1.2, 400.0, "A cut that cracks with lightning.", {"color": STORM}),
			{"name": "Chain Spark", "shape": "chain", "icon_from": "lightning_chain", "damage": 1.4, "mana": 16.0, "cooldown": 6.0, "targets": 4, "reach": 320.0, "jump": 170.0, "color": STORM, "magic": true, "text": "Lightning leaps from the blade between four foes."},
			dash("Storm Rush", "spell_storm_rush", 1.7, 6.0, 230.0, "Ride the lightning through the crowd.", {"color": STORM}),
			slam("Thunderfall", "spell_thunderclap", 3.0, 11.0, 130.0, 80.0, "Call the storm down on the ground ahead.", {"color": STORM})],
		"greatsword": ["ground_breaker", arc("Overhead", "heavy_slash", 3.0, 5.0, 80.0, 1.3, 800.0, "A slow, enormous chop straight down."),
			spin("Sweep", "cleaving_storm", 1.6, 7.0, 105.0, 1, "One great sweep round you."), "cleaving_storm"],
		"executioner": [arc("Sentence", "execution", 3.4, 6.0, 70.0, 1.3, 600.0, "A headsman's blow, heaviest of all.", bleed(0.3)),
			slam("Scaffold Drop", "earthshatter", 2.8, 9.0, 110.0, 70.0, "Bring the blade down like the drop of a scaffold."),
			buff("Grim Resolve", "battle_cry", 25.0, 8.0, {"physical_damage": {"percent": 0.25}, "critical_damage": {"flat": 0.25}}, BLOOD, "For 8 seconds hit 25% harder and crit for more."),
			spin("Reaping", "bloodbath", 1.8, 10.0, 115.0, 2, "Two great reaping turns.", bleed())],
		"pulsebrand": [arc("Heartbeat Cleave", "heavy_slash", 2.6, 4.5, 140.0, 1.3, 600.0, "A cleave that pulses with stolen life.", {"color": BLOOD, "heal": 0.04}),
			spin("Pulse", "frost_nova", 1.5, 8.0, 130.0, 2, "Two waves of blood-red force beat out from you.", bleed()),
			slam("Rupture", "earthshatter", 3.0, 10.0, 120.0, 80.0, "Burst the ground open like a heart giving out.", bleed(0.35)),
			buff("Second Heart", "iron_skin", 40.0, 10.0, {"life_steal": {"flat": 0.08}, "health_regen": {"flat": 4.0}}, BLOOD, "For 10 seconds heal 8% of the damage you deal and much more over time.")],
		"axe": ["rend", arc("Chop", "rend", 2.2, 3.5, 90.0, 1.15, 450.0, "A plain, heavy chop."),
			spin("Axe Whirl", "whirlwind", 1.2, 7.0, 95.0, 2, "Whirl the axe round you twice."), "leap_slam"],
		"reaver": [arc("Gash", "rend", 2.0, 3.5, 110.0, 1.2, 380.0, "A ragged cut that bleeds freely.", bleed(0.35)),
			leap("Reaver's Leap", "leap_slam", 2.2, 8.0, 95.0, 200.0, "Leap and come down hooks-first.", bleed()),
			flurry("Hacking", "rapid_blows", 0.8, 6.0, 4, "Four savage hacks.", bleed(0.15)), "bloodbath"],
		"bloodthirst": [arc("Thirsting Cut", "rend", 2.2, 3.5, 110.0, 1.2, 400.0, "A cut that heals you a little.", {"heal": 0.04, "color": BLOOD}),
			spin("Blood Fountain", "bloodbath", 1.6, 9.0, 115.0, 2, "Spin, and drink from every wound.", {"heal": 0.06, "color": BLOOD}),
			leap("Frenzy Leap", "leap_slam", 2.4, 8.0, 100.0, 200.0, "Leap upon the nearest victim.", bleed()),
			buff("Bloodlust", "battle_cry", 30.0, 10.0, {"attack_speed": {"percent": 0.25}, "life_steal": {"flat": 0.05}}, BLOOD, "For 10 seconds swing 25% faster and drink 5% of what you deal.")],
		"dagger": ["shadow_dash", flurry("Quick Stabs", "blade_flurry", 0.6, 4.0, 4, "Four quick stabs."),
			arc("Backstab", "backstab", 2.8, 6.0, 60.0, 1.0, 120.0, "A cruel stab that crits more easily.", {"crit": 0.3}), "fan_of_knives"],
		"fang": [arc("Venom Bite", "backstab", 1.8, 3.0, 70.0, 1.0, 120.0, "A stab that leaves venom in the wound.", poison(0.35)),
			shot("Spit Venom", "fan_of_knives", 1.2, 5.0, 3, 24.0, "Flick three darts of venom.", {"speed": 700.0}, poison()),
			dash("Serpent Dart", "shadow_dash", 1.6, 5.0, 210.0, "Dart through foes, biting each.", poison()),
			flurry("Thousand Fangs", "blade_flurry", 0.6, 8.0, 7, "Seven bites in a heartbeat.", poison(0.2))],
		"frostbite": [arc("Frost Prick", "backstab", 1.8, 3.0, 70.0, 1.0, 120.0, "A cold stab that slows.", chill(0.6)),
			shot("Ice Darts", "fan_of_knives", 1.1, 5.0, 4, 30.0, "Throw four darts of ice.", {"speed": 720.0}, chill()),
			dash("Cold Snap", "shadow_dash", 1.6, 5.0, 210.0, "Flash past foes, freezing them in place.", {"stun": 1.0, "color": FROST}),
			spin("Hailstorm", "frost_nova", 1.4, 9.0, 120.0, 2, "A whirling storm of hail around you.", chill(0.7))],
		"spear": ["piercing_thrust", arc("Jab", "piercing_thrust", 1.6, 2.5, 40.0, 1.5, 300.0, "A long, quick jab."),
			"sweeping_arc", "impale"],
		"halberd": [arc("Hook and Cut", "piercing_thrust", 2.2, 4.0, 80.0, 1.4, 500.0, "Hook a foe and drag them off their feet.", {"stun": 0.8}),
			spin("Pole Sweep", "sweeping_arc", 1.5, 7.0, 125.0, 1, "A long sweep that keeps the crowd back."),
			slam("Crushing Blow", "ground_breaker", 2.8, 9.0, 100.0, 90.0, "Bring the axe-head down from on high."), "impale"],
		"sunfang": [arc("Dawn Thrust", "piercing_thrust", 2.2, 3.5, 50.0, 1.5, 350.0, "A thrust of burning light.", {"color": HOLY}),
			shot("Sunspear", "spell_holy_lance", 2.4, 6.0, 1, 0.0, "Hurl a lance of sunlight that pierces all.", {"pierce": true, "speed": 1000.0}, {"color": HOLY}),
			spin("Solar Ring", "spell_radiant_burst", 1.4, 9.0, 130.0, 1, "A ring of sunlight that heals you a little.", {"color": HOLY, "heal": 0.06}),
			slam("Noonfall", "spell_smite", 3.2, 12.0, 120.0, 100.0, "Bring the noon sun down on them.", {"color": HOLY})],
		"heartpiercer": [arc("Heart Thrust", "piercing_thrust", 2.4, 3.5, 40.0, 1.6, 300.0, "Aim for the heart.", bleed(0.3)),
			dash("Pierce Through", "impale", 2.0, 6.0, 240.0, "Run them through, one after another.", bleed()),
			spin("Vein Sweep", "sweeping_arc", 1.4, 8.0, 125.0, 1, "A sweep that opens every vein it crosses.", bleed()),
			buff("Pulse of War", "battle_cry", 30.0, 8.0, {"attack_speed": {"percent": 0.2}, "life_steal": {"flat": 0.05}}, BLOOD, "For 8 seconds strike faster and heal from every wound.")],
		"bow": ["piercing_arrow", shot("Double Shot", "rapid_volley", 1.1, 3.0, 2, 8.0, "Loose two arrows at once."),
			"rapid_volley", "explosive_arrow"],
		"splitshot": [shot("Splitting Arrow", "rapid_volley", 1.0, 3.5, 3, 30.0, "One arrow that splits in three."),
			shot("Fan of Arrows", "multishot", 0.9, 6.0, 7, 70.0, "Seven arrows in a wide fan."),
			shot("Long Shot", "piercing_arrow", 2.6, 5.0, 1, 0.0, "A slow, aimed shot that flies far and true.", {"pierce": true, "speed": 1100.0, "range": 900.0}),
			"rain_of_arrows"],
		"heartstring": [shot("Heartseeker", "piercing_arrow", 2.2, 4.0, 1, 0.0, "An arrow that bleeds what it strikes.", {"pierce": true}, bleed(0.3)),
			shot("Blood Volley", "rapid_volley", 1.0, 5.0, 4, 26.0, "Four red arrows.", {}, bleed()),
			shot("Vein Rain", "explosive_arrow", 1.6, 8.0, 5, 50.0, "A spray of arrows that drink as they strike.", {}, {"heal": 0.05, "color": BLOOD}),
			buff("Steady Pulse", "hunters_mark", 30.0, 10.0, {"critical_chance": {"flat": 0.15}, "attack_speed": {"percent": 0.15}}, BLOOD, "For 10 seconds your aim is sure and your hand quick.")],
		"staff": [shot("Arcane Bolt", "arcane_barrage", 1.4, 2.5, 1, 0.0, "A bolt of raw magic.", {"sprite": 2, "speed": 700.0}, magic),
			"arcane_barrage", spin("Force Ring", "frost_nova", 1.3, 8.0, 120.0, 1, "A ring of force pushes everything away.", magic), "meteor"],
		"altar_staff": [shot("Altar Light", "spell_holy_lance", 1.6, 2.5, 1, 0.0, "A bolt of the altar's light.", {"sprite": 2, "pierce": true}, magic),
			shot("Prayer Barrage", "arcane_missiles", 0.9, 5.0, 5, 40.0, "Five small lights fly out together.", {"sprite": 2}, magic),
			spin("Hallowed Ground", "spell_radiant_burst", 1.4, 9.0, 130.0, 1, "Light bursts round you and heals you.", {"heal": 0.08, "mana": 22.0, "stamina": 0.0, "magic": true, "color": HOLY}),
			"meteor"],
		"ember_staff": [shot("Ember Bolt", "spell_fire_bolt", 1.5, 2.5, 1, 0.0, "A spitting bolt of fire.", {"sprite": 2, "speed": 680.0}, {"mana": 14.0, "stamina": 0.0, "magic": true, "color": FIRE}),
			spin("Flame Ring", "spell_flame_ring", 1.4, 8.0, 120.0, 1, "Fire rushes out round you.", {"mana": 20.0, "stamina": 0.0, "magic": true, "color": FIRE, "status": {"status": "burn", "duration": 3.0, "power": 0.3}}),
			slam("Fire Pillar", "spell_meteor", 2.8, 10.0, 110.0, 120.0, "Raise a pillar of fire ahead.", {"mana": 26.0, "stamina": 0.0, "magic": true, "color": FIRE}),
			"meteor"],
		"wispkeeper": [shot("Wisp Bolt", "arcane_missiles", 1.3, 2.5, 2, 12.0, "Two little wisps dart out.", {"sprite": 2}, magic),
			{"name": "Wisp Chain", "shape": "chain", "icon_from": "lightning_chain", "damage": 1.3, "mana": 18.0, "cooldown": 6.0, "targets": 5, "reach": 320.0, "jump": 170.0, "color": Color(0.6, 1.0, 0.9), "magic": true, "text": "A wisp jumps between five foes."},
			buff("Wisp Ward", "iron_skin", 30.0, 10.0, {"armor": {"percent": 0.3}, "health_regen": {"flat": 3.0}}, Color(0.6, 1.0, 0.9), "For 10 seconds wisps guard and mend you."),
			"frost_nova"],
	}
