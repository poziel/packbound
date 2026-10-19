extends "res://tests/support/test_case.gd"

var recipe_script: Script
var ingredient_script: Script

func _run() -> void:
	for name: String in ["recipe_definition", "recipe_ingredient_definition"]:
		if not FileAccess.file_exists("res://systems/crafting/%s.gd" % name):
			check(false, name + " Resource script exists")
			finish()
			return
	recipe_script = load("res://systems/crafting/recipe_definition.gd")
	ingredient_script = load("res://systems/crafting/recipe_ingredient_definition.gd")
	if recipe_script == null or ingredient_script == null or not recipe_script.can_instantiate() or not ingredient_script.can_instantiate():
		check(false, "Recipe and ingredient Resource scripts can instantiate")
		finish()
		return
	check(recipe_script.is_tool() and ingredient_script.is_tool(), "Recipe models support editor authoring")
	check_contract()
	check_ingredient_validation()
	check_recipe_validation()
	check_serialization()
	finish()

func finish() -> void:
	report("RECIPE DEFINITION")
	quit(1 if failures else 0)

func ingredient(ids: Array = [&"small_sword"], quantity: int = 1) -> Resource:
	var value: Resource = ingredient_script.new()
	value.accepted_item_ids.assign(ids)
	value.quantity = quantity
	return value

func valid_recipe() -> Resource:
	var recipe: Resource = recipe_script.new()
	recipe.id = &"test_assemble_blade"
	recipe.result_item_id = &"test_blade"
	recipe.ingredients.append(ingredient())
	return recipe

func check_contract() -> void:
	var recipe: Resource = recipe_script.new()
	var requirement: Resource = ingredient_script.new()
	check(str(recipe.id).is_empty() and str(recipe.result_item_id).is_empty(), "New recipe requires authored IDs")
	check(recipe.ingredients.is_empty(), "New recipe has no implicit ingredients")
	check_equal(recipe.result_quantity, 1, "Default recipe creates one item")
	check(requirement.accepted_item_ids.is_empty(), "New ingredient needs accepted item IDs")
	check_equal(requirement.quantity, 1, "Default ingredient requires one item")
	check_equal(recipe.ingredients.get_typed_script(), ingredient_script, "Recipe owns typed ingredient definitions")
	check_equal(requirement.accepted_item_ids.get_typed_builtin(), TYPE_STRING_NAME, "Alternatives use stable StringName IDs")
	check_properties(recipe, {"id": TYPE_STRING_NAME, "ingredients": TYPE_ARRAY, "result_item_id": TYPE_STRING_NAME, "result_quantity": TYPE_INT})
	check_properties(requirement, {"accepted_item_ids": TYPE_ARRAY, "quantity": TYPE_INT})
	var other_recipe: Resource = recipe_script.new()
	var other_ingredient: Resource = ingredient_script.new()
	requirement.accepted_item_ids.append(&"small_sword")
	recipe.ingredients.append(requirement)
	check(other_recipe.ingredients.is_empty(), "Recipe arrays are independent")
	check(other_ingredient.accepted_item_ids.is_empty(), "Ingredient alternative arrays are independent")

func check_properties(value: Resource, types: Dictionary) -> void:
	var group_count: int = 0
	for property: Dictionary in value.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_GROUP:
			group_count += 1
		if types.has(property.name):
			check_equal(property.type, types[property.name], "Recipe model field type: " + str(property.name))
			check(bool(int(property.usage) & PROPERTY_USAGE_EDITOR), "Recipe field is editable: " + str(property.name))
			check(bool(int(property.usage) & PROPERTY_USAGE_STORAGE), "Recipe field serializes: " + str(property.name))
			if property.name in ["quantity", "result_quantity"]:
				check_equal(property.hint, PROPERTY_HINT_RANGE, "Quantity has an Inspector range hint")
				check_equal(str(property.hint_string).get_slice(",", 0).to_float(), 1.0, "Quantity Inspector minimum is one")
				check(str(property.hint_string).contains("or_greater"), "Quantity hint does not cap authored amounts")
			types.erase(property.name)
	check(types.is_empty(), "Recipe model exposes all required fields")
	check(group_count > 0, "Recipe model has Inspector grouping")

func check_ingredient_validation() -> void:
	check_equal(ingredient().validation_errors(), PackedStringArray(), "One accepted item is valid")
	check_equal(ingredient([&"small_sword", &"bulky_dagger"], 2).validation_errors(), PackedStringArray(), "Alternatives allow a quantified requirement")
	check_equal(ingredient([&"small_sword"], 10000).validation_errors(), PackedStringArray(), "Positive quantities have no artificial upper limit")
	check_error(ingredient([]), "accepted_item_ids", "An ingredient needs alternatives")
	for blank: StringName in [&"", &" \t\n"]:
		check_error(ingredient([&"small_sword", blank]), "accepted_item_ids[1]", "Blank alternative reports its index")
	check_error(ingredient([&"small_sword", &"small_sword"]), "accepted_item_ids[1]", "Duplicate alternative reports its index")
	for quantity: int in [0, -1]:
		check_error(ingredient([&"small_sword"], quantity), "quantity", "Direct assignment cannot bypass positive quantity validation")
	var value: Resource = ingredient([&"small_sword", &"bulky_dagger"], 2)
	var before: Array = value.accepted_item_ids.duplicate()
	check_equal(value.validation_errors(), value.validation_errors(), "Ingredient validation is repeatable")
	check_equal(value.accepted_item_ids, before, "Ingredient validation preserves alternative order")
	check_equal(value.quantity, 2, "Ingredient validation preserves quantity")

func check_recipe_validation() -> void:
	check_equal(valid_recipe().validation_errors(), PackedStringArray(), "Minimal recipe is valid")
	for field: String in ["id", "result_item_id"]:
		for blank: StringName in [&"", &" \t\n"]:
			var recipe: Resource = valid_recipe()
			recipe.set(field, blank)
			check_error(recipe, field, "Required recipe ID is not blank")
	for quantity: int in [0, -1]:
		var recipe: Resource = valid_recipe()
		recipe.result_quantity = quantity
		check_error(recipe, "result_quantity", "Recipe output quantity is positive")
	var recipe: Resource = valid_recipe()
	recipe.ingredients.clear()
	check_error(recipe, "ingredients", "Recipe requires at least one ingredient")
	recipe.ingredients.assign([null, ingredient([], 0)])
	check_error(recipe, "ingredients[0]", "Null ingredient has indexed error")
	check_error(recipe, "ingredients[1]: accepted_item_ids", "Invalid ingredient reports its child field")
	check_error(recipe, "ingredients[1]: quantity", "Validation collects multiple child errors")
	var before: PackedStringArray = recipe.validation_errors()
	check_equal(recipe.validation_errors(), before, "Recipe validation is repeatable")
	check_equal(recipe.ingredients.size(), 2, "Recipe validation preserves invalid slots")
	check_equal(recipe.ingredients[1].quantity, 0, "Recipe validation does not repair invalid input")
	recipe = valid_recipe()
	recipe.ingredients.append(ingredient([&"small_sword", &"bulky_dagger"], 2))
	check_equal(recipe.validation_errors(), PackedStringArray(), "Overlapping alternatives across requirements are valid")
	recipe.ingredients.append(recipe.ingredients[0])
	check_equal(recipe.validation_errors(), PackedStringArray(), "A shared requirement can describe multiple distinct ingredient slots")

func check_error(value: Resource, location: String, message: String) -> void:
	check("\n".join(value.validation_errors()).contains(location), message + ": " + location)

func check_serialization() -> void:
	var recipe: Resource = valid_recipe()
	recipe.result_quantity = 2
	recipe.ingredients.assign([
		ingredient([&"small_sword", &"bulky_dagger"], 2),
		ingredient([&"ruby_crystal"], 1),
		ingredient([&"glowing_mote"], 3)
	])
	var path: String = artifact_path("alternative_recipe.tres")
	var error: Error = ResourceSaver.save(recipe, path)
	check_equal(error, OK, "Native ResourceSaver writes alternative recipe")
	if error != OK:
		return
	var restored: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	check(restored != null, "Alternative recipe reloads")
	if restored == null:
		return
	check(restored != recipe, "Recipe round trip reads a separate object")
	check_equal(restored.get_script(), recipe_script, "Recipe retains its Resource class")
	check_equal(restored.id, recipe.id, "Recipe ID survives serialization")
	check_equal(restored.result_item_id, recipe.result_item_id, "Result ID survives serialization")
	check_equal(restored.result_quantity, 2, "Result quantity survives serialization")
	check_equal(restored.ingredients.size(), 3, "All ingredient requirements survive serialization")
	if restored.ingredients.size() != 3:
		return
	for index: int in range(3):
		var loaded: Resource = restored.ingredients[index]
		check_equal(loaded.get_script(), ingredient_script, "Nested ingredient class survives: %d" % index)
		check(loaded != recipe.ingredients[index], "Nested ingredient is reloaded: %d" % index)
		check_equal(loaded.accepted_item_ids, recipe.ingredients[index].accepted_item_ids, "Alternative IDs survive: %d" % index)
		check_equal(loaded.quantity, recipe.ingredients[index].quantity, "Ingredient quantity survives: %d" % index)
	check_equal(restored.validation_errors(), PackedStringArray(), "Reloaded alternative recipe remains valid")
