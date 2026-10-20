@tool
class_name CombatMetricConditionDefinition
extends ConditionDefinition
## Evaluated against the pre-relic combat snapshot.
enum Metric {
	HEALTH_PERCENT = 0,
	VOLLEY_DAMAGE = 1,
	REACTION_COUNT = 2,
	TURN = 3,
	CRAFTED_COUNT = 4,
	WEAPON_COUNT = 5,
	SPELL_COUNT = 6,
	SHIELD_COUNT = 7,
	ITEM_COUNT = 8,
	COMPANION_COUNT = 9,
	MAGICAL_DAMAGE = 10,
	PHYSICAL_DAMAGE = 11,
	STAMINA_SPENT = 12,
	UNUSED_MANA = 13,
	UNUSED_STAMINA = 14,
	SPARK = 15,
	SLOW = 16,
	DOOM = 17,
	BURN = 18,
	POISON = 19,
	CURSE = 20,
	CELLS = 21,
	BLOCK = 22,
	DAMAGE = 23,
	ENEMY_HEALTH_RATIO = 24
}
enum Comparison {
	AT_LEAST = 0,
	AT_MOST = 1,
	EQUAL = 2
}
@export var metric: Metric = Metric.HEALTH_PERCENT
@export var comparison: Comparison = Comparison.AT_LEAST
@export var threshold: int = 1

@export_range(0, 999, 1, "or_greater") var modulo: int = 0
@export_range(1, 999, 1, "or_greater") var denominator: int = 1
const KEYS: Array[String] = ["hp", "volley_damage", "reaction_count", "turn", "crafted_count", "weapon_count", "spell_count", "shield_count", "item_count", "companion_count", "magical_damage", "physical_damage", "stamina_spent", "unused_mana", "unused_stamina", "spark", "slow", "doom", "burn", "poison", "curse", "cells", "block", "damage", "enemy_hp"]
func matches(context: Dictionary) -> bool:
	var value: int = int(context.get(KEYS[metric], 0))
	var limit: int = threshold
	if metric == Metric.HEALTH_PERCENT:
		value *= 100
		limit *= int(context.get("max_hp", 0))
	elif metric == Metric.ENEMY_HEALTH_RATIO:
		value *= denominator
		limit *= int(context.get("enemy_max_hp", 0))
	if modulo > 0: value = posmod(value, modulo)
	if comparison == Comparison.EQUAL: return value == limit
	return value >= limit if comparison == Comparison.AT_LEAST else value <= limit

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if not Metric.values().has(metric): errors.append("metric must be valid.")
	if not Comparison.values().has(comparison): errors.append("comparison must be valid.")
	if threshold < 0: errors.append("threshold must be nonnegative.")
	if metric == Metric.HEALTH_PERCENT and threshold > 100: errors.append("Health percentage must not exceed 100.")
	if modulo < 0 or denominator <= 0: errors.append("Modulo must be nonnegative and denominator positive.")
	return errors

func tooltip_keyword_id() -> String:
	if metric == Metric.HEALTH_PERCENT and comparison == Comparison.AT_MOST and threshold == 50: return "low_hp"
	if metric == Metric.TURN and comparison == Comparison.EQUAL and modulo == 3 and threshold == 0: return "third"
	if metric == Metric.ITEM_COUNT:
		if comparison == Comparison.AT_MOST and threshold == 4: return "sparse"
		if comparison == Comparison.AT_LEAST and threshold == 8: return "many_items"
	if comparison == Comparison.AT_LEAST and threshold == 1:
		if metric == Metric.REACTION_COUNT: return "reactions"
		if metric == Metric.VOLLEY_DAMAGE: return "volley"
		if metric == Metric.COMPANION_COUNT: return "companions"
	return ""
