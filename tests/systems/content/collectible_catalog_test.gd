extends "res://tests/support/test_case.gd"

var catalog_script: Script
var category_script: Script
var item_script: Script
var relic_script: Script

func _run() -> void:
	for path: String in ["res://systems/content/collectible_category_definition.gd", "res://systems/content/collectible_catalog_definition.gd"]:
		if not FileAccess.file_exists(path):
			check(false, "Collectible catalog Resource exists: " + path)
			finish()
			return
	catalog_script = load("res://systems/content/collectible_catalog_definition.gd")
	category_script = load("res://systems/content/collectible_category_definition.gd")
	item_script = load("res://systems/items/item_definition.gd")
	relic_script = load("res://systems/relics/relic_definition.gd")
	if catalog_script == null or category_script == null or not catalog_script.can_instantiate() or not category_script.can_instantiate():
		check(false, "Catalog and category scripts compile")
		finish()
		return
	check(catalog_script.is_tool() and category_script.is_tool(), "Category and catalog support editor creation")
	check_defaults()
	check_category_validation()
	check_catalog_validation()
	check_long_category_graph()
	check_serialization()
	finish()

func finish() -> void:
	report("COLLECTIBLE CATALOG")
	quit(1 if failures else 0)

func category(id: StringName = &"armor", parent: StringName = &"") -> Resource:
	var value: Resource = category_script.new()
	value.id = id
	value.display_name = str(id).capitalize()
	value.parent_category_id = parent
	return value

func collectible(script: Script, id: StringName) -> Resource:
	var value: Resource = script.new()
	value.id = id
	value.display_name = str(id).capitalize()
	if script == item_script:
		value.role = &"armor"
		value.footprint.assign([Vector2i.ZERO])
	return value

func catalog() -> Resource:
	var value: Resource = catalog_script.new()
	value.categories.assign([category(&"equipment"), category(&"armor", &"equipment"), category(&"boots", &"armor")])
	var item: Resource = collectible(item_script, &"test_boots")
	item.category_ids.assign([&"boots"])
	var relic: Resource = collectible(relic_script, &"test_guardian")
	relic.category_ids.assign([&"armor", &"equipment"])
	value.collectibles.assign([item, relic])
	return value

func check_defaults() -> void:
	var first: Resource = catalog_script.new()
	var second: Resource = catalog_script.new()
	check(first.collectibles.is_empty() and first.categories.is_empty(), "New catalog arrays are empty")
	check_equal(first.validation_errors(), PackedStringArray(), "Empty authored catalog is valid")
	check_equal(first.collectibles.get_typed_script(), load("res://systems/content/collectible_definition.gd"), "Catalog accepts the shared collectible base")
	check_equal(first.categories.get_typed_script(), category_script, "Catalog uses typed category records")
	first.categories.append(category())
	first.collectibles.append(collectible(relic_script, &"test"))
	check(second.categories.is_empty() and second.collectibles.is_empty(), "Catalog default arrays are independent")
	var root: Resource = category_script.new()
	for field: String in ["id", "display_name", "description", "parent_category_id"]:
		check(str(root.get(field)).is_empty(), "New category field starts empty: " + field)

func check_category_validation() -> void:
	check_equal(category().validation_errors(), PackedStringArray(), "Root category needs no parent")
	check_equal(category(&"boots", &"armor").validation_errors(), PackedStringArray(), "Child stores a parent ID")
	for field: String in ["id", "display_name"]:
		var value: Resource = category()
		value.set(field, " \t" if field == "display_name" else &" \t")
		check_error(value, field, "Category requires nonblank identity")
	var value: Resource = category(&"armor", &"armor")
	check_error(value, "parent_category_id", "Category cannot parent itself")
	value = category(&"armor", &" \t")
	check_error(value, "parent_category_id", "Whitespace-only parent is not a root")

func check_catalog_validation() -> void:
	var value: Resource = catalog()
	check_equal(value.validation_errors(), PackedStringArray(), "Items and relics share valid hierarchical categories")
	value.categories.append(category(&"armor"))
	check_error(value, "categories[3]", "Duplicate category ID reports its record index")
	value = catalog()
	value.collectibles[1].id = value.collectibles[0].id
	check_error(value, "collectibles[1]", "Item and relic IDs share one unique namespace")
	value = catalog()
	value.collectibles[0].id = &"armor"
	check_equal(value.validation_errors(), PackedStringArray(), "Category and collectible IDs have separate namespaces")
	value = catalog()
	value.categories.append(null)
	value.collectibles.append(null)
	check_error(value, "categories[3]", "Null category reports its index")
	check_error(value, "collectibles[2]", "Null collectible reports its index")
	value = catalog()
	value.categories[0].parent_category_id = &"missing_parent"
	value.collectibles[1].category_ids.append(&"missing_category")
	value.collectibles[0].display_name = ""
	check_error(value, "categories[0].parent_category_id", "Unknown category parent is rejected")
	check_error(value, "collectibles[1].category_ids[2]", "Unknown membership has indexed location")
	check_error(value, "collectibles[0]: display_name", "Child errors are aggregated")
	var before: PackedStringArray = value.validation_errors()
	check_equal(value.validation_errors(), before, "Graph validation is repeatable")
	check_equal(value.categories[0].parent_category_id, &"missing_parent", "Validation does not repair parent references")
	check_equal(value.collectibles[1].category_ids.back(), &"missing_category", "Validation preserves category memberships")
	value = catalog()
	value.categories[0].parent_category_id = &"boots"
	check_error(value, "cycle", "Indirect category cycles are rejected")
	value = catalog()
	value.categories[0].parent_category_id = &"equipment"
	check_error(value, "parent_category_id", "Direct parent cycles are reported")

func check_long_category_graph() -> void:
	var value: Resource = catalog_script.new()
	for index: int in range(256):
		value.categories.append(category(StringName("category_%d" % index), &"" if index == 0 else StringName("category_%d" % (index - 1))))
	check_equal(value.validation_errors(), PackedStringArray(), "Deep category chains validate without recursion limits")
	value.categories[0].parent_category_id = &"category_255"
	check_error(value, "cycle", "Long category cycle terminates with a validation error")

func check_error(value: Resource, location: String, message: String) -> void:
	check("\n".join(value.validation_errors()).contains(location), message + ": " + location)

func check_serialization() -> void:
	var value: Resource = catalog()
	var ability: Resource = load("res://systems/abilities/ability_definition.gd").new()
	ability.id = &"shared_test_guard"
	ability.display_name = "Shared Test Guard"
	ability.trigger_id = &"test_prepare_stats"
	var effect: Resource = load("res://tests/systems/abilities/valid_effect.gd").new()
	effect.amount = 3
	ability.effects.append(effect)
	value.collectibles[0].abilities.append(ability)
	value.collectibles[1].abilities.append(ability)
	value.categories[1].description = "Shared by items and relics."
	var path: String = artifact_path("mixed_collectible_catalog.tres")
	var error: Error = ResourceSaver.save(value, path)
	check_equal(error, OK, "Mixed collectible catalog saves natively")
	if error != OK:
		return
	var restored: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	check(restored != null, "Mixed catalog reloads")
	if restored == null:
		return
	check_equal(restored.collectibles.size(), 2, "Reload retains both collectibles")
	check_equal(restored.categories.size(), 3, "Reload retains the category tree")
	if restored.collectibles.size() != 2 or restored.categories.size() != 3:
		return
	check_equal(restored.collectibles[0].get_script(), item_script, "Mixed container preserves item subtype")
	check_equal(restored.collectibles[1].get_script(), relic_script, "Mixed container preserves relic subtype")
	check_equal(restored.categories[2].parent_category_id, &"armor", "Reload preserves parent category")
	check_equal(restored.categories[1].description, value.categories[1].description, "Reload preserves category description")
	check_equal(restored.collectibles[0].category_ids, [&"boots"], "Reload preserves item categories")
	check_equal(restored.collectibles[1].category_ids, [&"armor", &"equipment"], "Reload preserves relic categories")
	if restored.collectibles[0].abilities.is_empty() or restored.collectibles[1].abilities.is_empty():
		check(false, "Shared abilities survive mixed serialization")
		return
	check(restored.collectibles[0].abilities[0] == restored.collectibles[1].abilities[0], "Item and relic retain shared ability identity")
	check_equal(restored.collectibles[0].abilities[0].effects[0].amount, 3, "Nested effect parameters survive")
	check_equal(restored.validation_errors(), PackedStringArray(), "Reloaded catalog graph validates")
