extends "res://tests/support/test_case.gd"

const TYPES = preload("res://systems/content/gameplay_types.gd")
var base_script: Script
var item_script: Script
var relic_script: Script

func _run() -> void:
	for path: String in ["res://systems/content/collectible_definition.gd", "res://systems/relics/relic_definition.gd"]:
		if not FileAccess.file_exists(path):
			check(false, "Collectible Resource exists: " + path)
			finish()
			return
	base_script = load("res://systems/content/collectible_definition.gd")
	item_script = load("res://systems/items/item_definition.gd")
	relic_script = load("res://systems/relics/relic_definition.gd")
	if base_script == null or item_script == null or relic_script == null or not item_script.can_instantiate() or not relic_script.can_instantiate():
		check(false, "Collectible hierarchy scripts compile")
		finish()
		return
	check(base_script.is_abstract(), "Shared collectible base is abstract")
	check_equal(item_script.get_base_script(), base_script, "Item inherits the shared collectible contract")
	check_equal(relic_script.get_base_script(), base_script, "Relic inherits the same contract")
	check(base_script.is_tool() and item_script.is_tool() and relic_script.is_tool(), "Hierarchy supports editor authoring")
	check_shared_contract()
	check_validation()
	check_old_item_resource()
	check_relic_serialization()
	check_preferences()
	finish()

func check_preferences() -> void:
	for script: Script in [item_script, relic_script]:
		var value: Resource = definition(script)
		for field: String in ["preferred_class_ids", "preferred_character_ids"]:
			check(value.get(field).is_empty(), "Preference defaults to neutral: " + field)
			check_equal(value.get(field).get_typed_builtin(), TYPE_STRING_NAME, "Preference uses stable IDs: " + field)
			for ids: Array in [[&""], [&" \t"], [&"mage", &"mage"]]:
				value.set(field, Array(ids, TYPE_STRING_NAME, &"", null))
				check_error(value, field + "[", "Invalid preference has indexed diagnostics")
			value.get(field).assign([&"mage", &"warrior"])
		check_equal(value.validation_errors(), PackedStringArray(), "Distinct preferences validate without restrictions")
		check(value.allowed_class_ids.is_empty() and value.allowed_character_ids.is_empty(), "Preferences do not write eligibility")
		var path: String = artifact_path("preferences_%s.tres" % value.get_script().get_global_name())
		check_equal(ResourceSaver.save(value, path), OK, "Preferences save natively")
		var restored: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		check(restored != null, "Preferences reload natively")
		if restored != null:
			for field: String in ["preferred_class_ids", "preferred_character_ids"]:
				check_equal(restored.get(field), value.get(field), "Native round trip retains " + field)

func finish() -> void:
	report("COLLECTIBLE DEFINITION")
	quit(1 if failures else 0)

func definition(script: Script) -> Resource:
	var value: Resource = script.new()
	value.id = &"test_collectible"
	value.display_name = "Test Collectible"
	if script == item_script:
		value.footprint.assign([Vector2i.ZERO])
	return value

func check_shared_contract() -> void:
	for script: Script in [item_script, relic_script]:
		var value: Resource = script.new()
		check_equal(value.rarity, TYPES.Rarity.COMMON, "Shared rarity defaults to COMMON")
		check_equal(value.icon, null, "Shared icon is optional")
		for field: String in ["tags", "category_ids", "allowed_class_ids", "allowed_character_ids", "base_stats", "abilities"]:
			check(value.get(field).is_empty(), "Shared default collection is empty: " + field)
		check_equal(value.category_ids.get_typed_builtin(), TYPE_STRING_NAME, "Categories use stable IDs")
		var properties: Dictionary = {}
		for property: Dictionary in value.get_property_list():
			properties[property.name] = property
		for field: String in ["id", "display_name", "description", "lore", "rarity", "icon", "tags", "category_ids", "allowed_class_ids", "allowed_character_ids", "base_stats", "abilities"]:
			check(properties.has(field), "Concrete collectible exposes shared field: " + field)
			if properties.has(field):
				check(bool(int(properties[field].usage) & PROPERTY_USAGE_EDITOR), "Shared field is Inspector-editable: " + field)
				check(bool(int(properties[field].usage) & PROPERTY_USAGE_STORAGE), "Shared field is serializable: " + field)
		check(str(properties.base_stats.hint_string).contains("DAMAGE"), "Both concrete types inherit named stat choices")
		if script == relic_script:
			for field: String in ["footprint", "rotatable", "activation_costs", "damage_type", "element"]:
				check(not properties.has(field), "Relic has no backpack-specific field: " + field)
	var item: Resource = definition(item_script)
	var relic: Resource = definition(relic_script)
	item.tags.append(&"metal")
	item.category_ids.append(&"swords")
	item.allowed_class_ids.append(&"warrior")
	item.allowed_character_ids.append(&"warrior")
	item.base_stats[TYPES.Stat.DAMAGE] = 9
	item.abilities.append(null)
	for field: String in ["tags", "category_ids", "allowed_class_ids", "allowed_character_ids", "base_stats", "abilities"]:
		check(relic.get(field).is_empty(), "Item and relic do not share default collections: " + field)

func check_validation() -> void:
	for script: Script in [item_script, relic_script]:
		var value: Resource = definition(script)
		check_equal(value.validation_errors(), PackedStringArray(), "Minimal concrete collectible validates")
		for field: String in ["id", "display_name"]:
			value = definition(script)
			value.set(field, " \t" if field == "display_name" else &" \t")
			check_error(value, field, "Inherited required-field validation")
		value = definition(script)
		value.rarity = 999
		check_error(value, "rarity", "Inherited rarity validation")
		value = definition(script)
		value.base_stats[999] = 1
		check_error(value, "base_stats", "Inherited enum stat validation")
		value = definition(script)
		value.abilities.append(null)
		check_error(value, "abilities[0]", "Inherited indexed ability validation")
		for ids: Array in [[&""], [&" \t"], [&"boots", &"boots"]]:
			value = definition(script)
			value.category_ids.assign(ids)
			check_error(value, "category_ids[", "Invalid category IDs have indexed diagnostics")
		value = definition(script)
		value.category_ids.assign([&"boots", &"armor", &"magic"])
		check_equal(value.validation_errors(), PackedStringArray(), "Several categories and explicit ancestors are structurally valid")
		var before: Array = value.category_ids.duplicate()
		check_equal(value.validation_errors(), value.validation_errors(), "Validation is repeatable")
		check_equal(value.category_ids, before, "Validation preserves authored category order")
	var item: Resource = definition(item_script)
	item.id = &""
	item.footprint.clear()
	check_error(item, "id", "Item validation includes shared errors")
	check_error(item, "footprint", "Item also reports equipment-specific errors")

func check_error(value: Resource, field: String, message: String) -> void:
	check("\n".join(value.validation_errors()).contains(field), message + ": " + field)

func check_old_item_resource() -> void:
	var old: Resource = ResourceLoader.load("res://tests/fixtures/content/pre_inheritance_item.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	check(old != null, "Pre-extraction enum item Resource still loads")
	if old == null:
		return
	check_equal(old.get_script(), item_script, "Old item retains concrete script identity")
	check_equal(old.id, &"test_charm", "Inherited item ID survives extraction")
	check_equal(old.display_name, "Test Charm", "Inherited item name survives extraction")
	check_equal(old.description, "Line one.\nLine two.", "Inherited multiline description survives extraction")
	check_equal(old.rarity, TYPES.Rarity.RARE, "Inherited enum rarity survives extraction")
	check_equal(old.tags, [&"test", &"charm"], "Inherited tags survive extraction")
	check_equal(old.allowed_class_ids, [&"warrior", &"mage"], "Inherited class restrictions survive extraction")
	check_equal(old.allowed_character_ids, [&"warrior"], "Inherited character restrictions survive extraction")
	check(old.icon is GradientTexture2D, "Inherited nested icon survives extraction")
	check_equal(old.base_stats[TYPES.Stat.DAMAGE], 9, "Inherited stat map survives extraction")
	check_equal(old.base_stats[TYPES.Stat.STAMINA], -1, "Signed stat values survive extraction")
	check_equal(old.activation_costs[TYPES.ResourceType.STAMINA], 2, "Item-specific costs survive extraction")
	check_equal(old.footprint, [Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, 1)], "Item footprint survives extraction")
	check_equal(old.rotatable, false, "Rotation permission survives extraction")
	check_equal(old.damage_type, TYPES.DamageType.MAGICAL, "Damage enum survives extraction")
	check_equal(old.element, TYPES.Element.FIRE, "Element enum survives extraction")
	check(old.category_ids.is_empty(), "Old item receives empty category default")
	check_equal(old.validation_errors(), PackedStringArray(), "Old authored properties remain valid after extraction")

func check_relic_serialization() -> void:
	var relic: Resource = definition(relic_script)
	relic.description = "A shared definition."
	relic.lore = "Test-only relic."
	relic.rarity = TYPES.Rarity.LEGENDARY
	relic.tags.assign([&"cursed"])
	relic.category_ids.assign([&"magic", &"armor"])
	relic.allowed_class_ids.assign([&"warrior"])
	relic.allowed_character_ids.assign([&"warrior"])
	relic.base_stats[TYPES.Stat.WARD] = 2
	var path: String = artifact_path("relic.tres")
	var error: Error = ResourceSaver.save(relic, path)
	check_equal(error, OK, "Native ResourceSaver writes a relic")
	if error != OK:
		return
	var restored: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	check(restored != null, "Relic reloads natively")
	if restored == null:
		return
	check_equal(restored.get_script(), relic_script, "Relic retains concrete subtype")
	for field: String in ["id", "display_name", "description", "lore", "rarity", "tags", "category_ids", "allowed_class_ids", "allowed_character_ids", "base_stats"]:
		check_equal(restored.get(field), relic.get(field), "Relic round trip retains " + field)
	check_equal(restored.validation_errors(), PackedStringArray(), "Reloaded relic validates without equipment fields")
