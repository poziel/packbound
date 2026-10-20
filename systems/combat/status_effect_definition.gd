@tool
class_name StatusEffectDefinition
extends Resource
## Shared status data. Stack counts, remaining rounds and source belong to live state.
enum StackPolicy { ADD = 0, REPLACE = 1, KEEP_HIGHEST = 2 }

@export_group("Identity")
@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D

@export_group("Lifetime and Stacking")
@export var stack_policy: StackPolicy = StackPolicy.ADD
## Zero means uncapped stacks or no timed expiration, respectively.
@export var max_stacks: int = 0
@export var duration_rounds: int = 0
@export var refresh_duration_on_application: bool = true
@export var decay_per_round: int = 0
@export var cleansable: bool = true

@export_group("Tick")
## Resolver-owned trigger ID, e.g. round_start. Empty means no periodic tick.
@export var tick_trigger_id: StringName = &""
@export var effects: Array[EffectDefinition] = []

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	for field: String in ["id", "display_name"]:
		if str(get(field)).strip_edges().is_empty():
			errors.append("%s must not be blank." % field)
	if not StackPolicy.values().has(stack_policy):
		errors.append("stack_policy must be a known StackPolicy.")
	for field: String in ["max_stacks", "duration_rounds", "decay_per_round"]:
		if int(get(field)) < 0:
			errors.append("%s must not be negative." % field)
	if not effects.is_empty() and str(tick_trigger_id).strip_edges().is_empty():
		errors.append("tick_trigger_id is required when tick effects are present.")
	for index: int in range(effects.size()):
		if effects[index] == null:
			errors.append("effects[%d] must not be null." % index)
		else:
			for error: String in effects[index].validation_errors():
				errors.append("effects[%d]: %s" % [index, error])
	return errors
