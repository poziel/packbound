extends "res://tests/battle_ui_test.gd"

func _run() -> void:
	render = DisplayServer.get_name() != "headless"
	create_timer(30).timeout.connect(func() -> void: printerr("Combat flow test timed out"); quit(1))
	_loot_placement_checks()
	game = load("res://scenes/main.tscn").instantiate()
	test_viewport = SubViewport.new()
	test_viewport.size = Vector2i(1280, 800)
	test_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(test_viewport)
	test_viewport.notify_mouse_entered()
	test_viewport.add_child(game)
	await process_frame
	game.start_run("warrior", 42)
	check(game.run.phase == PackRun.Phase.FIGHT and not game.modal.visible, "Initial relic choice is optional")
	_click(game.relic_reward_button)
	_click(game.choice_buttons[0])
	await process_frame
	check(game.run.phase == PackRun.Phase.FIGHT and game.action.text.is_empty() and game.action.accessibility_name == "Attack" and not game.action.disabled, "First encounter is immediately ready to attack")
	await create_timer(0.1).timeout
	check(game.run.turn == 1 and game.run.total_turns == 0, "Entering an encounter does not automatically spend a turn")
	var prediction: Dictionary = game.run.outcome(game.run.effects())
	game.front.settings["flash"] = true
	_click(game.action)
	_click(game.action)
	check(game.run.turn == 1 and game.run.total_turns == 1 and game.busy and game.playback.paused, "Second click pauses the first exchange without another champion action")
	check(game.run.hp == prediction["player_state"]["hp"] and game.run.enemy["hp"] == prediction["player_state"]["enemy_hp"], "First click applies only the player's part of the preview")
	_click(game.action)
	check(not game.playback.paused and game.run.total_turns == 1, "Action resumes the original exchange")
	await game.playback.monster_resolved
	game.playback.set_paused(true)
	check(game.run.hp == prediction["hp_after"], "First automatic response matches the combined outcome")
	game.start_run("warrior", 42)
	game.run.enemy["hp"] = 1
	game.run.hp = game.run.max_hp
	game._refresh()
	_click(game.action)
	await _wait_for_action()
	check(game.run.fight == 1 and not game.modal.visible, "Winning advances without opening a reward")
	var settled_turns: int = game.run.total_turns
	await create_timer(0.15).timeout
	check(game.run.combat_state == PackRun.CombatState.PREPARING and game.run.turn == 1 and game.run.total_turns == settled_turns, "Completed descent stops in preparation without touching the next enemy")
	check(game.run.item_rewards.size() == 1, "Victory banks exactly one item reward")
	var old_items: Array = game.run.items.duplicate(true)
	_click(game.item_reward_button)
	_click(game.choice_buttons[0])
	check(not game.busy and not game.gameplay_background.transitioning, "Claiming a saved reward does not replay the descent")
	check(game.run.fight == 1 and game.run.phase == PackRun.Phase.FIGHT and game.run.turn == 1, "Reward choice stays in next-room preparation")
	check(game.action.text.is_empty() and game.action.accessibility_name == "Attack" and not game.action.disabled and not game.modal.visible, "Next encounter waits for Attack")
	check(game.run.items.back()["cell"] != null and game.board.unpacked().is_empty(), "Reward button places its new item in the backpack")
	check(game.storage.bodies.is_empty(), "Auto-packed reward does not create a stashed physics item")
	for index in range(old_items.size()):
		check(game.run.items[index] == old_items[index], "Receiving loot preserves existing packed items")
	prediction = game.run.outcome(game.run.effects())
	_click(game.action)
	check(game.run.turn == 1 and game.run.enemy["hp"] == prediction["player_state"]["enemy_hp"], "First click on the next encounter attacks immediately")
	game.playback.set_paused(true)
	var frame: Control = game.combat.get_node("ActionFrame")
	check(frame.get_class() == "Control" and frame.get_child_count() == 4, "Bottom row is a transparent frame for all four controls")
	check(is_equal_approx(game.action.get_global_rect().get_center().x, frame.get_global_rect().get_center().x), "Attack centers in the left action bay")
	check(not frame.has_node("DamagePreview") and not game.has_method("_forecast_inspection"), "Forecast control and inspection are removed")
	_motion(Vector2(640, 80))
	await _snapshot("combat-flow-attack-and-loot")
	game.start_run("warrior", 42)
	# Milestone rewards remain optional.
	game.run.fight = 4
	game.run.prepare_enemy()
	game._refresh()
	game._show_phase_modal()
	check(not game.modal.visible and not game.relic_reward_button.disabled, "Milestone encounter banks a relic without interrupting combat")
	_click(game.relic_reward_button)
	_click(game.choice_buttons[0])
	check(game.run.phase == PackRun.Phase.FIGHT and game.action.text.is_empty() and game.action.accessibility_name == "Attack" and game.run.turn == 1, "Milestone relic choice needs no additional start step")
	print("COMBAT FLOW RESULT: %d checks, %d failures" % [checks, failures])
	await preload("res://tests/automatic_combat_cleanup.gd").release(self, game, test_viewport)
	quit(1 if failures else 0)

func _claim(state: PackRun, key: String) -> Dictionary:
	state.phase = PackRun.Phase.VICTORY if state.fight == PackRun.FLOORS - 1 else PackRun.Phase.FIGHT
	state.offers.assign([key])
	state.item_rewards.append({"floor": state.fight + 1, "offers": [key]})
	state.choose_loot(key)
	return state.items.back()

func _fill_except(state: PackRun, free_cells: Array[Vector2i]) -> void:
	state.items.clear()
	for y in range(PackRun.GRID.y):
		for x in range(PackRun.GRID.x):
			var cell := Vector2i(x, y)
			if not free_cells.has(cell):
				state.add_item("rusty_knife", cell)

func _loot_placement_checks() -> void:
	var state: PackRun = fixture()
	var original: Array = state.items.duplicate(true)
	var loot: Dictionary = _claim(state, "shortbow")
	check(loot["cell"] != null and state.can_place(loot, loot["cell"]), "Shaped reward is packed without overlap")
	check(loot["rotation"] == 0, "Auto-placement prefers the original orientation")
	for index in range(original.size()):
		check(state.items[index] == original[index], "Auto-placement never rearranges the existing layout")
	state = fixture()
	_fill_except(state, [Vector2i(6, 6), Vector2i(7, 6)])
	loot = _claim(state, "quiver")
	check(loot["cell"] == Vector2i(6, 6) and loot["rotation"] == 1 and loot["shape"] == Vector2i(2, 1), "Reward rotates to fit the only free horizontal space")
	check(state.can_place(loot, loot["cell"]), "Rotated placement obeys grid bounds and occupied cells")
	state = fixture()
	_fill_except(state, [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)])
	loot = _claim(state, "shortbow")
	check(loot["cell"] == Vector2i.ZERO and loot["rotation"] == 0, "Placement uses occupied mask cells, allowing interlocking shapes")
	for free_cells: Array[Vector2i] in [Array([], TYPE_VECTOR2I, "", null), Array([Vector2i(0, 0), Vector2i(3, 3), Vector2i(7, 6)], TYPE_VECTOR2I, "", null)]:
		state = fixture()
		_fill_except(state, free_cells)
		original = state.items.duplicate(true)
		loot = _claim(state, "shortbow")
		check(loot["cell"] == null and loot["rotation"] == 0, "Reward stays unused when no complete shape fits")
		check(state.items.size() == original.size() + 1, "Unplaceable reward is retained")
		for index in range(original.size()):
			check(state.items[index] == original[index], "Failed auto-placement preserves packed items")
	state = fixture()
	state.fight = PackRun.FLOORS - 1
	state.phase = PackRun.Phase.VICTORY
	loot = _claim(state, "antidote")
	check(state.phase == PackRun.Phase.VICTORY and loot["cell"] != null, "Final trophy is auto-packed before victory")
