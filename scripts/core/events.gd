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
