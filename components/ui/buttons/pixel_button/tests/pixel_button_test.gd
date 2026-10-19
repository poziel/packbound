extends "res://tests/support/test_case.gd"
## Run with --headless --path . --script res://components/ui/buttons/pixel_button/tests/pixel_button_test.gd

const BUTTON: PackedScene = preload("res://components/ui/buttons/pixel_button/pixel_button.tscn")
var activations: int = 0
var behind_activations: int = 0
var viewport: SubViewport

func _initialize() -> void:
	if not require_isolation():
		return
	call_deferred("_run")


func _run() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(640, 480)
	root.add_child(viewport)
	viewport.notify_mouse_entered()
	var behind: Button = Button.new()
	behind.position = Vector2(20, 20)
	behind.size = Vector2(128, 128)
	behind.pressed.connect(func() -> void: behind_activations += 1)
	viewport.add_child(behind)
	var button: PackPixelButton = BUTTON.instantiate()
	button.position = Vector2(20, 20)
	button.size = Vector2(128, 128)
	button.text = "L"
	button.silhouette = PackPixelButton.Silhouette.MASK
	button.content_region = Rect2(0, 0.5, 1, 0.5)
	button.content_padding = Vector2i(8, 4)
	button.pressed.connect(func() -> void: activations += 1)
	viewport.add_child(button)
	await process_frame
	await process_frame
	check(button.size == Vector2(128, 128), "Content region preserves the requested button geometry")
	_click(Vector2(116, 44))
	check(activations == 0 and behind_activations == 1, "Transparent L cutout passes clicks to the control behind it")
	_click(Vector2(44, 44))
	check(activations == 1, "Occupied L arm activates the native pressed signal")
	_click(Vector2(116, 116))
	check(activations == 2, "Occupied L foot activates the button")
	button.toggle_mode = true
	_click(Vector2(44, 44))
	check(button.button_pressed, "Toggle mode selects")
	_click(Vector2(44, 44))
	check(not button.button_pressed, "Toggle mode deselects")
	button.disabled = true
	var previous: int = activations
	_click(Vector2(44, 44))
	check(activations == previous, "Disabled button blocks activation")
	button.disabled = false
	button.grab_focus()
	_key(KEY_ENTER)
	check(activations == previous + 1 and button.has_focus(), "Keyboard Enter activates the focused button")
	button.toggle_mode = false
	button.set_pressed_no_signal(false)
	button.silhouette = PackPixelButton.Silhouette.STEPPED
	button.content_region = Rect2(0, 0, 1, 1)
	button.text = ""
	var content: Control = button.get_node("Content")
	var label: Label = Label.new()
	label.text = "Custom"
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	content.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	previous = activations
	_click(Vector2(84, 84))
	check(activations == previous + 1, "A custom child with STOP cannot steal the button's click")
	check(content.mouse_behavior_recursive == Control.MOUSE_BEHAVIOR_DISABLED, "Content descendants inherit passive pointer behavior")
	var rest_position: Vector2 = content.position
	_pointer(Vector2(84, 84), true)
	button._sync_content()
	check(content.position.y == rest_position.y + button.pixel_size, "Custom content follows the pressed face")
	_pointer(Vector2(84, 84), false)
	button._sync_content()
	check(content.position == rest_position, "Custom content returns to its original position")
	var sibling: PackPixelButton = BUTTON.instantiate()
	sibling.position = Vector2(300, 20)
	viewport.add_child(sibling)
	await process_frame
	var original_color: Color = sibling.face_color
	var original_pixels: PackedByteArray = sibling.get_theme_stylebox("normal").texture.get_image().get_data()
	button.face_color = Color("854d4d")
	await process_frame
	check(sibling.face_color == original_color and sibling.get_theme_stylebox("normal").texture.get_image().get_data() == original_pixels, "Changing one instance does not recolor another")
	for shape: int in PackPixelButton.Silhouette.values():
		button.silhouette = shape
		await process_frame
		check(button.get_theme_stylebox("normal").texture.get_image().get_size() == Vector2i(button.size), "Each silhouette raster matches its UI size")
		check(button._has_point(Vector2(32, 88)), "Each example retains its occupied interior")
	button.silhouette = PackPixelButton.Silhouette.MASK
	button.shape_mask = PackedStringArray(["###", "#.#", "###"])
	await process_frame
	check(not button._has_point(Vector2(64, 64)), "A mask can contain a fully enclosed transparent hole")
	button.size = Vector2(256, 128)
	await process_frame
	check(not button._has_point(Vector2(128, 64)) and button._has_point(Vector2(230, 64)), "Resizing updates both the visible mask and hit area")
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var picture: Image = button.get_theme_stylebox(state).texture.get_image()
		check(picture.get_pixel(128, 64).a == 0, "The hole remains transparent in " + state)
	button.silhouette = PackPixelButton.Silhouette.STEPPED
	button.corner_cut = 4
	button.size = Vector2(240, 64)
	await process_frame
	check(not button._has_point(Vector2(0, 0)), "Stepped corner is not clickable")
	check(button._has_point(Vector2(120, 30)), "Stepped face is clickable")
	check(not button._has_point(Vector2(-1, 30)), "Coordinates outside the control are rejected")
	var normal: Image = button.get_theme_stylebox("normal").texture.get_image()
	var hover: Image = button.get_theme_stylebox("hover").texture.get_image()
	var disabled_image: Image = button.get_theme_stylebox("disabled").texture.get_image()
	check(normal.get_data() != hover.get_data() and normal.get_data() != disabled_image.get_data(), "Hover and disabled states have distinct pixel colors")
	check(normal.get_pixel(120, 30) == normal.get_pixel(121, 31), "Source pixels render as exact 2 by 2 blocks")
	button.size = Vector2(241, 65)
	await process_frame
	check(button.get_theme_stylebox("normal").texture.get_image().get_size() == Vector2i(241, 65), "Odd control dimensions crop the last pixel block without stretching")
	button.silhouette = PackPixelButton.Silhouette.MASK
	button.shape_mask = PackedStringArray(["#", "##"])
	await process_frame
	check(not button._get_configuration_warnings().is_empty() and button._has_point(Vector2(120, 30)), "Malformed masks fall back safely with an editor warning")
	button.silhouette = PackPixelButton.Silhouette.POLYGON
	button.shape_polygon = PackedVector2Array()
	await process_frame
	check(not button._get_configuration_warnings().is_empty() and button._has_point(Vector2(120, 30)), "Invalid polygons fall back safely with an editor warning")
	button.silhouette = PackPixelButton.Silhouette.MASK
	button.shape_mask = PackedStringArray(["#.", "##"])
	await process_frame
	var packed: PackedScene = PackedScene.new()
	check(packed.pack(button) == OK, "A configured instance packs as a native scene")
	var state: SceneState = packed.get_state()
	var serialized_skin: bool = false
	for index: int in range(state.get_node_property_count(0)):
		var property_name: String = state.get_node_property_name(0, index)
		serialized_skin = serialized_skin or property_name == "theme"
		if property_name.begins_with("theme_override_styles/"):
			var style: StyleBoxTexture = state.get_node_property_value(0, index)
			for item: Dictionary in style.get_property_list():
				if item["name"] == "texture":
					serialized_skin = serialized_skin or bool(int(item["usage"]) & PROPERTY_USAGE_STORAGE)
	check(not serialized_skin, "Generated textures are not serialized into scenes")
	var restored: PackPixelButton = packed.instantiate()
	viewport.add_child(restored)
	await process_frame
	check(restored.face_color == button.face_color and restored.shape_mask == button.shape_mask, "Saved instances retain exported color and silhouette")
	check(not restored._has_point(Vector2(200, 10)), "Restored instances rebuild their cutout hit area")
	report("PIXEL BUTTON RESULT")
	viewport.queue_free()
	await process_frame
	quit(1 if failures else 0)

func _click(at: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	viewport.push_input(motion, true)
	_pointer(at, true)
	_pointer(at, false)

func _pointer(at: Vector2, down: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	viewport.push_input(event, true)

func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = code
		event.pressed = down
		viewport.push_input(event, true)
