extends "res://tests/support/storage_ui_support.gd"

func no_focus(control: Control) -> bool:
	if control.focus_mode != Control.FOCUS_NONE or control.has_focus(): return false
	for child in control.find_children("*", "Control", true, false):
		if child.focus_mode != Control.FOCUS_NONE or child.has_focus():
			printerr("FOCUS REMAINS: %s mode %s" % [child.get_path(), child.focus_mode])
			return false
	return true

func _run() -> void:
	create_timer(35).timeout.connect(func() -> void: printerr("Hover revision timed out"); quit(2))
	render = DisplayServer.get_name() != "headless"
	test_viewport = SubViewport.new()
	test_viewport.size = Vector2i(1280, 720)
	test_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(test_viewport)
	test_viewport.notify_mouse_entered()
	game = load("res://scenes/main.tscn").instantiate()
	test_viewport.add_child(game)
	await frames(3)
	game.run_saves.directory = preload("res://tests/support/artifact_paths.gd").path("legacy_tasks/tooltip-revision/saves")
	game.start_run("warrior", 42)
	game.waiting_at_entrance = false
	game.run.items.clear()
	game.run.relics.assign(["diagonal_thread"])
	game.run.phase = PackRun.Phase.FIGHT
	var item: Dictionary = game.run.add_item("cracked_shield", Vector2i.ZERO)
	game._refresh()
	await frames(4)
	game.inspector.show_delay = 0.02
	game.inspector.lock_delay = 0.15
	var point: Vector2 = game.board.get_global_transform_with_canvas() * game.board.item_rect(item).get_center()
	_motion(point)
	await create_timer(0.08).timeout
	check(game.inspector.windows.size() == 1, "Hover opens item inspection without clicking")
	if game.inspector.windows.is_empty(): quit(1); return
	var window: PackInspectWindow = game.inspector.windows[0]
	check(not window.recipe_shortcut.visible and window.timer.visible, "Countdown precedes the recipe icon")
	await create_timer(0.2).timeout
	check(window.locked and window.recipe_shortcut.visible and not window.timer.visible, "Locked item replaces countdown with recipe icon")
	check(no_focus(window) and game.board.focus_mode == Control.FOCUS_NONE, "Item tooltip and inventory cannot receive focus")
	# Find the actual link through native pointer hover; no clicks or focus calls.
	var found: bool = false
	for line in range(window.body.get_line_count()):
		for x in [50, 80, 110, 140]:
			_motion(window.body.global_position + Vector2(x, window.body.get_line_offset(line) + 10))
			await process_frame
			if game.inspector.active_keyword_link == "block": found = true; break
		if found: break
	check(found, "Stat links respond to hover without first clicking the tooltip")
	await create_timer(0.04).timeout
	check(game.inspector.windows.size() == 2 and game.inspector.windows[1].key == "block", "Hover opens nested stat definition")
	if game.inspector.windows.size() > 1:
		var definition: PackInspectWindow = game.inspector.windows[1]
		_mouse(game.inspector.pointer, true)
		_mouse(game.inspector.pointer, false)
		check(no_focus(definition) and not definition.body.text.contains("[bgcolor="), "Clicking a stat never focuses or keyboard-highlights its definition")
	_motion(window.recipe_shortcut.get_global_rect().get_center())
	await create_timer(0.22).timeout
	check(game.inspector.windows.size() == 2 and game.inspector.windows[1].key.begins_with("crafts_"), "Recipe icon opens recipe tooltip through hover")
	if game.inspector.windows.size() > 1:
		var recipes: PackInspectWindow = game.inspector.windows[1]
		check(recipes.locked and recipes.recipe_view != null, "Recipes lock while their trigger remains hovered")
		_motion(recipes.get_global_rect().get_center())
		await create_timer(0.2).timeout
		check(recipes.locked and no_focus(recipes), "Recipe tooltip locks while hovered and all recipe controls remain unfocusable")
	if render:
		DirAccess.make_dir_recursive_absolute("res://workspace/reviews/tooltip-revision")
		await RenderingServer.frame_post_draw
		test_viewport.get_texture().get_image().save_png("res://workspace/reviews/tooltip-revision/recipe-hover.png")
	game.inspector.clear()
	var relic_data: Dictionary = game._relic_inspection(0)
	check(not relic_data.has("icon"), "Owned relic tooltip carries no artwork")
	game.inspector._spawn(relic_data, Rect2(20, 20, 80, 80), -1)
	check(not game.inspector.windows[0].get_node("Content/Header/Icon").visible, "Relic title is displayed without an icon")
	game.inspector.clear()
	game.front._set_option("turn_based_combat", true)
	game.run.enemy.hp = 1000
	game.run.enemy.max_hp = 1000
	game._act()
	game.playback.set_process(false)
	var attack_texture: Texture2D = load("res://assets/icons/actions/attack/attack.png")
	check(game.playback.active and game.action.disabled and game.action.icon == attack_texture, "Current round shows disabled Attack, never Pause")
	game._act()
	check(not game.playback.paused and game.run.total_turns == 1, "Primary action cannot pause or restart a running turn-based round")
	game.playback._process(10)
	game.playback._process(10)
	check(game.playback.waiting_for_round and not game.action.disabled and game.action.icon == attack_texture, "Completed round enables the same Attack button")
	game._act()
	check(not game.playback.waiting_for_round and game.action.disabled, "Starting next round disables Attack again")
	game.playback.turn_based = false
	game._update_action_control()
	check(not game.action.disabled and game.action.icon != attack_texture, "Automatic combat retains its pause button")
	game._act()
	check(game.playback.paused, "Automatic combat still pauses through its primary button")
	game.playback.cancel()
	game.busy = false
	game.run.pending_turn.clear()
	game.run.combat_state = PackRun.CombatState.PREPARING
	game.run.items.clear()
	game.run.add_item("rusty_knife", Vector2i.ZERO)
	game.run.add_item("rusty_knife", Vector2i.RIGHT)
	game.playback.turn_based = true
	game._act()
	check(game.playback.snapshot().crafting_wait and game.action.disabled and game.action.icon == attack_texture, "Turn-based Attack is disabled during initial crafting as well")
	game.playback.cancel()
	report("TOOLTIP HOVER REVISION")
	await preload("res://tests/support/automatic_combat_cleanup.gd").release(self, game, test_viewport)
	quit(1 if failures else 0)
