extends "res://tests/support/test_case.gd"
const DATA = preload("res://systems/content/runtime_content.gd")

func _run() -> void:
	var content: GameContentDefinition = DATA.content()
	check_equal(content.validation_errors(), PackedStringArray(), "Registered records validate in a fresh process")
	check_equal(content.status_effects.size(), 5, "All five existing conditions are registered")
	check_equal(content.loot_pools.size(), 10, "All class, shared, relic and quiver pools are registered")
	check_equal(content.loot_progressions.size(), 8, "All reward progression contexts are registered")
	var statuses: Dictionary = {}
	for status: StatusEffectDefinition in content.status_effects:
		statuses[str(status.id)] = status
		check(status.icon != null, "Status reuses existing glyph: " + str(status.id))
		check(status.effects[0].resource_path.ends_with("rule_effect.tres"), "Status rule is an external definition")
	check_equal(statuses.doom.duration_rounds, 3, "Doom fuse retains the three-round content contract")
	check(not statuses.doom.refresh_duration_on_application, "Doom applications do not reset its fuse")
	check_equal(statuses.spark.effects[0].parameters.damage_per_stack, 2, "Spark retains two damage per stack")
	for key: String in ["poison", "burn", "slow"]:
		check_equal(statuses[key].decay_per_round, 1, "Existing decay retained: " + key)
	var pools: Dictionary = {}
	var covered: Dictionary = {}
	for pool: LootPoolDefinition in content.loot_pools:
		pools[str(pool.id)] = pool
		for id: StringName in pool.collectible_weights:
			covered[str(id)] = true
	for key: String in PackCatalog.ROSTER + PackCatalog.RELICS + PackCatalog.QUIVER.OPTIONS.keys():
		check(covered.has(key), "Existing reward candidate is registered: " + key)
	check(not covered.has(PackCatalog.QUIVER.KEY), "Permanent starter quiver is not normal loot")
	for class_key: String in PackCatalog.classes():
		var run := PackRun.new()
		run.reset(1729, class_key)
		for floor_number: int in range(1, 21):
			run.fight = floor_number - 1
			run.floor_index = floor_number - 1
			run.offers.clear()
			run.item_rewards.clear()
			var rng := RandomNumberGenerator.new()
			rng.seed = run.rng.seed
			rng.state = run.rng.state
			var expected: Array[String] = []
			for pool_id: String in ["offense_" + class_key, "defense", "utility"]:
				var pool: LootPoolDefinition = pools[pool_id]
				var eligible: Array[String] = []
				for id: StringName in pool.candidate_order:
					if pool.minimum_floors.get(id, 1) <= floor_number and run.item_enabled(PackCatalog.item(str(id))):
						eligible.append(str(id))
				if not eligible.is_empty():
					expected.append(eligible[rng.randi_range(0, eligible.size() - 1)])
			if class_key == "ranger" and floor_number % 3 == 0:
				var upgrades: Array[String] = PackCatalog.QUIVER.available(run.quiver())
				if not upgrades.is_empty():
					expected[2] = upgrades[rng.randi_range(0, upgrades.size() - 1)]
			run.roll_loot()
			check_equal(run.offers, expected, "Authored pool membership, floors and order preserve seeded rewards: %s floor %d" % [class_key, floor_number])
			check_equal(run.rng.state, rng.state, "Pool snapshot preserves RNG consumption")
	var bad := LootPoolDefinition.new()
	bad.id = &"unknown_candidate_test"
	bad.display_name = "Unknown candidate test"
	bad.collectible_weights = {&"missing_collectible": 1.0}
	content.loot_pools.append(bad)
	check(not content.validation_errors().is_empty(), "Catalog rejects unknown collectible references")
	content.loot_pools.pop_back()
	var progression: LootProgressionDefinition = content.loot_progressions[0].duplicate(true)
	progression.id = &"unknown_pool_test"
	progression.pool_ids.assign([&"missing_pool"])
	content.loot_progressions.append(progression)
	check(not content.validation_errors().is_empty(), "Catalog rejects unknown pool references")
	content.loot_progressions.pop_back()
	check_equal(content.validation_errors(), PackedStringArray(), "Checks leave the shared catalog unchanged")
	report("STATUS AND LOOT RECORDS")
	quit(1 if failures else 0)
