@tool
class_name LootProgressionDefinition
extends Resource
## Authored reward tuning. No rolling, RNG, interpolation or mutable run state.
@export var id: StringName = &""
@export var pool_ids: Array[StringName] = []
## One-based floor checkpoints; each dictionary maps GameplayTypes.Rarity to weight.
## Each checkpoint is complete (omitted rarities have zero weight). The
## resolver uses the latest checkpoint at or below the current floor, without interpolation.
@export var rarity_weights_by_floor: Dictionary[int, Dictionary] = {}
## Applied once if either preference list matches; restrictions are checked first.
## One is neutral. This definition does not introduce any new balance by default.
@export var preferred_weight_multiplier: float = 1.0

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if str(id).strip_edges().is_empty():
		errors.append("id must not be blank.")
	if pool_ids.is_empty():
		errors.append("pool_ids must contain at least one pool.")
	var seen: Dictionary = {}
	for key: StringName in pool_ids:
		if str(key).strip_edges().is_empty() or seen.has(key):
			errors.append("pool_ids must contain unique nonblank IDs.")
		seen[key] = true
	if not is_finite(preferred_weight_multiplier) or preferred_weight_multiplier < 1.0:
		errors.append("preferred_weight_multiplier must be finite and at least one.")
	if not rarity_weights_by_floor.has(1):
		errors.append("rarity_weights_by_floor must define floor 1.")
	for floor_number: int in rarity_weights_by_floor:
		if floor_number < 1:
			errors.append("rarity checkpoint floors must be positive.")
		var positive: bool = false
		for rarity: Variant in rarity_weights_by_floor[floor_number]:
			if not rarity is int or not GameplayTypes.Rarity.values().has(rarity):
				errors.append("floor %d contains an unknown rarity." % floor_number)
			var weight: Variant = rarity_weights_by_floor[floor_number][rarity]
			if not (weight is int or weight is float):
				errors.append("floor %d weights must be numbers." % floor_number)
			elif not is_finite(float(weight)) or float(weight) < 0.0:
				errors.append("floor %d weights must be finite and nonnegative." % floor_number)
			elif float(weight) > 0.0:
				positive = true
		if not positive:
			errors.append("floor %d must contain a positive rarity weight." % floor_number)
	return errors
