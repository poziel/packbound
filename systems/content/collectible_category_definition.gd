@tool
class_name CollectibleCategoryDefinition
extends Resource
## Shared item/relic category. Empty parent ID marks a root category.

@export_group("Identity")
@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""

@export_group("Hierarchy")
@export var parent_category_id: StringName = &""

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	for field: String in ["id", "display_name"]:
		if str(get(field)).strip_edges().is_empty():
			errors.append("%s must not be blank." % field)
	if parent_category_id != &"" and str(parent_category_id).strip_edges().is_empty():
		errors.append("parent_category_id must be empty or a nonblank category ID.")
	if id != &"" and parent_category_id == id:
		errors.append("parent_category_id must not reference this category itself.")
	return errors
