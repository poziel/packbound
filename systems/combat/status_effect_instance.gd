class_name StatusEffectInstance
extends RefCounted
## Mutable state for one status on one combatant. Treat the shared definition as
## read-only. Application rules, ticking and expiry belong to the status resolver.

var definition: StatusEffectDefinition
var stacks: int = 0
## Zero is untimed when definition.duration_rounds is zero, or an expired countdown
## for a timed status. Holding expired/empty state does not execute or remove it.
var remaining_rounds: int = 0

## Omitting remaining duration starts at the definition's duration. Explicit zero
## preserves an expired countdown when restoring state; -1 is the default sentinel.
func _init(status_definition: StatusEffectDefinition, initial_stacks: int = 0, initial_remaining_rounds: int = -1) -> void:
	definition = status_definition
	stacks = initial_stacks
	if initial_remaining_rounds == -1:
		remaining_rounds = definition.duration_rounds if definition != null else 0
	else:
		remaining_rounds = initial_remaining_rounds

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if definition == null:
		errors.append("definition must not be null.")
	else:
		for error: String in definition.validation_errors():
			errors.append("definition: " + error)
	if stacks < 0:
		errors.append("stacks must not be negative.")
	if remaining_rounds < 0:
		errors.append("remaining_rounds must not be negative.")
	return errors
