class_name PlayerStats
extends Node
## Level, experience, and the four stats the player spends points on.
##
## All balance numbers for leveling live here.

signal xp_changed(xp: int, xp_to_next: int)
signal leveled_up(level: int)
## Emitted when points are spent or gained.
signal stats_changed

const STATS: Array[String] = ["strength", "vitality", "agility", "luck"]
const POINTS_PER_LEVEL := 3
const CRITICAL_MULTIPLIER := 2.0

const BASE_MAX_HEALTH := 100.0
const HEALTH_PER_VITALITY := 12.0
const DAMAGE_PER_STRENGTH := 2.0
const SPEED_PER_AGILITY := 4.0
const BASE_CRITICAL_CHANCE := 0.05
const CRITICAL_PER_LUCK := 0.015
const MAX_CRITICAL_CHANCE := 0.6
## Share of progress toward the next level lost on death.
const DEATH_XP_LOSS := 0.25

var level := 1
var xp := 0
var unspent_points := 0
var points: Dictionary[String, int] = {"strength": 0, "vitality": 0, "agility": 0, "luck": 0}


## Experience needed to go from the current level to the next.
func xp_to_next() -> int:
	return roundi(25.0 * pow(level, 1.6))


func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		unspent_points += POINTS_PER_LEVEL
		leveled_up.emit(level)
		stats_changed.emit()
	xp_changed.emit(xp, xp_to_next())


func spend_point(stat: String) -> bool:
	if unspent_points <= 0 or not points.has(stat):
		return false
	unspent_points -= 1
	points[stat] += 1
	stats_changed.emit()
	return true


func apply_death_penalty() -> void:
	xp -= roundi(xp * DEATH_XP_LOSS)
	xp_changed.emit(xp, xp_to_next())


func max_health() -> float:
	return BASE_MAX_HEALTH + points["vitality"] * HEALTH_PER_VITALITY


func attack_damage(base: float) -> float:
	return base + points["strength"] * DAMAGE_PER_STRENGTH


func move_speed(base: float) -> float:
	return base + points["agility"] * SPEED_PER_AGILITY


func dodge_cooldown(base: float) -> float:
	return maxf(base * (1.0 - 0.02 * points["agility"]), 0.25)


func critical_chance() -> float:
	return minf(BASE_CRITICAL_CHANCE + points["luck"] * CRITICAL_PER_LUCK, MAX_CRITICAL_CHANCE)


func roll_critical() -> bool:
	return randf() < critical_chance()
