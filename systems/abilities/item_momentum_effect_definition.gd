@tool
class_name ItemMomentumEffectDefinition
extends EffectDefinition
@export_range(0, 999, 1, "or_greater") var gain: int = 0
@export_range(0, 999, 1, "or_greater") var damage_per_spent: int = 0
func validation_errors() -> PackedStringArray:
	return PackedStringArray(["Momentum effect requires a positive gain or damage multiplier."]) if gain < 0 or damage_per_spent < 0 or gain + damage_per_spent <= 0 else PackedStringArray()
