extends SceneTree

func _initialize() -> void:
	_capture.call_deferred()

func _capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 600)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(load("res://components/torch/demo.tscn").instantiate())
	for frame in range(20):
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://tests/output/torch")
	viewport.get_texture().get_image().save_png("res://tests/output/torch/torch-demo.png")
	var camera: Camera3D = viewport.get_child(0).get_node("Camera")
	camera.set_flying(true)
	await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://tests/output/torch/torch-demo-flying.png")
	camera.set_flying(false)
	viewport.queue_free()
	await process_frame
	print("Torch demo rendered")
	quit()
