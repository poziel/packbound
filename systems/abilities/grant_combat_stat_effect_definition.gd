@tool
class_name GrantCombatStatEffectDefinition
extends EffectDefinition
## Adds a per-round combat stat contribution, not a persistent character stat.
@export var stat: GameplayTypes.Stat = GameplayTypes.Stat.WARD
@export_range(1, 999, 1, "or_greater") var amount: int = 1

@export var scaling: CombatScalingDefinition

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if stat not in [GameplayTypes.Stat.BLOCK, GameplayTypes.Stat.HEALING, GameplayTypes.Stat.VAMPIRISM, GameplayTypes.Stat.PLATING, GameplayTypes.Stat.WARD, GameplayTypes.Stat.CURSE, GameplayTypes.Stat.THORNS, GameplayTypes.Stat.CLEANSE, GameplayTypes.Stat.PIERCE, GameplayTypes.Stat.PHYSICAL_RESISTANCE, GameplayTypes.Stat.MAGICAL_RESISTANCE]:
		errors.append("stat must be a supported combat bonus; damage, resources and statuses use their own effects.")
	if amount <= 0: errors.append("amount must be positive.")
	if scaling != null: errors.append_array(scaling.validation_errors())
	return errors
