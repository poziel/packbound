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
	run.enemy[GameplayTypes.Stat.POISON] = 2
	run.enemy[GameplayTypes.Stat.CLEANSE] = 0
	run.enemy[GameplayTypes.Stat.MAGICAL_RESISTANCE] = 0
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
	stats[GameplayTypes.Stat.POISON] = 3
	stats[GameplayTypes.Stat.CLEANSE] = 2
	stats[GameplayTypes.Stat.WARD] = 1
	var result: Dictionary = run.outcome(stats)
	check_equal(run.poison_state(), before, "Preview does not mutate live status instances")
	check_equal(run.rng.state, rng_before, "Preview preserves RNG")
	var feedback_stats: Dictionary = run.effects()
	feedback_stats[GameplayTypes.Stat.HEALING] = 10
	feedback_stats[GameplayTypes.Stat.WARD] = 100
	feedback_stats[GameplayTypes.Stat.SLOW] = 1
	feedback_stats.item_effects = [{"id": 1, "key": "healing", "amount": 10}, {"id": 2, "key": "ward", "amount": 100}, {"id": 3, "key": "slow", "amount": 1}]
	var feedback: Dictionary = run.outcome(feedback_stats)
	check(not feedback.item_effects.any(func(effect): return effect.key == "healing"), "Full-health healing produces no nominal feedback")
	check_equal(feedback.item_effects.filter(func(effect): return effect.key == "ward")[0].amount, 5, "Ward feedback uses actual enum-keyed absorption budget")
	check(feedback.response_item_effects.any(func(effect): return effect.key == "slow"), "Reactive enum stats emit feedback in the response phase")
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
	run.enemy[GameplayTypes.Stat.CLEANSE] = 1
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
	check_equal(loaded.version, 3, "Enum runtime snapshots use save schema version three")
	var version_two: Dictionary = captured.duplicate(true)
	version_two.version = 2
	check(saves.write("version_two", version_two) and not saves.read("version_two").is_empty(), "Version two saves remain readable")
	var restored := PackRun.new()
	saves.restore(restored, loaded)
	check_equal(restored.poison_state(), run.poison_state(), "Reload preserves committed player-phase status")
	check(restored.poison_status("player") != run.poison_status("player"), "Runs own distinct instances")
	var legacy: Dictionary = captured.duplicate(true)
	legacy.state.erase("poison_statuses")
	legacy.state.pending_turn.erase("poison_statuses_after")
	legacy.state.pending_turn.player_state.erase("poison_statuses")
	# Pending outcome stats had text keys, while scalar player checkpoint fields stay text.
	var pending_damage: int = legacy.state.pending_turn[GameplayTypes.Stat.DAMAGE]
	legacy.state.pending_turn.erase(GameplayTypes.Stat.DAMAGE)
	legacy.state.pending_turn["damage"] = pending_damage
	var old_run := PackRun.new()
	saves.restore(old_run, legacy)
	check_equal(old_run.pending_turn[GameplayTypes.Stat.DAMAGE], pending_damage, "Legacy pending damage loads into the enum key")
	check(not old_run.pending_turn.has("damage"), "Pending migration removes duplicate string damage")
	check(old_run.pending_turn.player_state.has("mana"), "Player checkpoint scalar fields retain their string names")
	run.complete_turn()
	restored.complete_turn()
	old_run.complete_turn()
	check_equal(restored.poison_state(), run.poison_state(), "Pending completion does not double tick after reload")
	check_equal(restored.hp, run.hp, "Pending completion preserves health")
	check_equal(old_run.poison_state(), run.poison_state(), "Numeric-only legacy pending turns remain compatible")
	loaded.state.poison_statuses.player.stacks = -1
	check(saves.write("invalid", loaded), "Corrupted fixture writes")
	check(saves.read("invalid").is_empty(), "Corrupted status counters are rejected")
	var playback := PackCombatPlayback.new()
	playback.restore(fixture(), {"active": true, "result": {"damage": 13}})
	check_equal(playback.snapshot().result[GameplayTypes.Stat.DAMAGE], 13, "Legacy playback outcomes normalize through save migration")
	check(not playback.snapshot().result.has("damage"), "Playback removes retired text stat keys")
	playback.cancel()
	playback.free()
	report("POISON RUNTIME")
	quit(1 if failures else 0)
