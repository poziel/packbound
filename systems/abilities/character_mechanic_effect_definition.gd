@tool
class_name CharacterMechanicEffectDefinition
extends EffectDefinition
## Class capabilities and tuning; algorithms remain in their owning systems.
enum Mechanic { MOMENTUM, ELEMENTAL_REACTIONS, VOLLEY, RAISE_DEAD, SHADOWSTEP }
@export var mechanic: Mechanic = Mechanic.MOMENTUM
@export var display_name: String = "Momentum"
@export_range(0, 999, 1, "or_greater") var momentum_per_response: int = 1
@export_range(1, 999, 1, "or_greater") var invisibility_period: int = 3
@export_range(0, 999, 1, "or_greater") var starting_companions: int = 1
@export_range(1, 999, 1, "or_greater") var companion_capacity: int = 3
@export_range(0, 999, 1, "or_greater") var companion_damage: int = 2
func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if not Mechanic.values().has(mechanic): errors.append("mechanic must be valid.")
	if momentum_per_response < 0: errors.append("momentum_per_response must not be negative.")
	if invisibility_period < 1: errors.append("invisibility_period must be positive.")
	if starting_companions < 0 or companion_capacity < 1 or starting_companions > companion_capacity: errors.append("Companions require a valid starting amount and capacity.")
	if companion_damage < 0: errors.append("companion_damage must not be negative.")
	return errors
