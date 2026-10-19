extends "res://tests/support/prototype_support.gd"

func _run() -> void:
	create_timer(30.0).timeout.connect(func() -> void:
		printerr("FAIL: Combat controls/resources test timed out")
		quit(2))
	_capacity_checks()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_run("mage", 42)
	game.run.relics.clear()
	game.run.items.clear()
	game.run.add_item("spark_ring", Vector2i.ZERO)["mana"] = 3
	var spell: Dictionary = game.run.add_item("ember_tome", Vector2i(1, 0))
	spell["cost"] = 4
	var shield: Dictionary = game.run.add_item("buckler", Vector2i(4, 0))
	shield["block"] = 8
	game.run.enemy["hp"] = 1000
	game.run.enemy["max_hp"] = 1000
	game.run.enemy["attacks"] = [4]
	game.front.settings["combat_speed"] = 4
	game.front.settings["flash"] = true
	game._refresh()
	check(game.mana_bar.get_value_text() == "6 / 6", "Preparation displays full starting mana fraction")
	check(game.block_bar.get_value_text() == "8 / 8", "Preparation displays full starting block fraction")
	check(game.action.text.is_empty() and game.action.accessibility_name == "Attack" and game.action.icon != null, "Preparation uses named icon-only Attack")
	var attack_region: Rect2 = game.action.icon.region
	check(attack_region == Rect2(64, 0, 32, 32), "Attack uses existing crossed-blades atlas glyph")
	game.action.pressed.emit()
	check(game.playback.active and not game.action.disabled and game.action.accessibility_name == "Pause combat", "Attack starts playback and becomes enabled Pause")
	check(game.mana_bar.get_value_text() == "2 / 6", "Mana spending keeps original capacity")
	game.action.pressed.emit()
	check(game.playback.paused and game.action.accessibility_name == "Resume combat" and not game.action.disabled, "Bottom Pause becomes enabled Resume while busy")
	check(game.action.icon.resource_path == "res://assets/ui/icons/combat-v1/resume.svg", "Paused control uses new resume glyph")
	var before: Array = game.run.items.duplicate(true)
	game.board.begin_drag(spell, Vector2.ZERO)
	check(game.board.dragging.is_empty() and game.run.items == before, "Bottom pause keeps inventory locked")
	var pending_before: Dictionary = game.run.pending_turn.duplicate(true)
	await create_timer(0.2).timeout
	check(game.run.pending_turn == pending_before, "Pause freezes pending combat checkpoint")
	game.action.pressed.emit()
	check(not game.playback.paused and game.action.accessibility_name == "Pause combat", "Bottom Resume restarts playback")
	await game.playback.monster_resolved
	game.action.pressed.emit()
	check(game.block_bar.get_value_text() == "4 / 8" and is_equal_approx(game.block_bar.value / game.block_bar.max_value, 0.5), "Four damage halves eight-block bar and retains denominator")
	check(game.board.failed_activations.is_empty(), "Preview of an unaffordable spell does not flash without an attempt")
	game.action.pressed.emit()
	await game.playback.player_resolved
	game.action.pressed.emit()
	check(game.run.pending_turn["dormant_ids"].has(spell["id"]), "Second action attempts unaffordable spell")
	check(game.board.failed_activations.has(spell["id"]), "Actual failed attempt starts item pulse")
	var pulse_before: Dictionary = game.board.failed_activations.duplicate()
	await create_timer(0.2).timeout
	check(game.board.failed_activations == pulse_before, "Pause freezes red pulse with combat")
	game.front.settings["flash"] = false
	game._settings_changed()
	check(game.board.failed_activations.is_empty(), "Disabling flashes clears item feedback")
	game._player_resolved(game.run.pending_turn)
	check(game.board.failed_activations.is_empty(), "Flash preference suppresses failed-activation feedback")
	game.front.settings["flash"] = true
	game._player_resolved(game.run.pending_turn)
	game.board.set_activation_feedback_paused(true)
	game.board._process(1.0)
	check(not game.board.failed_activations.is_empty(), "Feedback clock honors pause")
	game.board.set_activation_feedback_paused(false)
	game.board._process(1.0)
	check(game.board.failed_activations.is_empty(), "Feedback expires after resuming")
	game.start_run("warrior", 42)
	check(not game.playback.active and game.action.accessibility_name == "Attack" and not game.action.disabled, "New encounter restores Attack")
	check(game.board.failed_activations.is_empty() and not game.board.activation_feedback_paused, "New run clears stale item feedback")
	# Finish the last floor to exercise the real finish signal without descent.
	game.run.fight = PackRun.FLOORS - 1
	game.run.enemy["hp"] = 1
	game.run.enemy["armor"] = 0
	game.run.enemy["opening_armor"] = 0
	game._act()
	await game.playback.fight_finished
	check(game.action.accessibility_name == "Attack" and game.action.disabled, "Finished battle restores Attack glyph without starting another attack")
	report("COMBAT CONTROLS/RESOURCES RESULT")
	await preload("res://tests/support/automatic_combat_cleanup.gd").release(self, game)
	quit(1 if failures else 0)

func _capacity_checks() -> void:
	var state: PackRun = fixture("warrior")
	state.items.clear()
	var focus: Dictionary = state.add_item("spark_ring", Vector2i.ZERO)
	focus["mana"] = 6
	focus["mana_per_round"] = 5
	var spell: Dictionary = state.add_item("ember_tome", Vector2i(1, 0))
	spell["cost"] = 4
	var shield: Dictionary = state.add_item("buckler", Vector2i(4, 0))
	shield["block"] = 8
	shield["block_per_round"] = 2
	state.enemy["hp"] = 1000
	state.enemy["max_hp"] = 1000
	state.enemy["attacks"] = [4]
	check(state.start_combat() and state.mana_capacity == 6 and state.block_capacity == 8, "Combat initializes capacities from starting items")
	state.begin_turn()
	check(state.mana == 7 and state.mana_capacity == 11, "Mana capacity includes explicit regeneration before spell spending")
	check(state.block == 10 and state.block_capacity == 10, "Explicit block gain expands capacity")
	state.complete_turn()
	check(state.block == 6 and state.block_capacity == 10, "Enemy damage preserves greatest block capacity")
	state.effects()
	check(state.mana_capacity == 11 and state.block_capacity == 10, "Inspecting next-turn effects does not change capacities")
	state.begin_turn()
	check(state.block == 8 and state.block_capacity == 10, "Regeneration below the previous peak keeps block denominator stable")
	state.complete_turn()
	state.prepare_enemy()
	check(state.mana_capacity == 0 and state.block_capacity == 0, "Next encounter clears previous capacities")
	state.items.clear()
	state.start_combat()
	check(state.mana_capacity == 0 and state.block_capacity == 0, "Empty pools keep honest zero capacities")
	var furnace: PackRun = fixture("warrior")
	furnace.items.clear()
	furnace.relics.append("mana_furnace")
	furnace.add_item("spark_ring", Vector2i.ZERO)["mana"] = 6
	furnace.start_combat()
	furnace.begin_turn()
	check(furnace.mana == 0 and furnace.mana_capacity == 6, "Mana conversion preserves the initial mana denominator")
	check(furnace.block == 12 and furnace.block_capacity == 12, "Explicit furnace block conversion expands block capacity")
