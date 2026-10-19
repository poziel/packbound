@tool
class_name CharacterDefinition
extends CombatantDefinition
## Character identity is independent of the class roster ID.
@export var class_id: StringName = &""
@export_multiline var biography: String = ""
@export var starting_equipment: Array[StartingEquipmentDefinition] = []
@export var backpack_size: Vector2i = Vector2i(8, 7)

func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = super.validation_errors()
	if str(class_id).strip_edges().is_empty():
		errors.append("class_id must not be blank.")
	if backpack_size.x <= 0 or backpack_size.y <= 0:
		errors.append("backpack_size must have positive dimensions.")
	for index: int in range(starting_equipment.size()):
		if starting_equipment[index] == null:
			errors.append("starting_equipment[%d] must not be null." % index)
		else:
			for error: String in starting_equipment[index].validation_errors():
				errors.append("starting_equipment[%d]: %s" % [index, error])
			var position: Vector2i = starting_equipment[index].position
			if position.x >= backpack_size.x or position.y >= backpack_size.y:
				errors.append("starting_equipment[%d].position lies outside backpack_size." % index)
	return errors
