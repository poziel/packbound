@tool
class_name MonsterDefinition
extends CombatantDefinition
@export var species_id: StringName = &""
@export var role_id: StringName = &""
@export var behavior: MonsterBehaviorDefinition
## Optional reference; encounter selection and progression scaling are separate rules.
@export var reward_pool_id: StringName = &""

func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = super.validation_errors()
	if behavior == null:
		errors.append("behavior must not be null.")
	else:
		for error: String in behavior.validation_errors():
			errors.append("behavior: %s" % error)
	return errors
