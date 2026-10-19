extends "res://tests/support/test_case.gd"

var game
var view: SubViewport
var confirmations := 0

func _initialize() -> void:
	if not require_isolation():
		return
	_run.call_deferred()

func mouse(down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = game.front.reset_button.get_global_rect().get_center()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	view.push_input(event, true)

func _run() -> void:
	view = SubViewport.new()
	view.size = Vector2i(1280, 800)
	root.add_child(view)
	view.notify_mouse_entered()
	game = load("res://scenes/main.tscn").instantiate()
	view.add_child(game)
	await process_frame
	game.front.show_options()
	await process_frame
	await process_frame
	var button: Button = game.front.reset_button
	button.connect("confirmed", func(): confirmations += 1)
	check(button.get("hold_seconds") == 1.2, "Reset uses the shared 1.2-second hold")
	check(button.theme_type_variation == &"DangerRightMenuButton", "Red right-hand styling retained")
	game.front._set_option("brightness", 110)
	var motion := InputEventMouseMotion.new()
	motion.position = button.get_global_rect().get_center()
	view.push_input(motion, true)
	mouse(true)
	await create_timer(0.1).timeout
	mouse(false)
	check(game.front.settings["brightness"] == 110 and confirmations == 0, "Short click does not reset options")
	mouse(true)
	await create_timer(0.65).timeout
	check(game.front.settings["brightness"] == 110 and button.get("hold_progress") > 0, "Partial hold shows progress without resetting")
	mouse(false)
	check(button.get("hold_progress") == 0.0 and confirmations == 0, "Early release cancels")
	mouse(true)
	await create_timer(1.35).timeout
	check(game.front.settings["brightness"] == 110 and confirmations == 0 and button.text.is_empty(), "Full ring arms without firing and replaces label")
	await create_timer(0.3).timeout
	check(confirmations == 0, "Continuing to hold does not fire")
	mouse(false)
	check(game.front.settings["brightness"] == 100 and confirmations == 1 and button.text == "RESET TO DEFAULT", "Release confirms once and restores label")
	game.front.options.get_node("%HoldDestructiveToggle").button_pressed = false
	var restart = game.pause_screen.get_node("%RestartButton")
	check(not button.get("hold_required") and not restart.hold_required, "Setting disables hold on both destructive actions")
	check(not button.tooltip_text.contains("Hold") and not restart.tooltip_text.contains("Hold"), "Click mode tooltips omit hold instructions")
	game.front.settings["hold_destructive_actions"] = true
	game.front._load_settings()
	check(not game.front.settings["hold_destructive_actions"], "Preference persists in saved settings")
	game.front._set_option("brightness", 110)
	mouse(true)
	await create_timer(0.05).timeout
	check(game.front.settings["brightness"] == 110, "Click mode activates on release like a normal button")
	mouse(false)
	check(game.front.settings["brightness"] == 100 and confirmations == 2, "Click mode resets once without a hold")
	check(button.get("hold_required") and restart.hold_required, "Reset defaults restores hold protection")
	game.front._set_option("hold_destructive_actions", false)
	game.start_run("warrior", 42)
	game.run.total_turns = 5
	game._open_pause_menu()
	await process_frame
	await process_frame
	var restart_confirmations := [0]
	restart.confirmed.connect(func(): restart_confirmations[0] += 1)
	motion.position = restart.get_global_rect().get_center()
	view.push_input(motion, true)
	var click := InputEventMouseButton.new()
	click.position = motion.position
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	view.push_input(click, true)
	click = click.duplicate()
	click.pressed = false
	view.push_input(click, true)
	while game.loading_screen.active:
		await process_frame
	check(restart_confirmations[0] == 1 and game.run.total_turns == 0, "Restart click starts a fresh run exactly once")
	check(restart.theme_type_variation == &"LeftMenuButton" and button.theme_type_variation == &"DangerRightMenuButton", "Both button appearances remain unchanged")
	game.front._set_option("hold_destructive_actions", true)
	print("OPTIONS RESET HOLD: 16 checks, %d failures" % failures)
	await preload("res://tests/support/automatic_combat_cleanup.gd").release(self, game, view)
	report("options_reset_hold")
	quit(1 if failures else 0)
