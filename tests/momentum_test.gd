extends "res://tests/prototype_test.gd"

func _run() -> void:
	var state: PackRun = fixture()
	state.enemy["hp"] = 1000
	state.enemy["max_hp"] = 1000
	state.enemy["attacks"] = [0]
	check(state.momentum == 0, "Fight starts empty")
	state.start_combat()
	for index in range(10):
		state.outcome(state.effects())
	check(state.momentum == 0, "Previews cannot generate Momentum")
	state.begin_turn()
	check(state.momentum == 0, "Player checkpoint does not award Momentum")
	var saves := PackRunSaves.new()
	var restored := PackRun.new()
	saves.restore(restored, saves.capture(state, 0))
	restored.complete_turn()
	check(restored.momentum == 1, "Mid-response save awards exactly once on completion")
	state.complete_turn()
	state.complete_turn()
	check(state.momentum == 1, "Completion grants exactly one")
	state.momentum_gain_bonus = 2
	state.end_turn()
	check(state.momentum == 4, "Gain modifier adds to base growth")
	check(not state.spend_momentum(5) and state.momentum == 4, "Unaffordable spending preserves resource")
	state.momentum_cost_reduction = 1
	check(state.spend_momentum(3) and state.momentum == 2, "Cost reduction retains unspent Momentum")
	state.combat_state = PackRun.CombatState.PAUSED
	check(not state.spend_momentum(1) and state.momentum == 2, "Paused resource cannot be spent")
	state.combat_state = PackRun.CombatState.RUNNING
	state.momentum_gain_bonus = 0
	state.end_turn()
	check(state.momentum == 3, "Growth resumes after spending")
	state.prepare_enemy()
	check(state.momentum == 0, "Next encounter resets Momentum")
	state.reset(42, "ranger")
	state.enemy["hp"] = 1000
	state.enemy["attacks"] = [0]
	state.end_turn()
	check(state.momentum == 0 and not state.spend_momentum(0), "Other Delvers cannot gain or spend Momentum")
	state = fixture()
	state.enemy["hp"] = 1
	state.end_turn()
	check(state.momentum == 0, "Killing opening action has no completed exchange")
	state = fixture()
	state.enemy["hp"] = 1000
	state.enemy["attacks"] = [1]
	var result: Dictionary = state.end_turn()
	check(result["retaliation"] == 0, "Warrior no longer counterattacks with Riposte")
	var old_save: Dictionary = saves.capture(state, 0)
	old_save["state"].erase("momentum")
	restored.momentum = 99
	saves.restore(restored, old_save)
	check(restored.momentum == 0, "Legacy saves initialize new resource safely")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.run.reset(42, "warrior")
	game.run.momentum = 7
	game._refresh()
	await process_frame
	check(game.momentum_bar.visible and game.momentum_bar.value == 7 and game.momentum_bar.max_value > 7, "Warrior meter displays uncapped Momentum with growing scale")
	check(game.momentum_bar.position.x >= game.stamina_bar.position.x + game.stamina_bar.size.x, "Momentum meter does not overlap stamina")
	game.run.reset(42, "ranger")
	game._refresh()
	check(not game.momentum_bar.visible, "Momentum meter is exclusive to Warrior")
	game.queue_free()
	await process_frame
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
