extends SceneTree
## Render actual-size route samples and measure visibility against the same empty room.

func _initialize() -> void:
	_run.call_deferred()

func picture(viewport: SubViewport) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func _run() -> void:
	var failures: int = 0
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var game: Control = load("res://scenes/main.tscn").instantiate()
	viewport.add_child(game)
	await process_frame
	game.start_run("warrior", 42)
	var life: Node3D = game.gameplay_background.world.active_room.get_node("CorridorLife")
	life.set_process(false)
	life.rng.seed = 42
	game.gameplay_background.world.active_room.set_process(false)
	life.get_node("AirborneDust").hide()
	life.get_node("DustHaze").hide()
	life.spider.hide()
	life.mouse.hide()
	var directory: String = "res://tests/output/critter-routes/run-%d" % Time.get_unix_time_from_system()
	DirAccess.make_dir_recursive_absolute(directory)
	print("CAPTURE DIRECTORY: ", directory)
	if OS.get_cmdline_user_args().has("--video"):
		life.get_node("AirborneDust").show()
		life.get_node("DustHaze").show()
		await capture_video(viewport, life, directory)
		viewport.queue_free()
		await process_frame
		quit()
		return
	var baseline: Image = await picture(viewport)
	baseline.save_png(directory + "/empty.png")
	for kind: String in ["mouse", "spider"]:
		for index in range(life.critters[kind]["routes"].size()):
			life.spider.hide()
			life.mouse.hide()
			life._begin_critter(kind, index)
			var state: Dictionary = life.critters[kind]
			var route: Dictionary = state["routes"][index]
			var sightings: Array[int] = []
			for frame in range(11):
				state["age"] = state["duration"] * frame / 10.0
				life._pose_critter(kind, state, 0.0)
				var current: Image = await picture(viewport)
				var changed: int = 0
				var bounds := Rect2i()
				for y in range(675):
					for x in range(624):
						var a: Color = baseline.get_pixel(x, y)
						var b: Color = current.get_pixel(x, y)
						if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.025:
							changed += 1
							bounds = Rect2i(x, y, 1, 1) if changed == 1 else bounds.expand(Vector2i(x, y))
				sightings.append(changed)
				current.save_png(directory + "/%s-%d-%02d.png" % [kind, index, frame])
				print("POSE %s %d %d: %s up=%s pixels=%d bounds=%s" % [kind, index, frame, state["node"].position, state["node"].basis.y.normalized(), changed, bounds])
			print("VISIBILITY %s %s %.2fs: %s" % [kind, route["name"], state["duration"], sightings])
			if sightings.max() == 0 or sightings[0] > 0 or sightings.back() > 0:
				failures += 1
				printerr("FAIL: Route must emerge visibly and hide its entry and exit: " + route["name"])
	viewport.queue_free()
	await process_frame
	print("RENDERED ROUTES RESULT: 10 routes, %d failures" % failures)
	quit(1 if failures else 0)

func capture_video(viewport: SubViewport, life: Node3D, directory: String) -> void:
	for visit: Array in [["mouse", 1], ["mouse", 0], ["spider", 0]]:
		for kind: String in life.critters:
			life.critters[kind]["active"] = false
			life.critters[kind]["node"].hide()
			life.critters[kind]["cooldown"] = 1000.0
		life._begin_critter(visit[0], visit[1])
		var state: Dictionary = life.critters[visit[0]]
		var frames_path: String = directory + "/" + state["routes"][visit[1]]["name"]
		DirAccess.make_dir_recursive_absolute(frames_path)
		for frame in range(ceili(state["duration"] * 30.0) + 12):
			life.advance_ambient(1.0 / 30.0)
			await process_frame
			if frame % 3 == 0:
				await RenderingServer.frame_post_draw
				viewport.get_texture().get_image().save_png(frames_path + "/%04d.png" % (frame / 3))
		print("VIDEO FRAMES: ", frames_path)
