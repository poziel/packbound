extends SceneTree

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void:
	_run.call_deferred()

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	for i in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.tmp/death-" + name + ".png")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	game.start_run("warrior", 42)
	var gameplay_theme: Theme = load("res://themes/gameplay/theme.tres")
	check(gameplay_theme.get_stylebox("grabber", "VScrollBar").get_script() == load("res://components/icon_button/log_scrollbar_style.gd"), "Default vertical scrollbar uses slim style")
	check(gameplay_theme.get_stylebox("grabber", "HScrollBar").horizontal, "Default horizontal scrollbar uses horizontal slim style")
	check(game.stage_number.get_theme_font_size("font_size") == game.history_view.get_theme_font_size("normal_font_size"), "Footer and log text sizes match")
	check(game.settings_button.theme_type_variation == &"IconButton", "Settings uses shared icon-button theme")
	check(not game.settings_button.has_theme_color_override("icon_hover_color"), "Settings inherits interaction colors")
	for arrow: Button in [game.previous_stage, game.next_stage, game.result_log.get_node("Navigation/Previous"), game.result_log.get_node("Navigation/Next")]:
		for state: String in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
			check(arrow.get_theme_stylebox(state) is StyleBoxEmpty, "Log arrows have no frame in " + state)
		check(arrow.get_theme_color("icon_normal_color").is_equal_approx(Color(0.843137, 0.729412, 0.494118, 1)), "Log arrows inherit accent yellow")
		check(arrow.get_theme_constant("icon_max_width") == 20 and arrow.custom_minimum_size == Vector2(48, 48), "Log arrows have larger glyphs and targets")
		check(arrow.get_theme_color("icon_hover_color").v > arrow.get_theme_color("icon_normal_color").v, "Hover lightens only the icon")
		check(arrow.get_theme_color("icon_focus_color").v < arrow.get_theme_color("icon_normal_color").v, "Focus darkens only the icon")
	for history: RichTextLabel in [game.history_view, game.result_log.get_node("History")]:
		check(history.get_v_scroll_bar().theme_type_variation == &"LogScrollBar", "Both logs share subtle scrollbar")
	game.run_saves.directory = "user://victory-panel-test-%d" % Time.get_ticks_usec()
	game.run.phase = PackRun.Phase.VICTORY
	game.elapsed = 328.0
	game.front.settings["name_display"] = 0
	game.front.settings["show_run_time"] = true
	game._show_phase_modal()
	check(not game.close_button.visible, "Victory has no X")
	check(game.modal_body.get_parsed_text() == "Cleared the last floor as the Warrior in 05:28", "Victory class and enabled time")
	var record: Label = game.modal.get_node("DeathScreen/LowestFloor")
	check(record.visible and record.text == "New record!", "First victory displays record below summary")
	await capture("victory-record")
	game.front.settings["name_display"] = 1
	game.front.settings["character_name"] = "Mira"
	game.front.settings["show_run_time"] = false
	game._show_phase_modal()
	check(game.modal_body.get_parsed_text() == "Cleared the last floor as Mira", "Victory custom name without time or reward reminder")
	var previous: Dictionary = game.run_saves.capture(game.run, 300.0)
	game.run_saves.write("previous-winner", previous)
	game._show_phase_modal()
	check(not record.visible, "Slower victory does not claim a record")
	check(not game.run_saves.is_victory_record(300.0), "Equal time does not claim a record")
	check(game.run_saves.is_victory_record(299.0), "Faster victory is a record")
	check(game.run_saves.is_victory_record(300.0, "previous-winner"), "Current save is excluded on reopening the result")
	await capture("victory-no-time")
	game.run.phase = PackRun.Phase.DEFEAT
	game.run.fight = 3
	game.run.hp = 0
	game._refresh()
	game.elapsed = 328.0
	game.front.settings["name_display"] = 0
	game.front.settings["show_run_time"] = true
	game._show_phase_modal()
	check(game.modal.get_node("DeathScreen").is_visible_in_tree(), "Death uses its full-screen scene")
	check(not game.modal.get_node("DialogFrame").visible and not game.modal.get_node("Dimmer").visible, "Death has no floating frame or dimmer")
	check(game.modal_title.text == "The satchel fall silent", "Requested death title")
	check(game.modal_body.get_parsed_text() == "Died as the Warrior on floor 4 in 05:28", "Class, floor and time")
	await capture("with-time")
	game.front.settings["name_display"] = 1
	game.front.settings["character_name"] = "Mira"
	game.front.settings["show_run_time"] = false
	game._settings_changed()
	game._show_phase_modal()
	check(game.modal_body.get_parsed_text() == "Died as Mira on floor 4", "Custom name without time")
	check(not game.timer_label.visible, "Timer setting hides HUD time")
	check(game.result_buttons.size() == 3, "Three result actions")
	if game.result_buttons.size() == 3:
		await process_frame
		var center: Button = game.result_buttons[1]
		check(absf(center.get_global_rect().get_center().x - 640.0) < 1, "New descent is centered on screen")
		for i in range(3):
			check(game.result_buttons[i].get_theme_stylebox("normal").ends == [1, 3, 2][i], "Outer decoration and plain center")
		await capture("no-time")
		game.result_buttons[0].pressed.emit()
		check(game.modal_kind == "result_log", "Battle log opens")
		check(game.modal.get_node("LogTitle").is_visible_in_tree(), "Battle log has a dedicated header")
		check(game.close_button.get_global_rect().end.y < game.result_log.get_global_rect().position.y, "Header separates X from log content")
		check(game.close_button.is_visible_in_tree() and game.close_button.size == Vector2(40, 40), "Small close control remains available")
		check(game.modal.get_node("ResultLog/History").text == game.history_view.text, "Same combat log content")
		game.run.stage_history.append({"number": 2, "name": "Test monster", "lines": ["A second encounter."], "action_starts": []})
		game._refresh_history()
		game.result_log.get_node("Navigation/Previous").pressed.emit()
		check(game.result_log.get_node("Navigation/StageNumber").text == "Stage 01", "Previous stage works in result log")
		game.result_log.get_node("Navigation/Next").pressed.emit()
		check(game.result_log.get_node("History").get_parsed_text() == "A second encounter.", "Next stage works in result log")
		await capture("battle-log")
		if DisplayServer.get_name() != "headless":
			game.result_log.get_node("History").text = "\n[hr width=100% height=2 color=#394855]\n".join(PackedStringArray(Array(range(35)).map(func(i): return "Combat event %d: the descent continues." % i)))
			var motion := InputEventMouseMotion.new()
			motion.position = game.result_log.get_node("Navigation/Previous").get_global_rect().get_center()
			root.push_input(motion)
			await capture("log-controls-hover")
		game.close_button.pressed.emit()
		check(game.modal_kind == "result", "X returns to full-screen death screen")
		game.result_buttons[0].pressed.emit()
		var escape := InputEventKey.new()
		escape.keycode = KEY_ESCAPE
		escape.pressed = true
		game._input(escape)
		check(game.modal_kind == "result" and game.modal.get_node("DeathScreen").is_visible_in_tree(), "Escape returns to death screen")
		game.result_buttons[1].pressed.emit()
		await game.loading_screen.finished
		check(game.run.class_key == "warrior" and game.run.phase == PackRun.Phase.FIGHT and game.run.fight == 0, "New descent restarts same class")
		game.run.phase = PackRun.Phase.DEFEAT
		game._show_phase_modal()
		game.result_buttons[2].pressed.emit()
		await game.loading_screen.finished
		check(game.front.selection.is_visible_in_tree() and not game.combat.visible, "Continue opens selection")
	game.front.settings["show_run_time"] = true
	game._settings_changed()
	check(game.timer_label.visible, "Timer can be enabled again")
	await preload("res://tests/automatic_combat_cleanup.gd").release(self, game)
	print("Death screen failures: ", failures)
	quit(1 if failures else 0)
