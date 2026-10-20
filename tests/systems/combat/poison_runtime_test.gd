extends "res://tests/support/test_case.gd"

func fixture() -> PackRun:
	var run := PackRun.new()
	run.reset(1729, "warrior")
	run.items.clear()
	run.relics.clear()
	run.start_combat()
	run.hp = 100
	run.max_hp = 100
	run.enemy.hp = 200
	run.enemy.max_hp = 200
	run.enemy.attacks = [1]
	run.enemy.hits = 3
	run.enemy.poison = 2
	run.enemy.cleanse = 0
	run.enemy.magical_resistance = 0
	run.player_poison = 5
	run.enemy_poison = 4
	return run

func plain(value: Variant) -> bool:
	if value is Object: return false
	if value is Dictionary:
		for child: Variant in value.values():
			if not plain(child): return false
	if value is Array:
		for child: Variant in value:
			if not plain(child): return false
	return true

func _run() -> void:
	var run := fixture()
	var before: Dictionary = run.poison_state()
	var rng_before: int = run.rng.state
	var stats: Dictionary = run.effects()
	stats.poison = 3
	stats.cleanse = 2
	stats.ward = 1
	var result: Dictionary = run.outcome(stats)
	check_equal(run.poison_state(), before, "Preview does not mutate live status instances")
	check_equal(run.rng.state, rng_before, "Preview preserves RNG")
	check_equal(result.enemy_poison_after, 6, "Fresh outgoing stacks tick before decay")
	check_equal(result.player_state.player_poison, 2, "Player cleanse precedes tick and decay")
	check_equal(result.poison_after, 4, "Incoming multi-hit Poison applies once after player decay")
	run.relics.append("plague_seal")
	check_equal(run.outcome(stats).enemy_poison_after, 7, "Plague Seal retains enemy stacks")
	run.relics.clear()
	run.set_meta("pack_dev_policy", {"invulnerable": true})
	check_equal(run.outcome(stats).poison_after, 4, "Invulnerability retains contact Poison")
	check_equal(run.outcome(stats).hp_after, 100, "Invulnerability prevents Poison health loss")
	run.enemy.attacks = [0]
	check_equal(run.outcome(stats).poison_after, 2, "No damaging contact means no incoming Poison")
	var authored: StatusEffectDefinition = run.poison_status("enemy").definition
	var rule: CatalogRuleEffectDefinition = authored.effects[0]
	var saved_parameters: Dictionary = rule.parameters.duplicate(true)
	var saved_decay: int = authored.decay_per_round
	var saved_cleansable: bool = authored.cleansable
	rule.parameters.damage_per_stack = 2
	authored.decay_per_round = 2
	var changed: Dictionary = run.outcome(stats)
	check_equal(changed.poison_damage_actual, 14, "Combat reads authored tick damage")
	check_equal(changed.enemy_poison_after, 5, "Combat reads authored decay")
	authored.cleansable = false
	run.enemy.cleanse = 1
	check_equal(run.outcome(stats).enemy_poison_after, 5, "Enemy cleansing respects definition policy")
	check_equal(run.outcome(stats).player_state.player_poison, 3, "Player cleansing respects definition policy")
	rule.parameters = saved_parameters
	authored.decay_per_round = saved_decay
	authored.cleansable = saved_cleansable
	run = fixture()
	var saves := PackRunSaves.new()
	saves.directory = artifact_path("poison_saves")
	check(not run.begin_turn().is_empty(), "Combat creates a pending turn")
	var captured: Dictionary = saves.capture(run, 1.0)
	check(plain(captured), "Save contains plain data without runtime objects")
	check(not captured.state.has("_poison_statuses"), "Backing instances are excluded from saves")
	check(saves.write("pending", captured), "Pending turn writes to disk")
	var loaded: Dictionary = saves.read("pending")
	check(not loaded.is_empty(), "Pending turn reloads from disk")
	var restored := PackRun.new()
	saves.restore(restored, loaded)
	check_equal(restored.poison_state(), run.poison_state(), "Reload preserves committed player-phase status")
	check(restored.poison_status("player") != run.poison_status("player"), "Runs own distinct instances")
	var legacy: Dictionary = captured.duplicate(true)
	legacy.state.erase("poison_statuses")
	legacy.state.pending_turn.erase("poison_statuses_after")
	legacy.state.pending_turn.player_state.erase("poison_statuses")
	var old_run := PackRun.new()
	saves.restore(old_run, legacy)
	run.complete_turn()
	restored.complete_turn()
	old_run.complete_turn()
	check_equal(restored.poison_state(), run.poison_state(), "Pending completion does not double tick after reload")
	check_equal(restored.hp, run.hp, "Pending completion preserves health")
	check_equal(old_run.poison_state(), run.poison_state(), "Numeric-only legacy pending turns remain compatible")
	loaded.state.poison_statuses.player.stacks = -1
	check(saves.write("invalid", loaded), "Corrupted fixture writes")
	check(saves.read("invalid").is_empty(), "Corrupted status counters are rejected")
	report("POISON RUNTIME")
	quit(1 if failures else 0)
