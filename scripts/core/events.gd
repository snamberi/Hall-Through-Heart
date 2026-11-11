extends Node
## Global progression event bus (autoload "Events").
##
## Systems announce what happened here and other systems react, so leveling,
## mastery, quests, and the interface never need to know about each other.

## The player hurt something. `amount` is health actually removed.
signal damage_dealt(weapon_type: String, amount: float)
## An enemy died. Keys: id, name, level, rank, xp, position, weapon_type.
signal enemy_killed(info: Dictionary)
signal xp_gained(amount: int, source: String)
signal level_up(level: int)
## Every tenth level.
signal milestone_reached(level: int)
signal mastery_level_up(weapon_type: String, level: int)
signal player_died(xp_lost: int)
## The player picked something up. `item` is the saved form (Item.to_dict()).
signal item_acquired(item: Dictionary)
signal profession_level_up(profession: String, level: int)
## Something was gathered from the world. Keys: resource, item, count.
signal resource_gathered(info: Dictionary)
signal item_crafted(recipe_id: String)
## The player pressed interact next to someone.
signal npc_interacted(npc: Node)
signal quest_completed(title: String, rewards: String)
signal biome_discovered(biome: String, xp: int)
## A big message for the middle of the screen (a wave starting, a place entered).
signal announcement(title: String, detail: String)
## The player rested somewhere; they will wake there after dying.
signal checkpoint_set(position: Vector2, place: String)
