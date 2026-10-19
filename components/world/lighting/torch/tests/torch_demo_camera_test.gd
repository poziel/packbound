extends "res://tests/support/test_case.gd"


func _initialize() -> void:
	if not require_isolation():
		return
	_run.call_deferred()


func _run() -> void:
	create_timer(10).timeout.connect(func() -> void: printerr("Camera test timed out"); quit(2))
	var demo: Node3D = load("res://components/world/lighting/torch/demo.tscn").instantiate()
	root.add_child(demo)
	await process_frame
	var camera: Camera3D = demo.get_node("Camera")
	check(camera.scene_file_path == "res://components/tools/free_camera/free_camera.tscn", "Demo instances the shared FreeCamera scene")
	check(camera.has_method("move_camera"), "Torch demo has a movable inspection camera")
	if not camera.has_method("move_camera"):
		demo.queue_free()
		await process_frame
		report("TORCH CAMERA RESULT")
		quit(1)
		return
	camera.set_process(false)
	var home: Transform3D = camera.transform
	check(camera.get_node("Controls/Hint").visible and camera.get_node("Controls/Hint").text.contains("Press Z"), "Idle hint explains how to enter fly mode")
	check(camera.projection == Camera3D.PROJECTION_PERSPECTIVE, "Free movement uses a perspective view of the 3D torches")
	camera.move_camera(Vector3(0, 0, -1), 0.5)
	check(camera.position.distance_to(home.origin) > 0.5, "Forward input moves toward the torches")
	var distance: float = camera.position.distance_to(home.origin)
	camera.reset_view()
	camera.move_camera(Vector3(1, 0, -1), 0.5)
	check(is_equal_approx(camera.position.distance_to(home.origin), distance), "Diagonal movement keeps the same speed")
	camera.reset_view()
	camera.move_camera(Vector3(0, 0, -1), 0.5, true)
	check(camera.position.distance_to(home.origin) > distance * 2.0, "Shift provides faster movement")
	camera.look_camera(Vector2(200, 100000))
	check(absf(camera.rotation.y - home.basis.get_euler().y) > 0.1 and absf(camera.rotation.x) < PI * 0.5, "Mouse look turns and clamps vertical rotation")
	camera.reset_view()
	check(camera.transform.is_equal_approx(home), "Reset returns to the original showcase framing")
	camera.move_camera(Vector3.RIGHT, 0.2)
	var reset := InputEventKey.new()
	reset.keycode = KEY_R
	reset.pressed = true
	camera._unhandled_input(reset)
	check(camera.transform.is_equal_approx(home) and not camera.flying, "R resets the view outside fly mode")
	var toggle := InputEventKey.new()
	toggle.keycode = KEY_Z
	toggle.pressed = true
	camera._unhandled_input(toggle)
	check(camera.get("flying") == true, "Z enters fly mode without holding a mouse button")
	if camera.get("flying") != true:
		demo.queue_free()
		await process_frame
		report("TORCH CAMERA RESULT")
		quit(1)
		return
	check(camera.get_node("Controls/Hint").visible and camera.get_node("Controls/Hint").text.begins_with("Flying"), "Flying shows the compact movement hint")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_RIGHT
	release.pressed = false
	camera._unhandled_input(release)
	check(camera.flying, "Fly mode stays active without holding right mouse")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	key.keycode = KEY_SPACE
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	var previous_y: float = camera.position.y
	camera._process(0.1)
	check(camera.position.y > previous_y, "Space raises the camera")
	key.pressed = false
	Input.parse_input_event(key)
	key = InputEventKey.new()
	key.physical_keycode = KEY_CTRL
	key.keycode = KEY_CTRL
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	previous_y = camera.position.y
	camera._process(0.1)
	check(camera.position.y < previous_y, "Ctrl lowers the camera")
	key.pressed = false
	Input.parse_input_event(key)
	camera._unhandled_input(toggle)
	check(not camera.flying and camera.get_node("Controls/Hint").text.contains("Press Z"), "Z exits fly mode and restores the idle hint")
	camera._unhandled_input(toggle)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	camera._unhandled_input(escape)
	check(not camera.flying and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Escape releases the pointer")
	camera._unhandled_input(toggle)
	camera._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not camera.flying and camera.get_node("Controls/Hint").text.contains("Press Z"), "Losing focus exits fly mode and restores the idle hint")
	demo.queue_free()
	await process_frame
	report("TORCH CAMERA RESULT")
	quit(1 if failures else 0)
