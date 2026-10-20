extends "res://tests/support/test_case.gd"

func fixture() -> PackRun:
	var run := PackRun.new()
	run.reset(1729, "warrior")
	run.items.clear()
	run.relics.clear()
	run.start_combat()
	run.hp = 100
	run.max_hp = 100
	run.enemy.hp = 500
	run.enemy.max_hp = 500
	run.enemy.attacks = [5]
	run.enemy.hits = 3
	run.enemy[GameplayTypes.Stat.CLEANSE] = 0
	run.enemy[GameplayTypes.Stat.POISON] = 0
	run.enemy[GameplayTypes.Stat.MAGICAL_RESISTANCE] = 0
	return run

func _run() -> void:
	_authored_policies()
	_orphan_fuses()
	var run := fixture()
	run.enemy_burn = 4
	run.enemy_slow = 2
	run.enemy_spark = 3
	run.enemy_doom = 5
	run.enemy_doom_turns = 2
	check_equal(run.status("enemy", &"burn").stacks, 4, "Numeric Burn accessor updates the authoritative instance")
	run.status("enemy", &"slow").stacks = 3
	check_equal(run.enemy_slow, 3, "Numeric Slow accessor reads the authoritative instance")
	var before: Dictionary = run.status_state()
	var rng_before: int = run.rng.state
	var stats: Dictionary = run.effects()
	stats["physical_damage"] = 0
	stats["magical_damage"] = 1
	stats[GameplayTypes.Stat.SPARK] = 2
	var result: Dictionary = run.outcome(stats)
	check_equal(run.status_state(), before, "All status previews preserve live stacks and exact timers")
	check_equal(run.rng.state, rng_before, "Status previews preserve gameplay RNG")
	check_equal(result.burn_damage_actual, 4, "Burn ticks before its round decay")
	check_equal(result.spark_damage_actual, 6, "Spark ticks only the three existing stacks")
	check_equal(result.enemy_spark_after, 4, "Existing Spark consumes once before two fresh stacks apply")
	check_equal(result.doom_damage_actual, 0, "Doom with two rounds left waits this round")
	check_equal(result.enemy_doom_turns_after, 1, "Doom advances exactly one round")
	check_equal(result.hp_after, 94, "Slow reduces all three five-damage strikes by three")
	check_equal(result.enemy_slow_after, 2, "Slow decays once after all strikes")
	check_equal(result.player_state.enemy_burn, 3, "Burn decays once in the player checkpoint")
	var fresh := fixture()
	var fresh_stats: Dictionary = fresh.effects()
	fresh_stats["magical_damage"] = 1
	fresh_stats[GameplayTypes.Stat.SPARK] = 3
	check_equal(fresh.outcome(fresh_stats).spark_damage_actual, 0, "New Spark waits for a later magical hit")
	run.enemy[GameplayTypes.Stat.CLEANSE] = 1
	var cleansed: Dictionary = run.outcome(run.effects())
	for key: String in ["burn_damage_actual", "spark_damage_actual", "doom_damage_actual"]:
		check_equal(cleansed[key], 0, "Enemy cleansing precedes the status tick: " + key)
	check_equal(cleansed.enemy_slow_after, 0, "Enemy cleansing removes Slow before strikes")
	run.enemy[GameplayTypes.Stat.CLEANSE] = 0
	var saves := PackRunSaves.new()
	saves.directory = artifact_path("all_status_saves")
	check(not run.begin_turn().is_empty(), "Status fixture creates a pending turn")
	var captured: Dictionary = saves.capture(run, 1.0)
	check(captured.state.has("statuses"), "Save records the complete status map")
	check(captured.state.pending_turn.has("statuses_after"), "Pending result records its final status map")
	check(captured.state.pending_turn.player_state.has("statuses"), "Player checkpoint records exact status timers")
	check(saves.write("pending", captured), "Pending statuses write to disk")
	var loaded: Dictionary = saves.read("pending")
	check(not loaded.is_empty(), "Pending statuses reload from disk")
	var restored := PackRun.new()
	saves.restore(restored, loaded)
	check_equal(restored.status_state(), run.status_state(), "Reload preserves exact committed stacks and timers")
	check(restored.status("enemy", &"doom") != run.status("enemy", &"doom"), "Reload owns independent status instances")
	var poison_legacy: Dictionary = captured.duplicate(true)
	poison_legacy.state.poison_statuses = {"player": captured.state.statuses.player.poison.duplicate(true), "enemy": captured.state.statuses.enemy.poison.duplicate(true)}
	poison_legacy.state.erase("statuses")
	check(saves.write("poison_legacy", poison_legacy), "Prior Poison map fixture writes")
	var poison_loaded: Dictionary = saves.read("poison_legacy")
	check(not poison_loaded.is_empty(), "Prior Poison maps remain readable")
	var poison_restored := PackRun.new()
	saves.restore(poison_restored, poison_loaded)
	check_equal(poison_restored.status_state(), run.status_state(), "Prior Poison map and numeric elemental fields restore together")
	var legacy_runs: Array[PackRun] = []
	for version: int in [1, 2, 3]:
		var legacy: Dictionary = captured.duplicate(true)
		legacy.version = version
		legacy.state.erase("statuses")
		legacy.state.erase("poison_statuses")
		legacy.state.pending_turn.erase("statuses_after")
		legacy.state.pending_turn.erase("poison_statuses_after")
		legacy.state.pending_turn.player_state.erase("statuses")
		legacy.state.pending_turn.player_state.erase("poison_statuses")
		check(saves.write("legacy_%d" % version, legacy), "Numeric version %d fixture writes" % version)
		var old_data: Dictionary = saves.read("legacy_%d" % version)
		check(not old_data.is_empty(), "Numeric version %d remains readable" % version)
		var old_run := PackRun.new()
		saves.restore(old_run, old_data)
		legacy_runs.append(old_run)
	run.complete_turn()
	restored.complete_turn()
	check_equal(restored.status_state(), run.status_state(), "Pending reload completion does not double tick any status")
	check_equal(restored.hp, run.hp, "Pending reload preserves response health")
	for old_run: PackRun in legacy_runs:
		old_run.complete_turn()
		check_equal(old_run.status_state(), run.status_state(), "Numeric-only pending completion preserves statuses")
	var corrupt: Dictionary = captured.duplicate(true)
	corrupt.state.statuses.enemy.doom.remaining_rounds = -1
	check(saves.write("corrupt_timer", corrupt), "Corrupt timer fixture writes")
	check(saves.read("corrupt_timer").is_empty(), "Negative Doom timer is rejected on read")
	corrupt = captured.duplicate(true)
	corrupt.state.pending_turn.statuses_after.enemy.spark.definition_id = "burn"
	check(saves.write("corrupt_pending", corrupt), "Corrupt pending fixture writes")
	check(saves.read("corrupt_pending").is_empty(), "Wrong status ID in pending map is rejected on read")
	report("STATUS RUNTIME")
	quit(1 if failures else 0)

func _authored_policies() -> void:
	var run := fixture()
	var burn: StatusEffectDefinition = run.status("enemy", &"burn").definition
	var rule: CatalogRuleEffectDefinition = burn.effects[0]
	var parameters: Dictionary = rule.parameters.duplicate(true)
	var decay: int = burn.decay_per_round
	var cap: int = burn.max_stacks
	var policy: int = burn.stack_policy
	var cleansable: bool = burn.cleansable
	run.enemy_burn = 3
	var stats: Dictionary = run.effects()
	stats[GameplayTypes.Stat.BURN] = 5
	rule.parameters.damage_per_stack = 3
	burn.decay_per_round = 2
	burn.max_stacks = 6
	var result: Dictionary = run.outcome(stats)
	check_equal(result.burn_damage_actual, 18, "Runtime Burn applies authored damage and stack cap")
	check_equal(result.player_state.enemy_burn, 4, "Runtime Burn applies authored decay after capped stacks tick")
	burn.stack_policy = StatusEffectDefinition.StackPolicy.REPLACE
	stats[GameplayTypes.Stat.BURN] = 2
	check_equal(run.outcome(stats).burn_damage_actual, 6, "Runtime Burn reads replacement application policy")
	burn.stack_policy = StatusEffectDefinition.StackPolicy.ADD
	burn.cleansable = false
	run.enemy[GameplayTypes.Stat.CLEANSE] = 1
	stats[GameplayTypes.Stat.BURN] = 0
	check_equal(run.outcome(stats).burn_damage_actual, 9, "Runtime cleansing honors uncleansable Burn")
	# Loading records preserves history even when today's authored cap is lower.
	var saves := PackRunSaves.new()
	var legacy: Dictionary = saves.capture(run, 1.0)
	legacy.state.erase("statuses")
	legacy.state.enemy_burn = 12
	var restored := PackRun.new()
	saves.restore(restored, legacy)
	check_equal(restored.enemy_burn, 12, "Numeric legacy restoration preserves recorded stacks above the current cap")
	rule.parameters = parameters
	burn.decay_per_round = decay
	burn.max_stacks = cap
	burn.stack_policy = policy
	burn.cleansable = cleansable
	var doom: StatusEffectDefinition = run.status("enemy", &"doom").definition
	var duration: int = doom.duration_rounds
	doom.duration_rounds = 5
	run = fixture()
	stats = run.effects()
	stats[GameplayTypes.Stat.DOOM] = 2
	check_equal(run.outcome(stats).enemy_doom_turns_after, 4, "Runtime Doom starts its authored duration")
	run.enemy_doom = 3
	run.enemy_doom_turns = 2
	check_equal(run.outcome(stats).enemy_doom_turns_after, 1, "Runtime Doom reapplication retains its active fuse")
	doom.duration_rounds = duration

func _orphan_fuses() -> void:
	var saves := PackRunSaves.new()
	var run := fixture()
	var legacy: Dictionary = saves.capture(run, 1.0)
	legacy.state.erase("statuses")
	legacy.state.enemy_doom = 0
	legacy.state.enemy_doom_turns = 3
	saves.restore(run, legacy)
	check_equal(run.enemy_doom_turns, 3, "Numeric legacy restore preserves an empty positive Doom fuse")
	check_equal(run.outcome(run.effects()).enemy_doom_turns_after, 2, "Empty legacy Doom fuse advances one round")
	var exact: Dictionary = saves.capture(run, 1.0)
	var restored := PackRun.new()
	saves.restore(restored, exact)
	check_equal(restored.status_state(), run.status_state(), "New status snapshots preserve empty positive Doom fuses")
	run.enemy_doom_turns = 1
	var stats: Dictionary = run.effects()
	stats[GameplayTypes.Stat.DOOM] = 2
	check_equal(run.outcome(stats).doom_damage_actual, 4, "Fresh Doom uses a retained one-round orphan fuse")
