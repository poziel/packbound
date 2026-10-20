@tool
class_name GrantDamageEffectDefinition
extends EffectDefinition
@export var damage_type: GameplayTypes.DamageType = GameplayTypes.DamageType.PHYSICAL
@export_range(1, 999, 1, "or_greater") var amount: int = 1
@export var scaling: CombatScalingDefinition
func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if not GameplayTypes.DamageType.values().has(damage_type): errors.append("damage_type must be valid.")
	if amount <= 0: errors.append("amount must be positive.")
	if scaling != null: errors.append_array(scaling.validation_errors())
	return errors
