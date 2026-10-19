@tool
class_name MonsterBehaviorDefinition
extends Resource
## Authored ordered action cycle. Repeated action references represent repeated turns.
## Future executor skips unavailable actions; no available action means wait.
## Cursor/turn progression belongs to runtime state, never this shared Resource.
@export var actions: Array[ActionDefinition] = []
## False means wait after the final action rather than restart the cycle.
@export var repeat_cycle: bool = true

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if actions.is_empty():
		errors.append("actions must contain at least one action.")
	for index: int in range(actions.size()):
		if actions[index] == null:
			errors.append("actions[%d] must not be null." % index)
		else:
			for error: String in actions[index].validation_errors():
				errors.append("actions[%d]: %s" % [index, error])
	return errors
