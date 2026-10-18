extends SceneTree
## Graphics-enabled review of the reusable staircase demo and its camera routes.

func _initialize() -> void:
	_capture.call_deferred()

func _capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var demo: Node3D = load("res://components/staircase/demo.tscn").instantiate()
	viewport.add_child(demo)
	await process_frame
	var directory := "res://tests/output/stairs/demo"
	DirAccess.make_dir_recursive_absolute(directory)
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(directory + "/overview.png")
	for role: String in ["EntranceStairs", "ExitStairs"]:
		demo.selected = demo.get_node(role)
		for progress: float in [0.0, 0.5, 1.0]:
			demo._pose(progress)
			await process_frame
			await RenderingServer.frame_post_draw
			viewport.get_texture().get_image().save_png(directory + "/%s-%02d.png" % [role, roundi(progress * 100)])
	for role: String in ["EntranceStairs", "ExitStairs"]:
		var stairs: Node3D = demo.get_node(role)
		demo.camera.global_transform = stairs.get_node("Top" if role == "EntranceStairs" else "Bottom").global_transform
		if role == "EntranceStairs":
			demo.camera.rotate_object_local(Vector3.UP, PI)
		await process_frame
		await RenderingServer.frame_post_draw
		var picture: Image = viewport.get_texture().get_image()
		picture.save_png(directory + "/%s-closed-end.png" % role)
		for pixel: Vector2i in [Vector2i(640, 400), Vector2i(440, 250), Vector2i(840, 550)]:
			var color: Color = picture.get_pixelv(pixel)
			if color.r + color.g + color.b > 0.01:
				printerr("FAIL: Stair end lets the scene background show through: " + role)
				quit(1)
				return
	# Inspect the seam from inside the formerly open gap, including side views.
	for role: String in ["EntranceStairs", "ExitStairs"]:
		var wall: Node3D = demo.get_node(role + "/EndWall")
		var directions: Array[Vector3] = [Vector3.LEFT, Vector3.RIGHT, Vector3.UP, Vector3.DOWN]
		for index: int in directions.size():
			demo.camera.global_position = wall.to_global(Vector3(0, 0, 0.8))
			var direction: Vector3 = wall.global_basis * directions[index]
			demo.camera.look_at(demo.camera.global_position + direction, wall.global_basis.z if index > 1 else Vector3.UP)
			await process_frame
			await RenderingServer.frame_post_draw
			var seam: Image = viewport.get_texture().get_image()
			seam.save_png(directory + "/%s-seam-%d.png" % [role, index])
			var color: Color = seam.get_pixel(640, 400)
			if color.r + color.g + color.b > 0.01:
				printerr("FAIL: Open gap around staircase end wall: %s view %d" % [role, index])
				quit(1)
				return
	demo.preview(demo.get_node("EntranceStairs"))
	await process_frame
	var reset := InputEventKey.new()
	reset.keycode = KEY_R
	reset.pressed = true
	viewport.push_input(reset, true)
	await process_frame
	if demo.travel.is_valid() or not demo.camera.transform.is_equal_approx(demo.camera.home):
		printerr("FAIL: Reset did not cancel staircase preview")
		quit(1)
		return
	demo.preview(demo.get_node("EntranceStairs"))
	var fly := InputEventKey.new()
	fly.keycode = KEY_Z
	fly.pressed = true
	viewport.push_input(fly, true)
	await process_frame
	if demo.travel.is_valid() or not demo.camera.flying:
		printerr("FAIL: Z did not cancel preview and enter fly mode")
		quit(1)
		return
	demo.camera.set_flying(false)
	print("STAIRCASE DEMO: rendered closed black ends and both routes; R resets and Z enters fly mode")
	demo.queue_free()
	viewport.queue_free()
	await process_frame
	quit()
