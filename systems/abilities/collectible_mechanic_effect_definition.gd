@tool
class_name CollectibleMechanicEffectDefinition
extends EffectDefinition
## Parameters for existing mechanics that resolve at distinct combat phases.
enum Mechanic {
	DIAGONAL_LINKS = 0,
	WRAP_LINKS = 1,
	OVERHEAL_DAMAGE = 2,
	BLOOD_MANA = 3,
	REPEAT_STRONGEST = 4,
	MANA_TO_BLOCK = 5,
	REVIVE = 6,
	REPEAT_MELEE = 7,
	MIRROR = 8,
	PREVENT_STATUS_DECAY = 9
}
@export var mechanic: Mechanic = Mechanic.DIAGONAL_LINKS
@export_range(1, 999, 1, "or_greater") var amount: int = 1
@export_range(1, 999, 1, "or_greater") var divisor: int = 1
@export var status: StatusEffectDefinition
func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if not Mechanic.values().has(mechanic): errors.append("mechanic must be valid.")
	if amount <= 0 or divisor <= 0: errors.append("Mechanic parameters must be positive.")
	if mechanic == Mechanic.PREVENT_STATUS_DECAY and status == null: errors.append("Decay prevention requires a status reference.")
	return errors
