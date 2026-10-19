extends "res://tests/support/test_case.gd"

var confirmations := 0
var hold: Button
var viewport: SubViewport

func _initialize() -> void:
	if not require_isolation():
		return
	_run.call_deferred()

func settle() -> void:
	for i in range(4):
		await process_frame

func motion(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	viewport.push_input(event, true)

func mouse(down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = hold.get_global_rect().get_center()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	viewport.push_input(event, true)

func accept_key(down: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.pressed = down
	event.echo = echo
	viewport.push_input(event, true)

func snapshot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(preload("res://tests/support/artifact_paths.gd").path("menu-buttons/") + name + ".png")

func _run() -> void:
	# Isolate synthetic input from the user's live game and OS pointer/focus.
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	await create_timer(0.2).timeout
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var showcase: Control = load("res://themes/menu/showcase.tscn").instantiate()
	viewport.add_child(showcase)
	await settle()
	hold = showcase.get_node("Frame/Padding/Columns/Actions/Hold")
	hold.hold_seconds = 0.25
	hold.confirmed.connect(func() -> void: confirmations += 1)
	var native: Button = showcase.get_node("Frame/Padding/Columns/Actions/Native")
	check(native.get_theme_stylebox("normal") == showcase.theme.get_stylebox("normal", "Button"), "Native button inherits shared theme")
	check(not native.has_theme_stylebox_override("normal"), "No local skin override")
	check(native.get_theme_stylebox("hover") != native.get_theme_stylebox("normal"), "Distinct hover resource")
	check(showcase.theme.get_stylebox("normal", "Button").palette == showcase.theme.get_stylebox("hover", "Button").palette, "States share editable palette")
	await snapshot("normal")
	motion(native.get_global_rect().get_center())
	await settle()
	check(native.is_hovered(), "Pointer enters native button")
	await snapshot("hover")
	native.grab_focus()
	motion(Vector2(5, 5))
	await settle()
	await snapshot("focus")
	motion(hold.get_global_rect().get_center())
	mouse(true)
	await create_timer(0.08).timeout
	check(hold.hold_progress > 0, "Pointer hold advances progress")
	mouse(false)
	check(confirmations == 0 and hold.hold_progress == 0, "Early release cancels")
	mouse(true)
	await create_timer(0.12).timeout
	await snapshot("holding")
	await create_timer(0.2).timeout
	check(confirmations == 0, "Full pointer hold waits for release")
	await create_timer(0.3).timeout
	check(confirmations == 0, "Long hold remains armed")
	mouse(false)
	check(confirmations == 1, "Release confirms exactly once")
	mouse(true)
	await create_timer(0.05).timeout
	motion(Vector2(5, 5))
	await create_timer(0.3).timeout
	check(confirmations == 1 and hold.hold_progress == 0, "Leaving button cancels")
	mouse(false)
	hold.grab_focus()
	accept_key(true)
	await create_timer(0.12).timeout
	accept_key(true, true)
	await create_timer(0.2).timeout
	check(confirmations == 1, "Keyboard hold and key-repeat wait for release")
	accept_key(false)
	check(confirmations == 2, "Keyboard release confirms once")
	check(hold.hold_progress == 0, "Keyboard release resets")
	accept_key(true)
	await create_timer(0.05).timeout
	native.grab_focus()
	await create_timer(0.3).timeout
	check(confirmations == 2 and hold.hold_progress == 0, "Focus loss cancels")
	accept_key(false)
	hold.grab_focus()
	accept_key(true)
	await create_timer(0.05).timeout
	hold.disabled = true
	await create_timer(0.3).timeout
	check(confirmations == 2 and hold.hold_progress == 0, "Disabling during hold cancels")
	accept_key(false)
	hold.disabled = false
	await settle()
	hold.grab_focus()
	accept_key(true)
	await create_timer(0.05).timeout
	hold.hide()
	await create_timer(0.3).timeout
	check(confirmations == 2 and hold.hold_progress == 0, "Hiding during hold cancels")
	accept_key(false)
	hold.show()
	await settle()
	hold.grab_focus()
	accept_key(true)
	await create_timer(0.05).timeout
	hold.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await create_timer(0.3).timeout
	check(confirmations == 2 and hold.hold_progress == 0, "Application focus loss cancels")
	accept_key(false)
	# Exercise a mapped controller accept without changing project input settings.
	hold.grab_focus()
	var accept_button := InputEventJoypadButton.new()
	accept_button.button_index = JOY_BUTTON_A
	InputMap.action_add_event("ui_accept", accept_button)
	for down: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = JOY_BUTTON_A
		event.pressed = down
		viewport.push_input(event, true)
		if down:
			await create_timer(0.35).timeout
	check(confirmations == 3, "Controller accept hold confirms")
	InputMap.action_erase_event("ui_accept", accept_button)
	showcase.queue_free()
	await settle()
	for path in ["main_menu", "options", "class_selection", "pause_screen"]:
		var scene: Control = load("res://scenes/menus/%s/%s.tscn" % [path, path]).instantiate()
		viewport.add_child(scene)
		await settle()
		for node in scene.find_children("*", "Button", true, false):
			# Options may use the gameplay theme for its form controls.
			if scene.theme == load("res://themes/menu/theme.tres") and node.get_class() == "Button" and node.theme_type_variation != &"DelverTileButton":
				check(node.get_theme_stylebox("normal").get_script() == load("res://components/ui/buttons/menu_button/menu_button_style.gd"), path + ": " + node.name + " inherits decoration")
		if path == "main_menu":
			await snapshot("main-menu")
		scene.queue_free()
		await settle()
	report("MENU BUTTON RESULT")
	quit(1 if failures else 0)
