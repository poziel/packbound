@tool
class_name MonsterTraitEffectDefinition
extends EffectDefinition
## Monster response and shield traits, interpreted by the combat resolver.
@export var intent: String = ""
@export_range(0, 999, 1, "or_greater") var drain: int = 0
@export_range(0, 999, 1, "or_greater") var reflect: int = 0
@export_range(0, 999, 1, "or_greater") var sunder: int = 0
@export_range(0, 999, 1, "or_greater") var enrage: int = 0
@export_range(0, 999, 1, "or_greater") var regen: int = 0
@export_range(0, 999, 1, "or_greater") var parry: int = 0
@export_range(0, 999, 1, "or_greater") var opening_armor: int = 0
@export_range(0, 999, 1, "or_greater") var cycle_armor: int = 0
func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	for field: String in ["drain", "reflect", "sunder", "enrage", "regen", "parry", "opening_armor", "cycle_armor"]:
		if int(get(field)) < 0: errors.append(field + " must not be negative.")
	return errors
func profile() -> Dictionary:
	return {"intent": intent, "drain": drain, "reflect": reflect, "sunder": sunder,
		"enrage": enrage, "regen": regen, "parry": parry, "opening_armor": opening_armor, "cycle_armor": cycle_armor}
