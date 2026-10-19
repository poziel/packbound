extends "res://tests/battle_ui_test.gd"

func _run() -> void:
	render = DisplayServer.get_name() != "headless"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.run_saves.directory = "res://workspace/logs/deferred-reward-saves"
	game.start_run("warrior", 42)
	check(game.run.phase == PackRun.Phase.FIGHT and not game.modal.visible, "Starting relic does not block combat")
	check(game.run.relic_rewards == [1] and not game.relic_reward_button.disabled, "Starting relic remains claimable from its icon")
	var first_relics: Array = game.run.relic_offers.duplicate()
	game._open_reward(true)
	game._close_modal()
	check(game.run.relic_offers == first_relics and game.run.relic_rewards.size() == 1, "Closing a relic choice preserves its offers and entitlement")
	game.front.settings["combat_speed"] = 4
	game.run.hp = 30
	game.run.enemy["hp"] = 1
	game._act()
	game._open_reward(true)
	check(not game.modal.visible, "Reward selection cannot interrupt an attack or descent")
	await _wait_for_action()
	check(game.run.fight == 0 and game.run.phase == PackRun.Phase.SELECTOR and not game.modal.visible, "Winning enters the selector without choosing an item")
	game._door_chosen("combat")
	await _wait_for_action()
	check(game.run.hp == 30 and game.run.items.size() == 3, "Combat does not recover health when winning or claiming an item")
	var first_items: Array = game.run.offers.duplicate()
	_click(game.item_reward_button)
	check(game.modal.visible and game.reward_close_button.visible, "Item icon opens a dismissible selection")
	await _snapshot("deferred-rewards-chooser")
	_key(KEY_ESCAPE)
	check(not game.modal.visible and game.run.item_rewards.size() == 1, "Escape closes the chooser without consuming its claim")
	for index in range(3):
		game.run.enemy["hp"] = 1
		game.run.hp = game.run.max_hp
		game._act()
		await _wait_for_action()
		game._door_chosen("combat")
		await _wait_for_action()
	check(game.run.fight == 4 and game.run.item_rewards.size() == 4 and game.run.relic_rewards == [1], "Four unclaimed items accumulate; future relics come from rooms")
	check(game.run.offers == first_items and game.run.relic_offers == first_relics, "Later fights do not reroll deferred choices")
	check(game.item_reward_button.get_node("Badge") is TextureRect and game.item_reward_button.get_node("Badge").visible, "Item alert uses custom artwork without a numeric counter")
	check(game.relic_reward_button.get_node("Badge") is TextureRect and game.relic_reward_button.get_node("Badge").visible, "Relic alert uses custom artwork without a numeric counter")
	check(not game.item_reward_button.tooltip_text.contains("4") and not game.relic_reward_button.accessibility_name.contains("2"), "Reward labels do not reveal pending choice counts")
	var item_rect: Rect2 = game.item_reward_button.get_rect()
	var relic_rect: Rect2 = game.relic_reward_button.get_rect()
	check(relic_rect.position.x - item_rect.end.x < game.storage_button.position.x - relic_rect.end.x, "Reward buttons are grouped more tightly than unused items")
	await _snapshot("deferred-rewards-banked")
	var old_enemy: Dictionary = game.run.enemy.duplicate(true)
	var old_hp: int = game.run.hp
	game._open_reward(false)
	for index in range(4):
		check(game.modal.visible, "Next item choice remains open until the queue is exhausted")
		_click(game.choice_buttons[0])
		if index == 0:
			var next_offers: Array = game.run.offers.duplicate()
			await _snapshot("reward-refinement-next-choice")
			game._close_modal()
			check(game.run.item_rewards.size() == 3, "Closing mid-sequence keeps all remaining item choices")
			game._open_reward(false)
			check(game.run.offers == next_offers, "Reopening mid-sequence preserves the next offers")
	game._choose(0)
	check(game.run.items.size() == 7 and game.run.item_rewards.is_empty() and not game.modal.visible, "Sequential choices grant one item each and close after the last choice")
	check(game.run.enemy == old_enemy and game.run.hp == old_hp and game.run.turn == 1 and not game.busy, "Claims do not reset combat, heal, or replay descent")
	check(game.item_reward_button.disabled and not game.item_reward_button.get_node("Badge").visible, "Empty item claims disable their icon and clear its badge")
	game._open_reward(true)
	for index in range(1):
		check(game.modal.visible, "Next relic choice remains open until the queue is exhausted")
		_click(game.choice_buttons[0])
	check(game.run.relics.size() == 1 and game.run.relic_floors_claimed == [1], "Deferred starting relic binds once and retains its earning floor")
	game.run.prepare_enemy()
	check(game.run.relic_rewards.is_empty(), "Preparing the same milestone does not award another relic")
	game.run.fight = 19
	game.run.prepare_enemy()
	game.run.enemy["hp"] = 1
	game.run.hp = game.run.max_hp
	game._act()
	await _wait_for_action()
	check(game.run.phase == PackRun.Phase.VICTORY and game.modal.visible and game.run.item_rewards.size() == 1, "Final kill completes the run without requiring its trophy")
	game._close_modal()
	game._open_reward(false)
	game._choose(0)
	check(game.run.phase == PackRun.Phase.VICTORY and game.run.items.size() == 8, "Final trophy can still be claimed after victory")
	game.start_run("mage", 42)
	check(game.run.item_rewards.is_empty() and game.run.relic_rewards == [1] and game.run.relics.is_empty(), "New run clears old rewards and grants only its starting relic")
	var state := PackRun.new()
	state.reset(42)
	for index in range(20):
		state.enemy["hp"] = 1
		for protection: String in ["armor", "opening_armor", "cycle_armor", "parry"]:
			state.enemy[protection] = 0
		state.hp = state.max_hp
		state.end_turn()
		state.advance_encounter()
		if state.phase == PackRun.Phase.SELECTOR:
			state.choose_destination("combat")
	check(state.phase == PackRun.Phase.VICTORY and state.item_rewards.size() == 20 and state.relic_rewards == [1], "Entire combat descent can defer twenty items and its starting relic")
	for index in range(20):
		state.choose_loot(state.offers[0])
	for index in range(1):
		state.choose_relic(state.relic_offers[0])
	check(state.items.size() == 23 and state.relics.size() == 1 and state.item_rewards.is_empty() and state.relic_rewards.is_empty(), "All deferred rewards can be claimed consecutively after the final fight")
	print("DEFERRED REWARDS RESULT: %d checks, %d failures" % [checks, failures])
	await preload("res://tests/automatic_combat_cleanup.gd").release(self, game)
	quit(1 if failures else 0)
