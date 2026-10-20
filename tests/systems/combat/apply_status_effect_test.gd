extends "res://tests/support/test_case.gd"

func _run() -> void:
	var path: String = "res://systems/abilities/apply_status_effect_definition.gd"
	if not FileAccess.file_exists(path):
		check(false, "Typed status application definition exists")
		report("APPLY STATUS EFFECT")
		quit(1)
		return
	var model: Script = load(path)
	var resolver: Script = load("res://systems/abilities/effect_resolver.gd")
	var effect = model.new()
	check(not effect.validation_errors().is_empty(), "Status reference is required")
	effect.status = StatusResolver.definition(&"poison")
	effect.stacks = 3
	check_equal(effect.validation_errors(), PackedStringArray(), "Typed effect validates")
	var source: Dictionary = {&"poison": StatusResolver.create(&"poison", 1)}
	var opponent: Dictionary = {&"poison": StatusResolver.create(&"poison", 2)}
	var result: Dictionary = resolver.resolve(effect, source, opponent)
	check_equal(result.errors, PackedStringArray(), "Opponent application succeeds")
	check_equal(opponent[&"poison"].stacks, 5, "Default target is the opponent")
	check_equal(source[&"poison"].stacks, 1, "Opponent effect leaves source unchanged")
	effect.target = model.Target.SELF
	resolver.resolve(effect, source, opponent, 2)
	check_equal(source[&"poison"].stacks, 7, "Self effect applies authored stacks times activation count")
	check_equal(effect.stacks, 3, "Execution does not mutate the shared definition")
	var capped := StatusEffectDefinition.new()
	capped.id = &"fixture"
	capped.display_name = "Fixture"
	capped.max_stacks = 4
	capped.duration_rounds = 3
	var policy_effect = model.new()
	policy_effect.status = capped
	policy_effect.stacks = 3
	var targets: Dictionary = {&"fixture": StatusEffectInstance.new(capped, 2, 1)}
	resolver.resolve(policy_effect, source, targets)
	check_equal(targets[&"fixture"].stacks, 4, "Effect execution delegates stack caps to StatusResolver")
	check_equal(targets[&"fixture"].remaining_rounds, 3, "Effect execution delegates duration refresh to StatusResolver")
	capped.stack_policy = StatusEffectDefinition.StackPolicy.REPLACE
	policy_effect.stacks = 1
	resolver.resolve(policy_effect, source, targets)
	check_equal(targets[&"fixture"].stacks, 1, "Effect execution delegates replacement stacking")
	var output_path: String = artifact_path("apply_effect.tres")
	check_equal(ResourceSaver.save(effect, output_path), OK, "Typed effect serializes as a Resource")
	var loaded: Resource = ResourceLoader.load(output_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	check_equal(loaded.stacks, effect.stacks, "Authored stack count survives serialization")
	check_equal(loaded.target, model.Target.SELF, "Target enum survives serialization")
	check_equal(loaded.status.id, effect.status.id, "Status definition reference survives serialization")
	var before: Dictionary = StatusResolver.snapshot(source[&"poison"])
	result = resolver.resolve(effect, source, opponent, -1)
	check(not result.errors.is_empty(), "Negative application counts are rejected")
	check_equal(StatusResolver.snapshot(source[&"poison"]), before, "Rejected applications leave state unchanged")
	result = resolver.resolve(effect, {}, opponent)
	check(not result.errors.is_empty(), "Missing target status state fails explicitly")
	effect.stacks = 0
	check(not effect.validation_errors().is_empty(), "Authored stack count must be positive")
	effect.stacks = 3
	effect.target = 99
	check(not effect.validation_errors().is_empty(), "Unknown target enum is rejected")
	var content = preload("res://systems/content/runtime_content.gd").content()
	check_equal(content.status_applications.size(), 5, "All existing statuses have authored application effects")
	for application in content.status_applications:
		check_equal(application.stacks, 1, "Combat aggregate templates apply one stack per contribution")
		check_equal(application.validation_errors(), PackedStringArray(), "Authored application effect validates")
	var original_applications: Array = content.status_applications.duplicate()
	content.status_applications.remove_at(0)
	check(not content.validation_errors().is_empty(), "Content validation rejects missing application records before combat")
	content.status_applications.assign(original_applications)
	var unsupported := CatalogRuleEffectDefinition.new()
	unsupported.rule_id = &"fixture"
	check(not resolver.resolve(unsupported, source, opponent).errors.is_empty(), "Unsupported effects fail explicitly")
	report("APPLY STATUS EFFECT")
	quit(1 if failures else 0)
