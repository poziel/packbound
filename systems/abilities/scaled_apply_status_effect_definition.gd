@tool
class_name ScaledApplyStatusEffectDefinition
extends ApplyStatusEffectDefinition
## Bounded application count from the pre-relic combat snapshot.
enum Metric { ONE = 0, REACTION_COUNT = 1 }
@export var metric: Metric = Metric.ONE
@export_range(1, 999, 1, "or_greater") var cap: int = 1

func applications(context: Dictionary) -> int:
	return mini(cap, maxi(0, int(context.get("reaction_count", 0)))) if metric == Metric.REACTION_COUNT else 1

func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = super.validation_errors()
	if not Metric.values().has(metric): errors.append("metric must be valid.")
	if cap <= 0: errors.append("cap must be positive.")
	return errors
