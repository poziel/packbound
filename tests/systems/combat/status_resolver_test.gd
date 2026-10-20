extends "res://tests/support/test_case.gd"

func _run() -> void:
	var path: String = "res://systems/combat/status_resolver.gd"
	if not FileAccess.file_exists(path):
		check(false, "Status resolver exists")
		report("STATUS RESOLVER")
		quit(1)
		return
	var resolver: Script = load(path)
	var definition := StatusEffectDefinition.new()
	definition.id = &"fixture"
	definition.display_name = "Fixture"
	definition.duration_rounds = 3
	definition.max_stacks = 5
	definition.decay_per_round = 1
	var state := StatusEffectInstance.new(definition)
	resolver.apply(state, 3)
	resolver.apply(state, 4)
	check_equal(state.stacks, 5, "Additive application obeys the authored cap")
	state.remaining_rounds = 1
	resolver.apply(state, 1)
	check_equal(state.remaining_rounds, 3, "Reapplication refreshes configured duration")
	definition.refresh_duration_on_application = false
	state.remaining_rounds = 1
	resolver.apply(state, 1)
	check_equal(state.remaining_rounds, 1, "Nonrefreshing application retains its timer")
	definition.stack_policy = StatusEffectDefinition.StackPolicy.REPLACE
	resolver.apply(state, 2)
	check_equal(state.stacks, 2, "Replacement application replaces stacks")
	definition.stack_policy = StatusEffectDefinition.StackPolicy.KEEP_HIGHEST
	resolver.apply(state, 1)
	check_equal(state.stacks, 2, "Highest-stack policy keeps the larger amount")
	definition.cleansable = false
	check_equal(resolver.cleanse(state, 1), 0, "Uncleansable statuses reject cleansing")
	definition.cleansable = true
	check_equal(resolver.cleanse(state, 1), 1, "Partial cleanse returns the removed amount")
	check_equal(state.stacks, 1, "Partial cleansing preserves remaining stacks")
	resolver.advance_round(state)
	check_equal(state.stacks, 0, "Decay or timed expiry removes exhausted state")
	resolver.apply(state, 4)
	check_equal(state.remaining_rounds, 3, "Applying to an expired status starts a fresh timer")
	definition.decay_per_round = 0
	state.remaining_rounds = 1
	resolver.advance_round(state)
	check_equal(state.stacks, 0, "Timed expiration works without stack decay")
	var poison = resolver.create(&"poison", 6)
	var result: Dictionary = resolver.tick(poison, &"after_direct_attacks", {"owner": "player", "resistances": {"magical": 25}})
	check_equal(result.damage, 4, "Poison damage reads its rule and rounds resistance as before")
	check_equal(result.wardable_damage, 4, "Player Poison participates in the shared Ward budget")
	check_equal(poison.stacks, 6, "Tick calculation does not mutate its input")
	check_equal(resolver.tick(poison, &"wrong_phase", {}).damage, 0, "Ticks require the matching trigger")
	var copied = resolver.copy(poison)
	resolver.advance_round(copied, {"owner": "enemy", "relics": ["plague_seal"]})
	check_equal(copied.stacks, 6, "Plague Seal suppresses enemy Poison decay")
	resolver.advance_round(copied, {"owner": "player", "relics": ["plague_seal"]})
	check_equal(copied.stacks, 5, "Plague Seal does not suppress player Poison decay")
	check_equal(poison.stacks, 6, "Copies keep previews isolated")
	var saved: Dictionary = resolver.snapshot(copied)
	check(resolver.is_snapshot_valid(saved, &"poison"), "Plain status snapshot validates")
	var restored = resolver.restore(saved)
	check_equal(restored.stacks, copied.stacks, "Restoration retains exact stacks")
	check_equal(restored.definition, poison.definition, "Restoration resolves the registered shared definition")
	saved.stacks = -1
	check(not resolver.is_snapshot_valid(saved, &"poison"), "Negative saved stacks are rejected")
	report("STATUS RESOLVER")
	quit(1 if failures else 0)
