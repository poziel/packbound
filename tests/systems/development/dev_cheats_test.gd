extends "res://tests/support/test_case.gd"

func _run() -> void:
	var script = load("res://systems/development/dev_session.gd") if FileAccess.file_exists("res://systems/development/dev_session.gd") else null
	check(script != null, "Transient developer policy exists")
	if script == null:
		report("DEV CHEATS")
		quit(1)
		return
	var session = script.new()
	var run := PackRun.new()
	run.reset(1729, "mage")
	var commands = load("res://systems/development/dev_commands.gd").new()
	commands.apply(run, "set_player", {"stat": "mana", "value": 0})
	var ordinary: Dictionary = run.effects()
	session.attach(run)
	check_equal(run.effects(), ordinary, "Attached policy with cheats off changes nothing")
	session.set_cheat("infinite_mana", true)
	var free: Dictionary = run.effects()
	check(free.active_ids.size() > ordinary.active_ids.size(), "Infinite mana activates otherwise unaffordable spells")
	check_equal(free.mana_spent, 0, "Infinite mana charges no mana")
	check_equal(free.blood_cost, 0, "Infinite mana does not charge Arcane Barter health")
	check_equal(free.mana_after, 0, "Infinite mana does not invent a huge resource reserve")
	session.clear_cheats()
	check_equal(run.effects(), ordinary, "Disabling cheats restores ordinary resolution")
	run.reset(1729)
	commands.apply(run, "set_player", {"stat": "stamina", "value": 0})
	var normal_stamina: Dictionary = run.effects()
	session.set_cheat("infinite_stamina", true)
	check(run.effects().active_ids.size() > normal_stamina.active_ids.size(), "Infinite stamina bypasses actual affordability")
	check_equal(run.effects().stamina_spent, 0, "Infinite stamina charges no stamina")
	session.clear_cheats()
	run.hp = 1
	run.player_poison = 50
	run.relics.append("arcane_barter")
	session.set_cheat("invulnerable", true)
	var outcome: Dictionary = run.outcome(run.effects())
	check_equal(outcome.player_state.hp, 1, "Poison and item costs cannot kill invulnerable player")
	check_equal(outcome.hp_after, 1, "Enemy response cannot damage invulnerable player")
	var saves := PackRunSaves.new()
	var saved: Dictionary = saves.capture(run, 0.0)
	var restored := PackRun.new()
	restored.reset(1729)
	saves.restore(restored, saved)
	check(not restored.has_meta("pack_dev_policy"), "Cheats do not persist through serializer")
	check_equal(restored.resource_overrides, run.resource_overrides, "Explicit round budgets persist normally")
	var other := PackRun.new()
	other.reset(1729)
	check(not other.has_meta("pack_dev_policy"), "Policy does not affect another run")
	session.clear_cheats()
	session.set_cheat("restore_health", true)
	run.hp = 1
	run.player_poison = 0
	run.start_combat()
	run.begin_turn()
	check_equal(run.hp, run.max_hp, "Restore health applies at player round boundary")
	session.clear_cheats()
	run.reset(1729)
	run.items.clear()
	run.hp = 30
	run.enemy.hp = 10
	run.enemy.max_hp = 20
	run.enemy.attacks = [5]
	run.enemy.poison = 3
	run.enemy.drain = 4
	var contact_normal: Dictionary = run.outcome(run.effects())
	session.set_cheat("invulnerable", true)
	var contact_immune: Dictionary = run.outcome(run.effects())
	check_equal(contact_immune.hp_after, 30, "Invulnerability prevents contact health loss")
	check_equal(contact_immune.poison_after, contact_normal.poison_after, "Invulnerability preserves poison application")
	check_equal(contact_immune.enemy_hp_after, contact_normal.enemy_hp_after, "Invulnerability preserves enemy drain trigger")
	session.detach()
	check(not run.has_meta("pack_dev_policy"), "Detach removes transient policy")
	report("DEV CHEATS")
	quit(1 if failures else 0)
