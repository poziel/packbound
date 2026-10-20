extends "res://tests/support/test_case.gd"

func _run() -> void:
	var path: String = "res://systems/combat/status_effect_instance.gd"
	if not FileAccess.file_exists(path):
		check(false, "StatusEffectInstance runtime class exists")
		report("STATUS EFFECT INSTANCE")
		quit(1)
		return
	var runtime: Script = load(path)
	var doom: StatusEffectDefinition = load("res://assets/status_effects/doom/status_effect.tres")
	var poison: StatusEffectDefinition = load("res://assets/status_effects/poison/status_effect.tres")
	var original_duration: int = doom.duration_rounds
	var first = runtime.new(doom, 2)
	var second = runtime.new(doom, 8, 1)
	check(first is RefCounted and not first is Resource, "Instances are runtime state rather than authored Resources")
	check_equal(first.definition, doom, "Instance retains the shared definition reference")
	check_equal(second.definition, doom, "Multiple instances share the same read-only definition")
	check_equal(first.stacks, 2, "Constructor retains initial stacks")
	check_equal(first.remaining_rounds, original_duration, "Fresh duration defaults to the definition")
	check_equal(second.remaining_rounds, 1, "Restored duration overrides the definition default")
	first.stacks = 4
	first.remaining_rounds = 2
	check_equal(second.stacks, 8, "Stack changes are isolated per instance")
	check_equal(second.remaining_rounds, 1, "Duration changes are isolated per instance")
	check_equal(doom.duration_rounds, original_duration, "Live duration changes do not mutate the definition")
	check_equal(first.validation_errors(), PackedStringArray(), "Valid live state validates")
	var expired = runtime.new(doom, 0, 0)
	check_equal(expired.stacks, 0, "Empty stack state is retained")
	check_equal(expired.remaining_rounds, 0, "Explicit expired duration is not reset to the default")
	check_equal(expired.validation_errors(), PackedStringArray(), "Empty or expired state is valid to hold")
	var untimed = runtime.new(poison, 3)
	check_equal(untimed.remaining_rounds, 0, "Untimed statuses retain zero duration")
	check_equal(untimed.validation_errors(), PackedStringArray(), "Untimed state validates")
	var invalid = runtime.new(doom, -2, -3)
	check_equal(invalid.validation_errors().size(), 2, "Negative live counters are reported")
	check_equal(invalid.stacks, -2, "Validation does not silently clamp state")
	check_equal(invalid.remaining_rounds, -3, "Validation does not silently reset state")
	var missing = runtime.new(null)
	check(not missing.validation_errors().is_empty(), "Missing definition is reported without crashing")
	report("STATUS EFFECT INSTANCE")
	quit(1 if failures else 0)
