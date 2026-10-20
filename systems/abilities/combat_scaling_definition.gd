@tool
class_name CombatScalingDefinition
extends Resource
## Bounded multiplier from the immutable pre-bonus snapshot.
enum Metric {
	ONE = 0,
	REACTIONS = 1,
	CRAFTED = 2,
	WEAPONS = 3,
	SPELLS = 4,
	SHIELDS = 5,
	COMPANIONS = 6,
	ITEMS = 7,
	CELLS = 8,
	MOMENTUM = 9,
	UNUSED_MANA = 10,
	UNUSED_STAMINA = 11,
	SPARK = 12,
	SLOW = 13,
	DOOM = 14
}
const KEYS: Array[String] = ["one", "reaction_count", "crafted_count", "weapon_count", "spell_count", "shield_count", "companion_count", "item_count", "cells", "momentum", "unused_mana", "unused_stamina", "spark", "slow", "doom"]
@export var metric: Metric = Metric.ONE
@export_range(1, 999, 1, "or_greater") var cap: int = 1
func amount(context: Dictionary) -> int:
	return mini(cap, maxi(0, 1 if metric == Metric.ONE else int(context.get(KEYS[metric], 0))))
func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if not Metric.values().has(metric): errors.append("Scaling metric must be valid.")
	if cap <= 0: errors.append("Scaling cap must be positive.")
	return errors
