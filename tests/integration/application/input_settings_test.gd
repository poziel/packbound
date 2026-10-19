extends "res://tests/support/prototype_support.gd"

const KEYS = preload("res://systems/application/keybindings.gd")

func press(code: int, ctrl: bool = false, shift: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	event.ctrl_pressed = ctrl
	event.shift_pressed = shift
	return event

func _run() -> void:
	var old := ConfigFile.new()
	old.set_value("options", "resolution", 2)
	old.set_value("keybinds", "pause", KEY_F8)
	check(old.save("user://packbound_settings.cfg") == OK, "Isolated preferences can be saved")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var menu: PackMenuFlow = game.front
	check(KEYS.normalize(menu.keybindings.pause).key == KEY_F8, "Legacy integer shortcut survives migration")
	check(menu.SIZES[menu.settings.resolution] == Vector2i(1920, 1080), "Legacy resolution retains dimensions")
	check(not InputMap.has_action("pack_inspect") and not InputMap.has_action("pack_rotate_alternate"), "Obsolete actions removed")
	check(not KEYS.matches(press(KEY_R), "rotate_right") and KEYS.matches(press(KEY_E), "rotate_right"), "Only E rotates right by default")
	for index in range(menu.SIZES.size()):
		var dimensions: Vector2i = menu.SIZES[index]
		check(dimensions.x * 9 == dimensions.y * 16, "Every size has exact 16:9 ratio")
		if index > 0: check(dimensions.x > menu.SIZES[index - 1].x, "Sizes increase monotonically")
	menu.show_options()
	check(menu.binding_buttons.size() == KEYS.DEFAULTS.size(), "Every action exposes a binding and reset")
	check(menu.binding_resets.pause.disabled == false and menu.binding_resets.primary.disabled, "Reset enabled only for changed binding")
	menu._reset_keybind("pause")
	check(menu.binding_resets.pause.disabled and KEYS.matches(press(KEY_ESCAPE), "pause"), "Individual reset applies immediately")
	menu._begin_keybind("priority_up")
	menu._input(press(KEY_F5, true, true))
	check(KEYS.matches(press(KEY_F5, true, true), "priority_up") and not KEYS.matches(press(KEY_F5), "priority_up"), "Modifier combination matches exactly")
	menu._begin_keybind("craft_lock")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_MIDDLE
	mouse.pressed = true
	mouse.alt_pressed = true
	menu._input(mouse)
	check(KEYS.matches(mouse, "craft_lock"), "Mouse button with modifier can be captured")
	menu._load_settings()
	KEYS.apply(menu.keybindings)
	check(KEYS.matches(mouse, "craft_lock") and KEYS.matches(press(KEY_F5, true, true), "priority_up"), "Keyboard and mouse combinations survive reload")
	menu._begin_keybind("primary")
	menu._input(press(KEY_F11))
	check(menu.capturing_action == "primary", "Fullscreen key stays reserved")
	menu._input(press(KEY_ESCAPE))
	check(menu.capturing_action.is_empty() and KEYS.normalize(menu.keybindings.primary).key == KEY_SPACE, "Escape cancels capture")
	menu._set_option("name_display", 1)
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/warrior/character.json"))
	check(menu.player_name("warrior") == profile.name, "Delver name comes from authored identity")
	check(not menu.settings.has("character_name"), "No custom player-name setting")
	menu._set_option("turn_based_combat", true)
	menu._load_settings()
	check(menu.settings.turn_based_combat and game.playback.turn_based, "Round pacing setting persists and reaches playback")
	if DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute("res://workspace/reviews/input-settings")
		menu._set_option("resolution", 2)
		for tab in [0, 1, 3]:
			menu.option_tabs.current_tab = tab
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://workspace/reviews/input-settings/options-%d.png" % tab)
	game.start_run("warrior", 42)
	game.waiting_at_entrance = false
	game.run.phase = PackRun.Phase.FIGHT
	game.run.items.clear()
	game.run.relic_offers.clear()
	game.run.enemy.hp = 1000
	game.run.enemy.max_hp = 1000
	var item: Dictionary = game.run.add_item("rusty_knife", Vector2i.ZERO)
	game._refresh()
	game.board.pointer = game.board.item_rect(item).get_center()
	var priority: int = int(item.get("priority", 0))
	check(game.board._item_shortcut(press(KEY_F5, true, true)), "Rebound priority action targets hovered item")
	check(int(item.get("priority", 0)) != priority, "Priority action changes the hovered item")
	check(game.board.focus_mode == Control.FOCUS_NONE, "Inventory has no keyboard focus")
	game.inspector.clear()
	game.inspector.enabled = true
	game.inspector.source = game.board
	game.inspector.source_rect = game.board.item_rect(item)
	game.inspector.source_rect.position += game.board.global_position
	game.inspector.pointer = game.inspector.source_rect.get_center()
	game.inspector._spawn({"key": "quick_test", "title": "Quick inspection", "body": "Item preview"}, game.inspector.source_rect, -1)
	Input.parse_input_event(press(KEY_SHIFT))
	Input.flush_buffered_events()
	check(KEYS.held("quick_inspect"), "Quick inspect hold is active")
	game.inspector._process(5.0)
	check(not game.inspector.windows[0].locked and game.inspector.windows[0].age == 0.0, "Held quick inspect never locks even after delay")
	game.inspector.pointer = Vector2.ZERO
	game.inspector._process(0.01)
	check(game.inspector.windows.is_empty(), "Quick preview disappears immediately when leaving item")
	var release := press(KEY_SHIFT)
	release.pressed = false
	Input.parse_input_event(release)
	for pair in [[KEY_F2, "Relics"], [KEY_F3, "Statistics"], [KEY_F4, "Logs"], [KEY_F1, "Backpack"]]:
		check(game._game_shortcut(press(pair[0])) and game.character_tabs.get_current_tab_control().name == pair[1], "Panel shortcut opens " + pair[1])
	for code in [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5]:
		game._game_shortcut(press(code))
		check(game.board.dragging.is_empty(), "Choice shortcuts never grab backpack items")
	game.board.cancel_drag()
	check(game._game_shortcut(press(KEY_SPACE)) and game.playback.active, "Space activates primary combat action")
	game.playback.set_process(false)
	game.playback._process(10)
	game.playback._process(10)
	check(game.playback.waiting_for_round and not game.action.disabled, "Round wait keeps primary action available")
	game._game_shortcut(press(KEY_SPACE))
	check(game.run.total_turns == 2, "Space starts the next round")
	game.playback.cancel()
	game.busy = false
	game.run.combat_state = PackRun.CombatState.PREPARING
	game.run.pending_turn.clear()
	game._refresh()
	check(game._game_shortcut(press(KEY_B)) and game.storage.visible, "Stash shortcut opens stash")
	var stash_item: Dictionary = game.run.add_item("bandage")
	game._refresh()
	game._game_shortcut(press(KEY_1))
	check(stash_item.cell == null and game.storage.grabbed == null, "Choice shortcuts never transfer stash items")
	game._game_shortcut(press(KEY_B))
	check(not game.storage.visible, "Stash shortcut closes stash")
	game.run.relic_rewards.assign([0])
	game.run.relic_offers.assign(["diagonal_thread"])
	game._refresh()
	check(game._game_shortcut(press(KEY_L)) and game.modal_kind == "reward" and game.reward_is_relic, "Relic reward shortcut opens chooser")
	game._game_shortcut(press(KEY_L))
	check(not game.modal.visible, "Reward shortcut toggles chooser closed")
	game._game_shortcut(press(KEY_L))
	menu._swap_binding("select_1", KEY_F9)
	KEYS.apply(menu.keybindings)
	game._game_shortcut(press(KEY_1))
	check(not game.run.relics.has("diagonal_thread"), "Old choice key stops selecting after rebinding")
	game._game_shortcut(press(KEY_F9))
	check(game.run.relics.has("diagonal_thread"), "Rebound choice shortcut chooses reward")
	var playback := PackCombatPlayback.new()
	root.add_child(playback)
	playback.set_process(false)
	var state := fixture("warrior")
	state.items.clear()
	state.phase = PackRun.Phase.FIGHT
	state.enemy.hp = 1000
	state.enemy.max_hp = 1000
	state.add_item("rusty_knife", Vector2i.ZERO)
	playback.turn_based = true
	check(playback.start(state, 1.0, 0.3, 0.28), "Round-based fight starts")
	playback._process(10)
	playback._process(10)
	check(playback.waiting_for_round and state.total_turns == 1 and not state.can_edit_inventory(), "After full round combat waits and inventory stays locked")
	playback._process(100)
	check(state.total_turns == 1, "Time alone cannot start next round")
	var snapshot: Dictionary = playback.snapshot()
	check(snapshot.waiting_for_round and snapshot.turn_based, "Save checkpoint records round wait")
	playback.restore(state, snapshot)
	check(playback.waiting_for_round and playback.paused, "Saved round wait restores safely paused")
	playback.set_paused(false)
	playback.advance_round()
	check(state.total_turns == 2 and not playback.waiting_for_round, "Attack advances exactly one round")
	playback._process(10)
	playback._process(10)
	playback.set_paused(true)
	playback.turn_based = false
	playback.set_paused(false)
	check(state.total_turns == 3 and not playback.waiting_for_round, "Disabling round pacing while paused resumes automatic combat")
	playback.cancel()
	playback.queue_free()
	await preload("res://tests/support/automatic_combat_cleanup.gd").release(self, game)
	report("INPUT SETTINGS RESULT")
	quit(1 if failures else 0)
