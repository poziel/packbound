@tool
class_name LootPoolDefinition
extends Resource
## Weighted candidate set shared by item and relic rewards. IDs resolve in the catalog.
## A pool never overrides a collectible's class/character restrictions.
@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Relative weights, not percentages. Zero disables an entry without removing it.
@export var collectible_weights: Dictionary[StringName, float] = {}
## Optional one-based unlock floors; omitted candidates are available from floor 1.
@export var minimum_floors: Dictionary[StringName, int] = {}
## Optional explicit order for deterministic migration; native dictionaries save sorted.
@export var candidate_order: Array[StringName] = []
@export var offer_count: int = 1
@export var allow_duplicates: bool = false

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	for field: String in ["id", "display_name"]:
		if str(get(field)).strip_edges().is_empty():
			errors.append("%s must not be blank." % field)
	if offer_count < 1:
		errors.append("offer_count must be greater than zero.")
	var positive: bool = false
	for key: StringName in collectible_weights:
		if str(key).strip_edges().is_empty():
			errors.append("collectible_weights IDs must not be blank.")
		var weight: float = collectible_weights[key]
		if not is_finite(weight) or weight < 0.0:
			errors.append("collectible_weights[%s] must be finite and nonnegative." % key)
		elif weight > 0.0:
			positive = true
	if not positive:
		errors.append("collectible_weights must contain a positive weight.")
	for key: StringName in minimum_floors:
		if not collectible_weights.has(key) or minimum_floors[key] < 1:
			errors.append("minimum_floors[%s] must reference a candidate and a positive floor." % key)
	if not candidate_order.is_empty():
		var seen: Dictionary = {}
		for key: StringName in candidate_order:
			if not collectible_weights.has(key) or seen.has(key):
				errors.append("candidate_order must contain each candidate exactly once.")
			seen[key] = true
		if seen.size() != collectible_weights.size():
			errors.append("candidate_order must cover all candidates.")
	return errors
