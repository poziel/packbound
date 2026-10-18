extends "res://tests/battle_ui_test.gd"

func _run() -> void:
	create_timer(30.0).timeout.connect(func() -> void: quit(2))
	render = DisplayServer.get_name() != "headless"
	test_viewport = SubViewport.new()
	test_viewport.size = Vector2i(1280, 720)
	test_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(test_viewport)
	test_viewport.notify_mouse_entered()
	game = load("res://scenes/main.tscn").instantiate()
	test_viewport.add_child(game)
	await process_frame
	await process_frame
	game.start_run("warrior", 42)
	await process_frame
	await process_frame
	var attack_rect: Rect2 = game.action.get_global_rect()
	check(is_equal_approx(attack_rect.size.x, attack_rect.size.y), "Attack is square")
	var previous_right: float = 0.0
	for button: Button in [game.item_reward_button, game.relic_reward_button, game.action, game.storage_button]:
		var rect: Rect2 = button.get_global_rect()
		check(is_equal_approx(rect.end.y, attack_rect.end.y), "Controls share bottom baseline: %s %s vs %s" % [button.name, rect, attack_rect])
		check(rect.position.x > previous_right, "Controls have separate hit areas: " + button.name)
		previous_right = rect.end.x
		if button != game.action:
			check(is_equal_approx(attack_rect.size.x / rect.size.x, 1.75), "Attack is 1.75 times " + button.name)
	for button: Button in [game.storage_button, game.item_reward_button, game.relic_reward_button]:
		check(button.get_parent() == game.action.get_parent(), "Menu belongs to ActionFrame: " + button.name)
		check(game.action.get_parent().get_global_rect().encloses(button.get_global_rect()), "ActionFrame encloses menu: " + button.name)
	check(game.action.tooltip_text.is_empty(), "Attack has no simple tooltip")
	check(not game.inspector.sources.any(func(entry: Dictionary) -> bool: return entry["target"] == game.action), "Attack has no advanced tooltip provider")
	check(game.enemy_bar.global_position.y < 160, "Monster vitals use the freed upper area")
	await _snapshot("bottom-controls-battle")
	game._open_reward(true)
	await process_frame
	check(game.modal.visible and not game.modal.get_node("Dimmer").visible, "Relics open without a full-screen dimmer")
	check(not game.modal.get_node("DialogFrame").visible, "Rewards replace the central dialog")
	check(game.board.mouse_filter == Control.MOUSE_FILTER_STOP, "Reward choice leaves the backpack usable")
	var bay: Rect2 = game.reward_panel.get_global_rect()
	for button: Button in game.choice_buttons:
		check(bay.encloses(button.get_global_rect()), "Reward choices stay in front of monsters: %s in %s" % [button.get_global_rect(), bay])
	check(bay.end.x < game.combat.get_node("CharacterDivider").global_position.x and bay.end.y < attack_rect.position.y, "Expanded panel leaves the backpack and bottom controls clear")
	var row_rect: Rect2 = game.choice_buttons[0].get_global_rect()
	check(is_equal_approx(row_rect.position.x - bay.position.x, 24) and is_equal_approx(bay.end.x - row_rect.end.x, 24), "Reward rows have equal horizontal insets")
	check(is_equal_approx(bay.end.y - game.choice_buttons[2].get_global_rect().end.y, 24), "Reward rows retain the same bottom inset")
	check(is_equal_approx(game.choice_buttons[1].global_position.y - row_rect.end.y, game.choice_buttons[2].global_position.y - game.choice_buttons[1].get_global_rect().end.y), "Reward rows have equal gaps")
	var description: RichTextLabel = game.choice_details[0]
	var long_description: String = "After spells activate, all remaining mana becomes block at 2 block per mana. No mana is retained. ".repeat(4)
	description.set_description(long_description)
	check(description.get_line_count() <= 3 and description.get_parsed_text().ends_with("…"), "Long rich descriptions are limited to three lines with ellipsis")
	check(description.get_theme_constant("line_separation") == 0, "Reward description leading is compact")
	description.set_description(PackCatalog.relic(game.run.relic_offers[0])["detail"])
	check(game._reward_inspection(0)["body"] == PackCatalog.relic(game.run.relic_offers[0])["detail"], "Advanced reward tooltip keeps the full description")
	for key: String in PackCatalog.RELICS:
		description.set_description(PackCatalog.relic(key)["detail"])
		check(description.get_line_count() <= 3 and description.get_content_height() <= description.size.y, "Relic summary fits three complete lines: " + key)
	for key: String in PackCatalog.ROSTER:
		description.set_description(PackCatalog.item(key)["detail"])
		check(description.get_line_count() <= 3 and description.get_content_height() <= description.size.y, "Item summary fits three complete lines: " + key)
	description.set_description(PackCatalog.relic(game.run.relic_offers[0])["detail"])
	_motion(game.choice_buttons[0].get_global_rect().get_center())
	await create_timer(0.3).timeout
	check(not game.inspector.windows.is_empty() and game.inspector.windows[0].key == "reward_" + game.run.relic_offers[0], "Actual reward hover opens its advanced tooltip")
	game.inspector.clear()
	await _snapshot("bottom-controls-relics")
	_click_tab(game.character_tabs.get_tab_bar(), _tab_index("Statistics"))
	check(game.character_tabs.current_tab == _tab_index("Statistics") and game.modal.visible, "Backpack tabs accept pointer input alongside the reward panel")
	_click_tab(game.character_tabs.get_tab_bar(), _tab_index("Backpack"))
	var item: Dictionary = game.run.items.back()
	var at: Vector2 = game.board.global_position + game.board.item_rect(item).get_center()
	_motion(at)
	_mouse(at, true)
	check(not game.board.dragging.is_empty(), "Backpack accepts an actual drag while rewards are open")
	_mouse(at, false)
	game.board.cancel_drag()
	var offers: Array = game.run.relic_offers.duplicate()
	_key(KEY_ESCAPE)
	check(not game.modal.visible and game.run.relic_offers == offers, "Escape preserves deferred offers")
	game.run.roll_loot()
	game._refresh()
	_click(game.item_reward_button)
	await process_frame
	check(game.modal.visible and not game.reward_is_relic, "Bottom item button opens the item panel")
	await _snapshot("bottom-controls-items")
	var count: int = game.run.items.size()
	_click(game.choice_buttons[0])
	check(game.run.items.size() == count + 1 and not game.modal.visible, "Panel choice grants an item and closes")
	_click(game.storage_button)
	check(game.storage.visible, "Bottom storage button still opens unused items")
	check(game.storage.get_global_rect().is_equal_approx(game.reward_panel.get_global_rect()), "Unused items and rewards share expanded panel bounds")
	for index: int in range(20):
		game.run.add_item("iron_charm")["cell"] = null
	game.storage.refresh()
	await process_frame
	await process_frame
	var storage_bounds: Rect2 = game.storage.get_global_rect()
	var pile_bounds: Rect2 = game.storage.pile.get_global_rect()
	check(is_equal_approx(pile_bounds.position.x - storage_bounds.position.x, 24) and is_equal_approx(storage_bounds.end.x - pile_bounds.end.x, 24), "Physics pile has equal side padding")
	check(is_equal_approx(storage_bounds.end.y - pile_bounds.end.y, 24), "Physics pile has matching bottom padding")
	check(game.storage.bodies.size() == game.board.unpacked().size(), "All unused items have physics bodies")
	await _snapshot("bottom-controls-unused")
	game.run.add_item("iron_charm")["cell"] = null
	game.storage.refresh()
	check(game.storage.bodies.size() == game.board.unpacked().size(), "Extra unused items join the same pile")
	game._close_storage()
	game._open_reward(true)
	_click(game.reward_close_button)
	check(not game.modal.visible and game.run.relic_offers == offers, "Panel close button preserves offers")
	game._toggle_storage()
	for dimensions: Vector2i in [Vector2i(1280, 800), Vector2i(1280, 720)]:
		test_viewport.size = dimensions
		await process_frame
		await process_frame
		game.storage.refresh()
		await process_frame
		await process_frame
		check(is_equal_approx(game.storage.get_global_rect().end.y - game.storage.pile.get_global_rect().end.y, 24), "Physics pile preserves bottom padding after resize")
		for button: Button in [game.item_reward_button, game.relic_reward_button, game.storage_button]:
			check(is_equal_approx(button.get_global_rect().end.y, game.action.get_global_rect().end.y), "Controls keep their baseline at %s" % dimensions)
	_click(game.action)
	check(game.playback.active, "Square attack starts the fight")
	print("BOTTOM CONTROLS REWARDS RESULT: %d checks, %d failures" % [checks, failures])
	await preload("res://tests/automatic_combat_cleanup.gd").release(self, game, test_viewport)
	quit(1 if failures else 0)
