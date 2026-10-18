extends "res://tests/menu_test.gd"

func _run() -> void:
	create_timer(20).timeout.connect(func() -> void: quit(2))
	for relocate: bool in [false, true]:
		game = load("res://scenes/main.tscn").instantiate()
		var combat: Control = game.get_node("Combat")
		var frame: Control = combat.get_node("ActionFrame")
		var relocated_group := Control.new()
		relocated_group.name = "RelocatedMenus"
		if relocate:
			frame.add_child(relocated_group)
		else:
			relocated_group.free()
		var buttons: Array[Button] = []
		var offsets: Array[Vector4] = []
		for button_name: String in ["StorageButton", "ItemRewardButton", "RelicRewardButton"]:
			var button: Button = frame.get_node(button_name)
			buttons.append(button)
			offsets.append(Vector4(button.offset_left, button.offset_top, button.offset_right, button.offset_bottom))
			if relocate:
				button.owner = null
				button.reparent(relocated_group, false)
				button.owner = frame
		root.add_child(game)
		await process_frame
		await process_frame
		check(game.storage_button == buttons[0] and game.item_reward_button == buttons[1] and game.relic_reward_button == buttons[2], "Startup resolves the moved buttons (relocated again: %s)" % relocate)
		if game.storage_button == null or game.item_reward_button == null or game.relic_reward_button == null:
			game.queue_free()
			await process_frame
			continue
		check(game.front.home.is_visible_in_tree(), "Application opens the main menu")
		if not relocate:
			await snapshot("moved-buttons/main-menu")
		game.start_run("warrior", 42)
		await process_frame
		check(game.combat.visible and game.board.run == game.run, "Starting a run finishes gameplay initialization")
		if not relocate:
			await snapshot("moved-buttons/gameplay")
		for index in buttons.size():
			check(Vector4(buttons[index].offset_left, buttons[index].offset_top, buttons[index].offset_right, buttons[index].offset_bottom) == offsets[index], "Button layout survives startup: " + buttons[index].name)
		game.storage_button.pressed.emit()
		check(game.storage.visible, "Moved storage button opens unused items")
		game._close_storage()
		game.run.roll_loot()
		game._refresh()
		game.item_reward_button.pressed.emit()
		check(game.modal.visible and game.modal_kind == "reward" and not game.reward_is_relic, "Moved item button opens item rewards")
		game._close_modal()
		game.relic_reward_button.pressed.emit()
		check(game.modal.visible and game.modal_kind == "reward" and game.reward_is_relic, "Moved relic button opens relic rewards")
		game._close_modal()
		await preload("res://tests/automatic_combat_cleanup.gd").release(self, game)
	print("MOVED BUTTONS RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
