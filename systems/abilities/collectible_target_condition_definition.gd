@tool
class_name CollectibleTargetConditionDefinition
extends ConditionDefinition
## Bonus recipients touch the source; categories/IDs filter recipients.
@export var category_ids: Array[StringName] = []
@export var item_ids: Array[StringName] = []
func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if category_ids.is_empty() and item_ids.is_empty(): errors.append("A target category or item ID is required.")
	for id: StringName in category_ids + item_ids:
		if str(id).strip_edges().is_empty(): errors.append("Target IDs must not be blank.")
	return errors
