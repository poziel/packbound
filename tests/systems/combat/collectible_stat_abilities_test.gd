extends "res://tests/support/test_case.gd"
const CATEGORIES = preload("res://systems/content/collectible_categories.gd")
const DATA = preload("res://systems/content/runtime_content.gd")

func _run() -> void:
	var effect_script: Script = load("res://systems/abilities/grant_combat_stat_effect_definition.gd") if FileAccess.file_exists("res://systems/abilities/grant_combat_stat_effect_definition.gd") else null
	check(effect_script != null, "Concrete combat stat grant effect exists")
	if effect_script == null:
		report("COLLECTIBLE STAT ABILITIES")
		quit(1)
		return
	var run := PackRun.new()
	run.reset(1729, "warrior")
	run.items.clear()
	run.relics.assign(["tin_cricket", "pocket_hearth"])
	run.max_hp = 100
	for health: int in [49, 50, 51, 100]:
		run.hp = health
		var result: Dictionary = run.effects()
		check_equal(result[GameplayTypes.Stat.WARD], 1, "Tin Cricket grants one Ward at health " + str(health))
		check_equal(result[GameplayTypes.Stat.HEALING], 1 if health <= 50 else 0, "Pocket Hearth checks the half-health boundary")
	for key: String in ["tin_cricket", "pocket_hearth"]:
		var definition: CollectibleDefinition = CATEGORIES.definition_for_key(key)
		check(not DATA.rules(definition.abilities).has("rule"), "No duplicate compatibility rule: " + key)
		var found: Resource
		for ability: AbilityDefinition in definition.abilities:
			for effect: EffectDefinition in ability.effects:
				if effect.get_script() == effect_script: found = effect
		check(found != null, "Relic references concrete stat effect: " + key)
		if found == null: continue
		var prior: int = found.amount
		found.amount = 4
		run.hp = 1
		check_equal(run.effects()[found.stat], 4, "Runtime reads changed authored amount: " + key)
		found.amount = prior
		var saved_stat: int = found.stat
		found.stat = GameplayTypes.Stat.POISON
		check(not definition.validation_errors().is_empty(), "Statuses require a status application effect")
		found.stat = GameplayTypes.Stat.BLOCK
		check_equal(run.effects()["block_gained"], prior, "Typed Block grant updates combat feedback budget")
		found.stat = saved_stat
		var ability: AbilityDefinition = definition.abilities[-1]
		var trigger: StringName = ability.trigger_id
		ability.trigger_id = &"coded_catalog_rule"
		check(not definition.validation_errors().is_empty(), "Concrete stat effects cannot hide inside a compatibility trigger")
		ability.trigger_id = trigger
		found.amount = 0
		check(not definition.validation_errors().is_empty(), "Invalid authored amount is rejected")
		found.amount = prior
		var path: String = artifact_path(key + ".tres")
		check_equal(ResourceSaver.save(found, path), OK, "Typed effect serializes")
		var restored: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		check_equal(restored.amount, prior, "Roundtrip preserves authored amount")
		check_equal(restored.stat, found.stat, "Roundtrip preserves enum stat")
	run.hp = 49
	var preview: Dictionary = run.effects()
	check_equal(run.outcome(preview).healed, 1, "Authored relic Healing reaches combat resolution")
	check(preload("res://systems/relics/relic_abilities.gd").description(PackCatalog.relic("pocket_hearth")).begins_with("Last Stand\n"), "Condition tooltip label is preserved")
	var rng_before: int = run.rng.state
	var state_before: Dictionary = run.status_state()
	check_equal(run.effects(), run.effects(), "Repeated stat previews are deterministic")
	check_equal(run.rng.state, rng_before, "Stat preview preserves RNG")
	check_equal(run.status_state(), state_before, "Stat preview preserves status instances")
	report("COLLECTIBLE STAT ABILITIES")
	quit(1 if failures else 0)
