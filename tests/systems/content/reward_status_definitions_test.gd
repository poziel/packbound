extends "res://tests/support/test_case.gd"

func _run() -> void:
	var status := StatusEffectDefinition.new()
	status.id = &"test_poison"
	status.display_name = "Test Poison"
	status.decay_per_round = 1
	check_equal(status.validation_errors(), PackedStringArray(), "Untimed decaying status is valid")
	var effect := CatalogRuleEffectDefinition.new()
	effect.rule_id = &"test_tick"
	effect.parameters = {"amount": 2}
	status.effects.assign([effect])
	check(not status.validation_errors().is_empty(), "Tick effects require an explicit trigger")
	status.tick_trigger_id = &"round_end"
	check_equal(status.validation_errors(), PackedStringArray(), "Tick effects validate recursively")
	status.duration_rounds = -1
	check(not status.validation_errors().is_empty(), "Negative status duration is rejected")
	status.duration_rounds = 3
	effect.rule_id = &""
	check(not status.validation_errors().is_empty(), "Invalid nested effect is reported")
	effect.rule_id = &"test_tick"
	effect.parameters[""] = 1
	check(not effect.validation_errors().is_empty(), "Catalog bindings reject blank parameter names")
	effect.parameters.erase("")
	effect.parameters[2] = "bad key"
	check(not effect.validation_errors().is_empty(), "Catalog bindings reject numeric parameter names")
	effect.parameters.erase(2)
	var pool := LootPoolDefinition.new()
	pool.id = &"test_items"
	pool.display_name = "Test Items"
	pool.collectible_weights = {&"rusty_knife": 2.0, &"bandage": 0.0}
	check_equal(pool.validation_errors(), PackedStringArray(), "Relative pool weights allow disabled entries")
	pool.collectible_weights[&"rusty_knife"] = NAN
	check(not pool.validation_errors().is_empty(), "Nonfinite pool weights are rejected")
	pool.collectible_weights[&"rusty_knife"] = -1.0
	check(not pool.validation_errors().is_empty(), "Negative pool weights are rejected")
	pool.collectible_weights[&"rusty_knife"] = 2.0
	var progression := LootProgressionDefinition.new()
	progression.id = &"test_descent"
	progression.pool_ids.assign([&"test_items"])
	progression.rarity_weights_by_floor = {1: {GameplayTypes.Rarity.COMMON: 10.0}, 5: {GameplayTypes.Rarity.RARE: 3.0}}
	check_equal(progression.validation_errors(), PackedStringArray(), "Sparse rarity checkpoints validate")
	progression.rarity_weights_by_floor[5][99] = 1.0
	check(not progression.validation_errors().is_empty(), "Unknown enum rarity is rejected")
	progression.rarity_weights_by_floor[5].erase(99)
	progression.rarity_weights_by_floor[5][GameplayTypes.Rarity.RARE] = "three"
	check(not progression.validation_errors().is_empty(), "Nonnumeric nested weights are rejected safely")
	progression.rarity_weights_by_floor[5][GameplayTypes.Rarity.RARE] = 3.0
	progression.pool_ids.append(&"test_items")
	check(not progression.validation_errors().is_empty(), "Repeated pool references are rejected")
	progression.pool_ids.pop_back()
	progression.preferred_weight_multiplier = INF
	check(not progression.validation_errors().is_empty(), "Infinite preference multipliers are rejected")
	progression.preferred_weight_multiplier = 1.5
	for value: Resource in [status, pool, progression, effect]:
		var before: String = var_to_str(value)
		check_equal(value.validation_errors(), PackedStringArray(), "Valid model: " + value.get_script().resource_path)
		check_equal(var_to_str(value), before, "Validation preserves authored values")
		var path: String = artifact_path(value.get_script().resource_path.get_file().get_basename() + ".tres")
		check_equal(ResourceSaver.save(value, path), OK, "Native Resource saving succeeds")
		var loaded: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		check(loaded != null, "Native Resource reload succeeds")
		if loaded != null:
			check_equal(loaded.validation_errors(), PackedStringArray(), "Round-trip preserves a valid definition")
			if loaded is StatusEffectDefinition:
				check_equal(loaded.effects[0].parameters.amount, 2, "Nested tick effects survive serialization")
			if loaded is LootProgressionDefinition:
				check_equal(loaded.rarity_weights_by_floor[5][GameplayTypes.Rarity.RARE], 3.0, "Enum-keyed rarity weights survive serialization")
	report("REWARD AND STATUS DEFINITIONS")
	quit(1 if failures else 0)
