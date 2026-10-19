extends "res://tests/support/test_case.gd"

const TYPES = preload("res://systems/content/gameplay_types.gd")
const MODEL_PATH := "res://systems/items/item_definition.gd"
var model: Script

func _run() -> void:
	if not FileAccess.file_exists(MODEL_PATH):
		check(false, "ItemDefinition Resource script exists")
		finish()
		return
	model = load(MODEL_PATH)
	if model == null or not model.can_instantiate():
		check(false, "ItemDefinition Resource script can instantiate")
		finish()
		return
	var item: Resource = valid_item()
	check(model.is_tool(), "Definition can instantiate with its scripted defaults in the editor")
	check(item is Resource, "Item definition is a native Godot Resource")
	check_equal(item.validation_errors(), PackedStringArray(), "Minimal authored item is valid")
	check_defaults()
	check_property_contract(item)
	check_validation()
	check_independent_collections()
	check_serialization()
	finish()

func finish() -> void:
	report("ITEM DEFINITION")
	quit(1 if failures else 0)

func valid_item() -> Resource:
	var item: Resource = model.new()
	item.id = &"test_charm"
	item.display_name = "Test Charm"
	item.role = &"booster"
	item.footprint.assign([Vector2i.ZERO])
	return item

func check_defaults() -> void:
	var item: Resource = model.new()
	for field: String in ["id", "display_name", "description", "lore", "role"]:
		check(str(item.get(field)).is_empty(), "New definition starts with empty " + field)
	check_equal(item.rarity, TYPES.Rarity.COMMON, "Default rarity is common")
	check_equal(item.damage_type, TYPES.DamageType.PHYSICAL, "Default damage identity is physical")
	check_equal(item.element, TYPES.Element.NONE, "Default element is NONE")
	check_equal(item.rotatable, true, "New equipment can rotate")
	check_equal(item.icon, null, "An icon is optional")
	for field: String in ["tags", "allowed_class_ids", "allowed_character_ids", "footprint", "base_stats", "activation_costs", "abilities"]:
		check(item.get(field).is_empty(), "New definition starts with empty " + field)

func check_property_contract(item: Resource) -> void:
	var expected := {
		"id": TYPE_STRING_NAME, "display_name": TYPE_STRING, "description": TYPE_STRING,
		"lore": TYPE_STRING, "role": TYPE_STRING_NAME, "rarity": TYPE_INT,
		"tags": TYPE_ARRAY, "allowed_class_ids": TYPE_ARRAY, "allowed_character_ids": TYPE_ARRAY,
		"footprint": TYPE_ARRAY, "rotatable": TYPE_BOOL, "icon": TYPE_OBJECT,
		"base_stats": TYPE_DICTIONARY, "activation_costs": TYPE_DICTIONARY,
		"damage_type": TYPE_INT, "element": TYPE_INT, "abilities": TYPE_ARRAY
	}
	var properties: Dictionary = {}
	var groups: PackedStringArray = []
	for property: Dictionary in item.get_property_list():
		properties[property.name] = property
		if int(property.usage) & PROPERTY_USAGE_GROUP:
			groups.append(property.name)
	for field: String in expected:
		check(properties.has(field), "Resource declares " + field)
		if not properties.has(field):
			continue
		check_equal(properties[field].type, expected[field], "Property type for " + field)
		check(bool(int(properties[field].usage) & PROPERTY_USAGE_EDITOR), "Inspector exposes " + field)
		check(bool(int(properties[field].usage) & PROPERTY_USAGE_STORAGE), "Serialization stores " + field)
	for group: String in ["Identity", "Classification", "Eligibility", "Equipment", "Base Values", "Damage Identity", "Abilities"]:
		check(groups.has(group), "Inspector provides group " + group)
	for field: String in ["tags", "allowed_class_ids", "allowed_character_ids"]:
		check_equal(item.get(field).get_typed_builtin(), TYPE_STRING_NAME, field + " stores StringName entries")
	check_equal(item.footprint.get_typed_builtin(), TYPE_VECTOR2I, "Footprint stores integer grid cells")
	for field: String in ["base_stats", "activation_costs"]:
		check_equal(item.get(field).get_typed_key_builtin(), TYPE_INT, field + " uses enum keys")
		check_equal(item.get(field).get_typed_value_builtin(), TYPE_INT, field + " uses integer amounts")
	check(str(properties.base_stats.hint_string).contains("DAMAGE"), "Inspector offers named stat keys")
	check(str(properties.activation_costs.hint_string).contains("MANA"), "Inspector offers named activation-resource keys")
	check_equal(properties.icon.hint_string, "Texture2D", "Inspector restricts icon to Texture2D")
	for field: String in ["rarity", "damage_type", "element"]:
		check_equal(properties[field].hint, PROPERTY_HINT_ENUM, "Inspector offers an enum dropdown for " + field)
	check_equal(item.abilities.get_typed_script(), load("res://systems/abilities/ability_definition.gd"), "Item stores typed AbilityDefinition references")
	for field: String in ["instance_id", "cell", "rotation", "priority", "cooldown"]:
		check(not properties.has(field), "Definition excludes runtime or deferred field " + field)

func check_validation() -> void:
	for field: String in ["id", "display_name", "role"]:
		for blank: String in ["", " \t\n"]:
			var item: Resource = valid_item()
			item.set(field, blank if field == "display_name" else StringName(blank))
			check_error(item, field, "Blank required field " + field)
	var item: Resource = valid_item()
	item.footprint.clear()
	check_error(item, "footprint", "Footprint must contain occupied cells")
	item = valid_item()
	item.footprint.append(Vector2i.ZERO)
	check_error(item, "footprint", "Duplicate footprint cells are rejected")
	for cell: Vector2i in [Vector2i(-1, 0), Vector2i(0, -1)]:
		item = valid_item()
		item.footprint.assign([cell])
		check_error(item, "footprint", "Negative footprint coordinates are rejected")
	for field: String in ["base_stats", "activation_costs"]:
		for invalid: int in [-1, 999]:
			item = valid_item()
			item.get(field)[invalid] = 1
			check_error(item, field, "Unknown enum key is rejected in " + field)
	item = valid_item()
	item.activation_costs[TYPES.ResourceType.STAMINA] = -1
	check_error(item, "activation_costs", "Negative activation costs are rejected")
	item = valid_item()
	item.activation_costs[TYPES.ResourceType.MANA] = 0
	item.base_stats[TYPES.Stat.DAMAGE] = -2
	check_equal(item.validation_errors(), PackedStringArray(), "Zero costs and signed base modifiers are valid")
	item = valid_item()
	item.allowed_class_ids.assign([&"warrior", &"mage"])
	item.allowed_character_ids.assign([&"future_character"])
	check_equal(item.validation_errors(), PackedStringArray(), "Cross-record eligibility checks belong to the loader")
	var before: String = var_to_str(item.footprint)
	var first: PackedStringArray = item.validation_errors()
	check_equal(item.validation_errors(), first, "Validation is repeatable")
	check_equal(var_to_str(item.footprint), before, "Validation preserves authored footprint")
	check_equal(item.allowed_character_ids, [&"future_character"], "Validation preserves authored references")

func check_error(item: Resource, field: String, message: String) -> void:
	var errors: PackedStringArray = item.validation_errors()
	check(not errors.is_empty(), message)
	check("\n".join(errors).contains(field), message + " identifies " + field)

func check_independent_collections() -> void:
	var first: Resource = model.new()
	var second: Resource = model.new()
	first.tags.append(&"test")
	first.allowed_class_ids.append(&"warrior")
	first.allowed_character_ids.append(&"warrior")
	first.footprint.append(Vector2i.ZERO)
	first.base_stats[TYPES.Stat.DAMAGE] = 7
	first.activation_costs[TYPES.ResourceType.STAMINA] = 2
	first.abilities.append(null)
	for field: String in ["tags", "allowed_class_ids", "allowed_character_ids", "footprint", "base_stats", "activation_costs", "abilities"]:
		check(second.get(field).is_empty(), "Fresh definitions do not share " + field)

func check_serialization() -> void:
	var item: Resource = valid_item()
	item.description = "Line one.\nLine two."
	item.lore = "A test record, never a registered gameplay item."
	item.rarity = TYPES.Rarity.RARE
	item.tags.assign([&"test", &"charm"])
	item.allowed_class_ids.assign([&"warrior", &"mage"])
	item.allowed_character_ids.assign([&"warrior"])
	item.footprint.assign([Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, 1)])
	item.rotatable = false
	item.base_stats[TYPES.Stat.DAMAGE] = 9
	item.base_stats[TYPES.Stat.STAMINA] = -1
	item.activation_costs[TYPES.ResourceType.STAMINA] = 2
	item.activation_costs[TYPES.ResourceType.MANA] = 0
	item.damage_type = TYPES.DamageType.MAGICAL
	item.element = TYPES.Element.FIRE
	var texture := GradientTexture2D.new()
	texture.gradient = Gradient.new()
	item.icon = texture
	var path: String = artifact_path("item_definition.tres")
	var error: Error = ResourceSaver.save(item, path)
	check_equal(error, OK, "Native ResourceSaver writes ItemDefinition")
	if error != OK:
		return
	var restored: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	check(restored != null, "Native ResourceLoader reconstructs ItemDefinition")
	if restored == null:
		return
	check(restored != item, "Serialization test reloads a distinct object")
	check_equal(restored.get_script(), model, "Reload retains the ItemDefinition class")
	for field: String in ["id", "display_name", "description", "lore", "role", "rarity", "tags", "allowed_class_ids", "allowed_character_ids", "footprint", "rotatable", "base_stats", "activation_costs", "damage_type", "element"]:
		check_equal(restored.get(field), item.get(field), "Serialization retains " + field)
	check(restored.icon is GradientTexture2D, "Serialization retains nested Texture2D Resource")
	check_equal(restored.validation_errors(), PackedStringArray(), "Reloaded definition remains valid")
	check_property_contract(restored)
