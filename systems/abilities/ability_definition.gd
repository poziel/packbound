@tool
class_name AbilityDefinition
extends Resource
## Shared authored ability data; treat as read-only during gameplay.

@export_group("Identity")
@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""

@export_group("Activation")
## A future resolver validates known triggers and their owner compatibility.
@export var trigger_id: StringName = &""
## All listed conditions must match. Empty means unconditional.
@export var conditions: Array[ConditionDefinition] = []
## Effects are authored in execution order; this model does not execute them.
@export var effects: Array[EffectDefinition] = []

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	for field: String in ["id", "display_name", "trigger_id"]:
		if str(get(field)).strip_edges().is_empty():
			errors.append("%s must not be blank." % field)
	if effects.is_empty():
		errors.append("effects must contain at least one effect.")
	for index: int in range(conditions.size()):
		if conditions[index] == null:
			errors.append("conditions[%d] must not be null." % index)
		else:
			for error: String in conditions[index].validation_errors():
				errors.append("conditions[%d]: %s" % [index, error])
	for index: int in range(effects.size()):
		if effects[index] == null:
			errors.append("effects[%d] must not be null." % index)
		else:
			for error: String in effects[index].validation_errors():
				errors.append("effects[%d]: %s" % [index, error])
	return errors
