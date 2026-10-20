extends "res://tests/support/battle_ui_support.gd"

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	test_viewport = SubViewport.new()
	test_viewport.size = Vector2i(1280, 800)
	root.add_child(test_viewport)
	test_viewport.notify_mouse_entered()
	test_viewport.add_child(game)
	await process_frame
	game.run_saves.directory = preload("res://tests/support/artifact_paths.gd").path("legacy_godot/automatic-combat-ui-test-saves")
	game.start_run("warrior", 42)
	var frame: Control = game.combat.get_node("ActionFrame")
	check(frame.get_class() == "Control" and frame.get_child_count() == 4, "Transparent action frame groups Attack and its three menus")
	check(is_equal_approx(game.action.position.x + game.action.size.x / 2, frame.size.x / 2), "Attack centers in left bay")
	game.run.items.clear()
	for x: int in range(4):
		var item: Dictionary = game.run.add_item("spark_ring", Vector2i(x, 0))
		item[GameplayTypes.Stat.MANA] = 6
	game._refresh()
	check(game.mana_bar.value == 25 and game.mana_bar.value_label.text == "25 / 25", "Preparation shows equipment mana plus the base pool")
	for state: int in [PackRun.CombatState.RUNNING, PackRun.CombatState.PAUSED]:
		game.run.combat_state = state
		game.run.pending_turn.clear()
		game.run.mana_capacity = 24
		game.run.block_capacity = 5
		game.run.mana = 19
		game.run.block = 2
		game._refresh()
		check(game.mana_bar.value == 19 and game.mana_bar.value_label.text == "19 / 24", "Combat shows remaining mana above twelve")
		check(game.block_bar.value == 2, "Combat shows depleted block")
		var original: Array = game.run.items.duplicate(true)
		game.board.begin_drag(game.run.items[0], Vector2.ZERO)
		game.board.rotate_held()
		game.board.drop_at(Vector2.ZERO)
		check(game.board.dragging.is_empty(), "Combat rejects a new drag without pending checkpoint")
		check(game.run.items == original, "Locked drag leaves cells and rotations unchanged")
		check(game.run.mana == 19 and game.run.block == 2 and not game.run.can_claim_rewards(), "Locked edits preserve pools and reward guard")
		# A drag already held when the state changes cannot become a mutation bypass.
		game.board.dragging = game.run.items[0]
		game.board.drag_rotation = 0
		game.board.drag_shape = game.board.dragging["shape"]
		game.board.rotate_held()
		check(game.board.drag_rotation == 0, "Locked held item cannot rotate")
		game.board.drop_at(Vector2.ZERO)
		check(game.run.items == original, "Locked stale drag cannot drop")
		game.board.cancel_drag()
	game.run.combat_state = PackRun.CombatState.PAUSED
	game._refresh_history()
	check(not game.history_view.scroll_following, "Paused logs allow scrolling without automatic follow")
	game.run.combat_state = PackRun.CombatState.PREPARING
	game.board.begin_drag(game.run.items[0], Vector2.ZERO)
	check(not game.board.dragging.is_empty(), "Preparation still supports dragging")
	game.board.pointer = game.storage_button.get_global_rect().get_center() - game.board.global_position
	game._update_preview()
	check(game.mana_bar.value == 19, "Preparation resource preview reflects dragging mana out of the backpack")
	check(game.values["mana"].text == "19" and game.values["block"].text == "0", "Preparation drag-preview resource rows agree with starting-pool bars")
	game.board.cancel_drag()
	game.start_run("warrior", 42)
	game.run.relics.clear()
	game.run.enemy["hp"] = 1000
	game.run.enemy["max_hp"] = 1000
	game.run.enemy["attacks"] = [0]
	game.run.add_item("spark_ring")
	game.front.settings["combat_speed"] = 4
	game._refresh()
	game._act()
	await game.playback.monster_resolved
	check(game.run.pending_turn.is_empty() and game.playback.active, "Fixture reaches running response gap between checkpoints")
	for pause_now: bool in [false, true]:
		game.playback.set_paused(pause_now)
		var items_before: Array = game.run.items.duplicate(true)
		var rewards_before: Array = game.run.relic_rewards.duplicate(true)
		var mana_before: int = game.run.mana
		var block_before: int = game.run.block
		game.board.begin_drag(game.run.items[0], Vector2.ZERO)
		game.board.rotate_held()
		game.board.drop_at(Vector2.ZERO)
		var event := InputEventMouseButton.new()
		event.pressed = true
		event.button_index = MOUSE_BUTTON_LEFT
		game.storage._slot_input(event, 0)
		game._open_reward(true)
		game.run.choose_relic(game.run.relic_offers[0])
		check(game.board.dragging.is_empty() and game.run.items == items_before, "Response gap and pause reject board/storage mutations")
		check(game.run.relic_rewards == rewards_before and not game.modal.visible, "Response gap and pause reject saved reward selection")
		check(game.run.mana == mana_before and game.run.block == block_before, "Rejected response-gap edits preserve resources exactly")
	game.character_tabs.current_tab = _tab_index("Logs")
	await process_frame
	check(game.history_view.is_visible_in_tree() and not game.history_view.scroll_following and game.playback.paused, "Paused logs remain navigable without resuming")
	game.run.stage_history.append({"number": 2, "name": "Later stage", "lines": ["Later event"], "action_starts": []})
	game._select_log_stage(0)
	var old_text: String = game.history_view.text
	game._refresh()
	check(game.log_stage_index == 0 and game.history_view.text == old_text and not game.history_view.scroll_following, "Refresh preserves an older-stage log selection")
	for index in range(100):
		game.run.stage_history[0]["lines"].append("Paused scroll fixture event %03d" % index)
	game._refresh_history()
	await process_frame
	await process_frame
	var scrollbar: VScrollBar = game.history_view.get_v_scroll_bar()
	check(scrollbar.max_value > scrollbar.page, "Paused history fixture has a real scrollable range")
	scrollbar.value = 0
	_motion(game.history_view.get_global_rect().get_center())
	_mouse(game.history_view.get_global_rect().get_center(), true, MOUSE_BUTTON_WHEEL_DOWN)
	await process_frame
	check(scrollbar.value > 0, "Actual paused log wheel input moves RichTextLabel scrollbar")
	var offset: float = scrollbar.value
	game._refresh()
	await process_frame
	check(is_equal_approx(scrollbar.value, offset) and game.playback.paused, "Paused refresh preserves the manually scrolled offset")
	game.character_tabs.current_tab = 0
	await process_frame
	var item: Dictionary = game.run.items[0]
	_motion(game.board.global_position + game.board.item_rect(item).position + Vector2(24, 24))
	await create_timer(0.35).timeout
	check(not game.inspector.windows.is_empty() and game.inspector.windows[0].key == "item_%d" % item["id"], "Paused item supports actual hover inspection")
	check(game.playback.paused and game.run.combat_state == PackRun.CombatState.PAUSED, "Read-only inspection never resumes combat")
	await _resource_row_checks()
	game.show_menu()
	report("AUTOMATIC UI RESULT")
	await preload("res://tests/support/automatic_combat_cleanup.gd").release(self, game, test_viewport)
	quit(1 if failures else 0)


func _resource_row_checks() -> void:
	game.start_run("warrior", 42)
	game.run.relics.clear()
	game.run.items.clear()
	game.run.add_item("spark_ring", Vector2i.ZERO)[GameplayTypes.Stat.MANA] = 6
	game.run.add_item("ember_tome", Vector2i(1, 0))
	var shield: Dictionary = game.run.add_item("buckler", Vector2i(4, 0))
	shield[GameplayTypes.Stat.BLOCK] = 5
	shield["block_per_round"] = 4
	game.run.enemy["hp"] = 1000
	game.run.enemy["max_hp"] = 1000
	game.run.enemy["attacks"] = [6]
	game.front.settings["combat_speed"] = 4
	game._refresh()
	check(game.values["block"].text == "5" and game.block_bar.value == 5, "Preparation block row excludes future recurring generation")
	game._act()
	game.playback.set_paused(true)
	game._update_preview()
	check(game.run.mana == 3 and game.run.pending_turn[GameplayTypes.Stat.MANA] == 6, "Fixture pauses after mana is spent with original champion stats pending")
	check(game.values["mana"].text == "3" and game.mana_bar.value == 3, "Paused champion wait shows spent mana consistently in row and bar")
	check(game._stat_inspection("mana")["body"].begins_with("Mana: 3\n"), "Mana row inspection describes the displayed remaining pool")
	check(game.values["damage"].text == str(game.run.pending_turn[GameplayTypes.Stat.DAMAGE]), "Resource correction preserves pending damage statistics")
	game.playback.set_paused(false)
	await game.playback.monster_resolved
	game.playback.set_paused(true)
	game._update_preview()
	check(game.run.pending_turn.is_empty() and game.run.block == 3 and game.run.effects()[GameplayTypes.Stat.BLOCK] == 7, "Fixture reaches depleted block before next recurring regeneration")
	check(game.values["block"].text == "3" and game.block_bar.value == 3 and game.block_bar.max_value == 9, "Paused response gap shows depleted block consistently in row and bar")
	check(game._stat_inspection("block")["body"].begins_with("Block: 3\n"), "Block row inspection describes the displayed depleted pool")
