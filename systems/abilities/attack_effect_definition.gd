@tool
class_name AttackEffectDefinition
extends EffectDefinition
## One ordered monster response. Damage remains physical in the current combat resolver.
@export_range(0, 999, 1, "or_greater") var damage: int = 0
@export_range(1, 99, 1, "or_greater") var hits: int = 1
@export var damage_type: GameplayTypes.DamageType = GameplayTypes.DamageType.PHYSICAL
func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if damage < 0: errors.append("damage must not be negative.")
	if hits < 1: errors.append("hits must be positive.")
	if damage_type != GameplayTypes.DamageType.PHYSICAL: errors.append("Monster responses currently support physical damage only.")
	return errors
