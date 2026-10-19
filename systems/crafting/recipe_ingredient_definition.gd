@tool
class_name RecipeIngredientDefinition
extends Resource
## One authored recipe requirement, not an owned item or catalog entity.

@export_group("Requirement")
## Any accepted ID can satisfy this requirement; quantities may mix accepted IDs.
@export var accepted_item_ids: Array[StringName] = []
@export_range(1, 999, 1, "or_greater") var quantity: int = 1

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if accepted_item_ids.is_empty():
		errors.append("accepted_item_ids must contain at least one item ID.")
	var seen: Dictionary[StringName, bool] = {}
	for index: int in range(accepted_item_ids.size()):
		var item_id: StringName = accepted_item_ids[index]
		if str(item_id).strip_edges().is_empty():
			errors.append("accepted_item_ids[%d] must not be blank." % index)
		if seen.has(item_id):
			errors.append("accepted_item_ids[%d] duplicates item ID %s." % [index, item_id])
		seen[item_id] = true
	if quantity < 1:
		errors.append("quantity must be greater than zero.")
	return errors
