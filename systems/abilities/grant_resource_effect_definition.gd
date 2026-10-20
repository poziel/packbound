@tool
class_name GrantResourceEffectDefinition
extends EffectDefinition
## Round budget granted before activation costs are reserved.
@export var resource: GameplayTypes.ResourceType = GameplayTypes.ResourceType.STAMINA
@export_range(1, 999, 1, "or_greater") var amount: int = 1
@export var scaling: CombatScalingDefinition
func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if resource not in [GameplayTypes.ResourceType.MANA, GameplayTypes.ResourceType.STAMINA]: errors.append("Round grants support mana and stamina only.")
	if amount <= 0: errors.append("amount must be positive.")
	if scaling != null: errors.append_array(scaling.validation_errors())
	return errors
