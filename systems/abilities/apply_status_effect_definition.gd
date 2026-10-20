@tool
class_name ApplyStatusEffectDefinition
extends EffectDefinition
## Shared authored application; execution never changes this Resource.
enum Target { SELF = 0, OPPONENT = 1 }

@export var status: StatusEffectDefinition
@export_range(1, 999, 1, "or_greater") var stacks: int = 1
@export var target: Target = Target.OPPONENT

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if status == null:
		errors.append("status must reference a status definition.")
	elif str(status.id).strip_edges().is_empty():
		errors.append("status must have a nonblank ID.")
	if stacks <= 0: errors.append("stacks must be positive.")
	if not Target.values().has(target): errors.append("target must be a valid Target.")
	# A status is a shared reference, not an owned child. Its catalog validates it.
	return errors
