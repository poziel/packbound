extends "res://tests/support/test_case.gd"

var ability_script: Script
var condition_script: Script
var effect_script: Script
var condition_fixture: Script
var effect_fixture: Script

func _run() -> void:
	for name: String in ["ability_definition", "condition_definition", "effect_definition"]:
		if not FileAccess.file_exists("res://systems/abilities/%s.gd" % name):
			check(false, name + " Resource script exists")
			finish()
			return
	ability_script = load("res://systems/abilities/ability_definition.gd")
	condition_script = load("res://systems/abilities/condition_definition.gd")
	effect_script = load("res://systems/abilities/effect_definition.gd")
	condition_fixture = load("res://tests/systems/abilities/valid_condition.gd")
	effect_fixture = load("res://tests/systems/abilities/valid_effect.gd")
	if ability_script == null or condition_script == null or effect_script == null or condition_fixture == null or effect_fixture == null:
		check(false, "Ability model and fixture scripts load")
		finish()
		return
	check(condition_script.is_abstract(), "ConditionDefinition is abstract")
	check(effect_script.is_abstract(), "EffectDefinition is abstract")
	check(ability_script.can_instantiate(), "AbilityDefinition is concrete")
	if not ability_script.can_instantiate() or not condition_fixture.can_instantiate() or not effect_fixture.can_instantiate():
		check(false, "Concrete definition scripts can instantiate before behavioral checks")
		finish()
		return
	for script: Script in [ability_script, condition_script, effect_script, condition_fixture, effect_fixture]:
		check(script.is_tool(), "Resource script supports editor authoring: " + script.resource_path)
	check_contract()
	check_validation()
	check_item_relationship()
	check_serialization()
	finish()

func finish() -> void:
	report("ABILITY DEFINITION")
	quit(1 if failures else 0)

func valid_ability() -> Resource:
	var ability: Resource = ability_script.new()
	ability.id = &"test_backed"
	ability.display_name = "Test Backed"
	ability.trigger_id = &"test_prepare_stats"
	ability.effects.append(effect_fixture.new())
	return ability

func check_contract() -> void:
	var ability: Resource = ability_script.new()
	for field: String in ["id", "display_name", "description", "trigger_id"]:
		check(str(ability.get(field)).is_empty(), "Default ability " + field + " is empty")
	check(ability.conditions.is_empty() and ability.effects.is_empty(), "New ability has empty typed relationships")
	check_equal(ability.conditions.get_typed_script(), condition_script, "Condition array uses the abstract contract")
	check_equal(ability.effects.get_typed_script(), effect_script, "Effect array uses the abstract contract")
	var types := {"id": TYPE_STRING_NAME, "display_name": TYPE_STRING, "description": TYPE_STRING, "trigger_id": TYPE_STRING_NAME, "conditions": TYPE_ARRAY, "effects": TYPE_ARRAY}
	var groups: PackedStringArray = []
	for property: Dictionary in ability.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_GROUP:
			groups.append(property.name)
		if types.has(property.name):
			check_equal(property.type, types[property.name], "Ability property type: " + str(property.name))
			check(bool(int(property.usage) & PROPERTY_USAGE_EDITOR), "Ability property is editable: " + str(property.name))
			check(bool(int(property.usage) & PROPERTY_USAGE_STORAGE), "Ability property is serialized: " + str(property.name))
			types.erase(property.name)
	check(types.is_empty(), "All ability properties are declared")
	check(groups.has("Identity") and groups.has("Activation"), "Ability Inspector groups describe identity and activation")
	var other: Resource = ability_script.new()
	ability.conditions.append(condition_fixture.new())
	ability.effects.append(effect_fixture.new())
	check(other.conditions.is_empty() and other.effects.is_empty(), "Fresh abilities have independent arrays")

func check_validation() -> void:
	var ability: Resource = valid_ability()
	check_equal(ability.validation_errors(), PackedStringArray(), "An unconditional ability is valid")
	for field: String in ["id", "display_name", "trigger_id"]:
		for blank: String in ["", " \t\n"]:
			ability = valid_ability()
			ability.set(field, blank if field == "display_name" else StringName(blank))
			check_error(ability, field, "Required ability field must not be blank")
	ability = valid_ability()
	ability.effects.clear()
	check_error(ability, "effects", "An ability needs at least one effect")
	for field: String in ["conditions", "effects"]:
		ability = valid_ability()
		ability.get(field).assign([null])
		check_error(ability, field + "[0]", "Null child reports its indexed location")
	ability = valid_ability()
	var condition: Resource = condition_fixture.new()
	condition.minimum_count = 0
	var effect: Resource = effect_fixture.new()
	effect.amount = 0
	ability.conditions.append(condition)
	ability.effects.append(effect)
	check_error(ability, "conditions[0]", "Invalid condition is reported")
	check_error(ability, "effects[1]", "Validation also reports later invalid effects")
	var before: String = var_to_str([ability.id, ability.trigger_id, condition.minimum_count, effect.amount])
	var errors: PackedStringArray = ability.validation_errors()
	check_equal(ability.validation_errors(), errors, "Nested validation is repeatable")
	check_equal(var_to_str([ability.id, ability.trigger_id, condition.minimum_count, effect.amount]), before, "Validation preserves invalid authored values")
	check_equal(ability.conditions.size(), 1, "Validation preserves condition entries")
	check_equal(ability.effects.size(), 2, "Validation preserves effect entries")

func check_error(value: Resource, location: String, message: String) -> void:
	check("\n".join(value.validation_errors()).contains(location), message + ": " + location)

func valid_item() -> Resource:
	var item: Resource = load("res://systems/items/item_definition.gd").new()
	item.id = &"test_charm"
	item.display_name = "Test Charm"
	item.role = &"booster"
	item.footprint.assign([Vector2i.ZERO])
	return item

func check_item_relationship() -> void:
	var item: Resource = valid_item()
	check_equal(item.abilities.get_typed_script(), ability_script, "Item exposes typed AbilityDefinition references")
	check_equal(item.validation_errors(), PackedStringArray(), "An item without abilities stays valid")
	item.abilities.append(null)
	check_error(item, "abilities[0]", "Null item ability reports its index")
	item.abilities.assign([ability_script.new()])
	check_error(item, "abilities[0]", "Invalid item ability reports its index")
	item.abilities.assign([valid_ability()])
	check_equal(item.validation_errors(), PackedStringArray(), "An item with a valid ability is valid")
	check(valid_item().abilities.is_empty(), "New items do not share ability arrays")

func check_serialization() -> void:
	var item: Resource = valid_item()
	var ability: Resource = valid_ability()
	ability.description = "Test fixture only.\nChecks shared references."
	var condition: Resource = condition_fixture.new()
	condition.minimum_count = 2
	ability.conditions.append(condition)
	ability.effects[0].amount = 3
	var second_effect: Resource = effect_fixture.new()
	second_effect.amount = 7
	ability.effects.append(second_effect)
	item.abilities.assign([ability, ability])
	var path: String = artifact_path("item_with_shared_ability.tres")
	var error: Error = ResourceSaver.save(item, path)
	check_equal(error, OK, "Item with nested ability graph saves natively")
	if error != OK:
		return
	var restored: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	check(restored != null, "Item with nested graph reloads")
	if restored == null:
		return
	check_equal(restored.abilities.size(), 2, "Reload preserves ability slots")
	if restored.abilities.size() != 2:
		return
	check(restored != item, "Round trip reads a new item instance")
	check(restored.abilities[0] != ability, "Round trip reads a new nested definition")
	check(restored.abilities[0] == restored.abilities[1], "Reload preserves intentional shared ability identity")
	var loaded: Resource = restored.abilities[0]
	for field: String in ["id", "display_name", "description", "trigger_id"]:
		check_equal(loaded.get(field), ability.get(field), "Reload preserves ability " + field)
	check_equal(loaded.conditions[0].get_script(), condition_fixture, "Reload preserves concrete condition subtype")
	check_equal(loaded.conditions[0].minimum_count, 2, "Reload preserves condition parameters")
	check_equal(loaded.effects[0].get_script(), effect_fixture, "Reload preserves concrete effect subtype")
	check_equal(loaded.effects[0].amount, 3, "Reload preserves first effect")
	check_equal(loaded.effects[1].amount, 7, "Reload preserves ordered second effect")
	check_equal(restored.validation_errors(), PackedStringArray(), "Reloaded graph validates")
