@tool
class_name RecipeDefinition
extends Resource
## Shared authored recipe data; catalog resolution and crafting execute elsewhere.

@export_group("Identity")
@export var id: StringName = &""

@export_group("Requirements")
## Every requirement must be satisfied, allocating each owned item at most once.
@export var ingredients: Array[RecipeIngredientDefinition] = []

@export_group("Result")
@export var result_item_id: StringName = &""
@export_range(1, 999, 1, "or_greater") var result_quantity: int = 1

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	for field: String in ["id", "result_item_id"]:
		if str(get(field)).strip_edges().is_empty():
			errors.append("%s must not be blank." % field)
	if result_quantity < 1:
		errors.append("result_quantity must be greater than zero.")
	if ingredients.is_empty():
		errors.append("ingredients must contain at least one requirement.")
	for index: int in range(ingredients.size()):
		if ingredients[index] == null:
			errors.append("ingredients[%d] must not be null." % index)
		else:
			for error: String in ingredients[index].validation_errors():
				errors.append("ingredients[%d]: %s" % [index, error])
	return errors
