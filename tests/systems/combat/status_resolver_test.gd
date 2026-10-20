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
	var burn = resolver.create(&"burn", 6)
	check_equal(resolver.tick(burn, &"after_poison_tick", {}).damage, 6, "Burn resolves authored per-stack damage")
	check_equal(resolver.tick(burn, &"after_poison_tick", {"resistances": {GameplayTypes.DamageType.MAGICAL: 50}}).damage, 3, "Burn respects magical resistance")
	resolver.advance_round(burn)
	check_equal(burn.stacks, 5, "Burn decays once per round")
	var slow = resolver.create(&"slow", 3)
	for strike: int in range(3):
		check_equal(resolver.tick(slow, &"before_enemy_strikes", {"damage": 5, "strike_index": strike}).reduction, 3, "Slow reduces every strike")
	check_equal(slow.stacks, 3, "Slow previews preserve stacks")
	check_equal(resolver.cleanse(slow), 3, "Slow cleansing removes every stack")
	var spark = resolver.create(&"spark", 3)
	check_equal(resolver.tick(spark, &"after_magical_direct_damage", {"magical_damage": 0}).damage, 0, "Spark requires positive magical direct damage")
	resolver.resolve_tick(spark, &"after_magical_direct_damage", {"magical_damage": 0})
	check_equal(spark.stacks, 3, "A zero-damage hit does not consume Spark")
	check_equal(resolver.tick(spark, &"after_magical_direct_damage", {"magical_damage": 1}).damage, 6, "Spark previews all existing stacks")
	check_equal(spark.stacks, 3, "Spark preview does not consume stacks")
	resolver.resolve_tick(spark, &"after_magical_direct_damage", {"magical_damage": 1})
	check_equal(spark.stacks, 2, "Resolving Spark consumes one stack")
	resolver.advance_round(spark)
	check_equal(spark.stacks, 2, "Spark has no passive stack decay")
	var doom = resolver.create(&"doom", 2)
	check_equal(doom.remaining_rounds, 3, "Doom starts its authored three-round timer")
	check_equal(resolver.resolve_tick(doom, &"after_spark_tick", {}).damage, 0, "Doom waits through the first round")
	resolver.advance_round(doom)
	resolver.apply(doom, 3)
	check_equal(doom.remaining_rounds, 2, "Adding Doom never refreshes an active fuse")
	check_equal(resolver.resolve_tick(doom, &"after_spark_tick", {}).damage, 0, "Doom waits through the second round")
	resolver.advance_round(doom)
	check_equal(resolver.tick(doom, &"after_spark_tick", {}).damage, 10, "Doom detonates on the third round before expiry")
	check_equal(doom.stacks, 5, "Doom preview preserves stacks")
	check_equal(resolver.restore(resolver.snapshot(doom)).remaining_rounds, 1, "Snapshots preserve the exact remaining Doom fuse")
	resolver.resolve_tick(doom, &"after_spark_tick", {})
	check_equal(doom.stacks, 0, "Doom detonation consumes all stacks")
	var orphan = resolver.create(&"doom")
	orphan.remaining_rounds = 3
	resolver.resolve_tick(orphan, &"after_spark_tick", {})
	resolver.advance_round(orphan)
	check_equal(orphan.remaining_rounds, 2, "An empty legacy Doom fuse elapses without being cleared")
	orphan.remaining_rounds = 1
	resolver.apply(orphan, 2)
	check_equal(orphan.remaining_rounds, 1, "Fresh Doom retains an existing nonrefreshing orphan fuse")
	check_equal(resolver.resolve_tick(orphan, &"after_spark_tick", {}).damage, 4, "Fresh Doom detonates immediately when the retained fuse is one")
	for id: StringName in [&"burn", &"spark", &"doom"]:
		var cleanable = resolver.create(id, 4)
		check_equal(resolver.cleanse(cleanable, 2), 2, "Partial cleansing removes authored condition stacks: " + str(id))
		check_equal(cleanable.stacks, 2, "Partial cleansing retains remaining condition stacks: " + str(id))
		resolver.cleanse(cleanable)
		check_equal(cleanable.remaining_rounds, 0, "Full cleansing clears condition timers: " + str(id))
	var result: Dictionary = resolver.tick(poison, &"after_direct_attacks", {"owner": "player", "resistances": {GameplayTypes.DamageType.MAGICAL: 25}})
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
