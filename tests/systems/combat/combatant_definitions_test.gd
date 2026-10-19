extends "res://tests/support/test_case.gd"

const VALID_EFFECT = preload("res://tests/systems/abilities/valid_effect.gd")

func _run() -> void:
	var character := CharacterDefinition.new()
	character.id = &"test_character"
	character.display_name = "Test Character"
	character.class_id = &"test_class"
	character.resource_capacities[GameplayTypes.ResourceType.HEALTH] = 40
	var equipment := StartingEquipmentDefinition.new()
	equipment.item_id = &"test_sword"
	equipment.position = Vector2i(2, 1)
	equipment.rotation = 1
	character.starting_equipment.append(equipment)
	var action := ActionDefinition.new()
	action.id = &"test_attack"
	action.display_name = "Test Attack"
	action.target_id = &"opponent"
	action.activation_costs[GameplayTypes.ResourceType.STAMINA] = 2
	action.effects.append(VALID_EFFECT.new())
	var behavior := MonsterBehaviorDefinition.new()
	behavior.actions.assign([action, action])
	var monster := MonsterDefinition.new()
	monster.id = &"test_monster"
	monster.display_name = "Test Monster"
	monster.behavior = behavior
	var character_class := CharacterClassDefinition.new()
	character_class.id = &"test_class"
	character_class.display_name = "Test Class"
	for value: Resource in [character, equipment, action, behavior, monster, character_class]:
		check_equal(value.validation_errors(), PackedStringArray(), "Valid " + value.get_script().get_global_name())
		var before: String = var_to_str(value.validation_errors())
		check_equal(var_to_str(value.validation_errors()), before, "Validation is repeatable")
		var path: String = artifact_path(value.get_script().get_global_name() + ".tres")
		check_equal(ResourceSaver.save(value, path), OK, "Definition saves")
		var restored: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		check(restored != null, "Definition reloads")
		if restored != null:
			check_equal(restored.get_script(), value.get_script(), "Concrete type survives")
			check_equal(restored.validation_errors(), PackedStringArray(), "Reloaded definition validates")
	var restored_character: CharacterDefinition = ResourceLoader.load(artifact_path("CharacterDefinition.tres"), "", ResourceLoader.CACHE_MODE_IGNORE)
	check_equal(restored_character.resource_capacities[GameplayTypes.ResourceType.HEALTH], 40, "Health capacity survives")
	check_equal(restored_character.starting_equipment[0].position, Vector2i(2, 1), "Nested placement survives")
	check_equal(restored_character.starting_equipment[0].rotation, 1, "Nested rotation survives")
	var restored_monster: MonsterDefinition = ResourceLoader.load(artifact_path("MonsterDefinition.tres"), "", ResourceLoader.CACHE_MODE_IGNORE)
	check_equal(restored_monster.behavior.actions.size(), 2, "Repeated action cycle survives")
	check_equal(restored_monster.behavior.actions[0].effects.size(), 1, "Nested effect survives")
	check(load("res://systems/combat/combatant_definition.gd").is_abstract(), "Combatant base is abstract")
	character.id = &""
	expect_error(character, "id")
	character.class_id = &""
	expect_error(character, "class_id")
	character.resource_capacities[999] = -1
	expect_error(character, "resource_capacities")
	character.base_stats[999] = 1
	expect_error(character, "base_stats")
	character.abilities.append(null)
	expect_error(character, "abilities[0]")
	character.backpack_size = Vector2i.ZERO
	expect_error(character, "backpack_size")
	expect_error(character, "starting_equipment[0].position")
	character.starting_equipment.append(null)
	expect_error(character, "starting_equipment[1]")
	equipment.item_id = &" "
	equipment.position = Vector2i(-1, 0)
	equipment.rotation = 4
	for field: String in ["item_id", "position", "rotation"]:
		expect_error(equipment, field)
	action.activation_costs[999] = -1
	action.target_id = &""
	action.conditions.append(null)
	action.effects.assign([null])
	for field: String in ["activation_costs", "target_id", "conditions[0]", "effects[0]"]:
		expect_error(action, field)
	expect_error(monster, "behavior: actions[0]")
	behavior.actions.clear()
	expect_error(behavior, "actions")
	monster.behavior = null
	expect_error(monster, "behavior")
	character_class.abilities.append(null)
	expect_error(character_class, "abilities[0]")
	check(CharacterDefinition.new().resource_capacities.is_empty(), "Mutable resource defaults are independent")
	check(MonsterDefinition.new().abilities.is_empty(), "Mutable ability defaults are independent")
	report("COMBATANT DEFINITIONS")
	quit(1 if failures else 0)

func expect_error(value: Resource, field: String) -> void:
	check("\n".join(value.validation_errors()).contains(field), "Indexed diagnostic: " + field)
