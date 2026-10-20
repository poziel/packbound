@tool
class_name CombatMetricConditionDefinition
extends ConditionDefinition
## Evaluated against the pre-relic combat snapshot.
enum Metric { HEALTH_PERCENT = 0, VOLLEY_DAMAGE = 1, REACTION_COUNT = 2 }
enum Comparison { AT_LEAST = 0, AT_MOST = 1 }
@export var metric: Metric = Metric.HEALTH_PERCENT
@export var comparison: Comparison = Comparison.AT_LEAST
@export var threshold: int = 1

func matches(context: Dictionary) -> bool:
	var value: int = int(context.get("volley_damage" if metric == Metric.VOLLEY_DAMAGE else "reaction_count", 0))
	var limit: int = threshold
	if metric == Metric.HEALTH_PERCENT:
		value = int(context.get("hp", 0)) * 100
		limit = int(context.get("max_hp", 0)) * threshold
	return value >= limit if comparison == Comparison.AT_LEAST else value <= limit

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if not Metric.values().has(metric): errors.append("metric must be valid.")
	if not Comparison.values().has(comparison): errors.append("comparison must be valid.")
	if threshold < 0: errors.append("threshold must be nonnegative.")
	if metric == Metric.HEALTH_PERCENT and threshold > 100: errors.append("Health percentage must not exceed 100.")
	return errors
