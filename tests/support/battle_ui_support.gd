extends "res://tests/support/prototype_support.gd"

var test_viewport: SubViewport

func _check_character_header(expected: bool) -> void:
	for control in [game.character_portrait, game.hp_bar, game.mana_bar, game.block_bar]:
		check(control.is_visible_in_tree() == expected, "Character header visibility: " + control.name)

func _click_tab(bar: TabBar, index: int) -> void:
	var at: Vector2 = bar.global_position + bar.get_tab_rect(index).get_center()
	_motion(at)
	_mouse(at, true)
	_mouse(at, false)

func _keyword_link_at(window: PackInspectWindow, term: String) -> Vector2:
	# Exercise native rich-text hit testing; scan only the paragraph's own bounds.
	var rect: Rect2 = window.body.get_global_rect()
	for y in range(8, int(rect.size.y), 8):
		for x in range(8, int(rect.size.x), 6):
			var at: Vector2 = rect.position + Vector2(x, y)
			_motion(at)
			if game.inspector.active_keyword_link == term and game.inspector.active_parent == game.inspector.windows.find(window):
				return at
	check(false, "Keyword link is hoverable: " + term)
	return rect.position

func _motion(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	_input_viewport().push_input(event, true)

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	_input_viewport().push_input(event, true)
	event = InputEventKey.new()
	event.keycode = code
	event.pressed = false
	_input_viewport().push_input(event, true)

func _input_viewport() -> Viewport:
	return test_viewport if is_instance_valid(test_viewport) and game.get_parent() == test_viewport else root

func _mouse(at: Vector2, pressed: bool, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = button
	event.pressed = pressed
	_input_viewport().push_input(event, true)

func _snapshot(filename: String) -> void:
	await process_frame
	await process_frame
	if not render:
		return
	await RenderingServer.frame_post_draw
	var picture: Image = _input_viewport().get_texture().get_image()
	check(not picture.is_empty(), "Rendered: " + filename)
	picture.save_png(preload("res://tests/support/artifact_paths.gd").path("%s.png") % filename)
