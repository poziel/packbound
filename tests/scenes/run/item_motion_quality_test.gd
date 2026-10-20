extends "res://tests/support/storage_ui_support.gd"

var preview_updates: int = 0
var measurements: Dictionary = {}
var review_dir := "res://workspace/reviews/item-motion"

class MeasuredRun extends PackRun:
	var effect_reads: int = 0
	func effects() -> Dictionary:
		effect_reads += 1
		return super.effects()

func _run() -> void:
	create_timer(60).timeout.connect(func() -> void: quit(2))
	render = DisplayServer.get_name() != "headless"
	Engine.max_fps = 144
	test_viewport = SubViewport.new()
	test_viewport.size = Vector2i(1920, 1080)
	test_viewport.size_2d_override = Vector2i(1280, 720)
	test_viewport.size_2d_override_stretch = true
	test_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(test_viewport)
	test_viewport.notify_mouse_entered()
	game = load("res://scenes/main.tscn").instantiate()
	test_viewport.add_child(game)
	await frames(3)
	game.run_saves.directory = preload("res://tests/support/artifact_paths.gd").path("legacy_tasks/item-motion/saves")
	game.start_run("warrior", 42)
	var measured := MeasuredRun.new()
	measured.reset(42, "warrior")
	game.run = measured
	game.board.run = measured
	game.waiting_at_entrance = false
	game.run.items.clear()
	game.run.relics.clear()
	game.run.phase = PackRun.Phase.FIGHT
	for y in range(5):
		for x in range(7):
			game.run.add_item("rusty_knife", Vector2i(x, y))
	var item: Dictionary = game.run.items[0]
	game._refresh()
	await frames(3)
	game.board.changed.connect(func() -> void: preview_updates += 1)
	var at: Vector2 = game.board.get_global_transform_with_canvas() * game.board.item_rect(item).get_center()
	_motion(at)
	_mouse(at, true)
	preview_updates = 0
	var started := Time.get_ticks_usec()
	for tick in 120:
		_motion(at + Vector2(tick % 12, 0))
	measurements.backpack_input_ms = float(Time.get_ticks_usec() - started) / 1000.0
	measurements.backpack_preview_updates = preview_updates
	check(preview_updates <= 2, "Moving within one placement does not recalculate combat preview for every pointer event")
	started = Time.get_ticks_usec()
	for tick in 5: game.board.preview_effects()
	measurements.effect_preview_ms = float(Time.get_ticks_usec() - started) / 5000.0
	started = Time.get_ticks_usec()
	for tick in 5: game.board.candidate_plan()
	measurements.placement_preview_ms = float(Time.get_ticks_usec() - started) / 5000.0
	started = Time.get_ticks_usec()
	for target: Dictionary in game.run.items: game.board.bonus_markers(target)
	measurements.adjacency_markers_ms = float(Time.get_ticks_usec() - started) / 1000.0
	var frame_costs: Array[float] = []
	var reads_before: int = measured.effect_reads
	preview_updates = 0
	for tick in 20:
		started = Time.get_ticks_usec()
		await process_frame
		frame_costs.append(float(Time.get_ticks_usec() - started) / 1000.0)
	frame_costs.sort()
	measurements.loaded_frame_median_ms = frame_costs[10]
	check(measurements.loaded_frame_median_ms < 35.0, "Dense inventory with 50 craft connections avoids the reproduced 70 ms frames")
	measurements.loaded_frame_effect_reads = measured.effect_reads - reads_before
	measurements.loaded_frame_preview_updates = preview_updates
	started = Time.get_ticks_usec()
	game.board._process(0.001)
	measurements.board_process_ms = float(Time.get_ticks_usec() - started) / 1000.0
	measurements.craft_trails = game.board._crafting_hover.size()
	game.board.cancel_drag()
	game.run.items.clear()
	item = game.run.add_item("bandage")
	game._refresh()
	game._toggle_storage()
	await frames(4)
	var storage: PackStorage = game.storage
	var body: RigidBody2D = storage.bodies[item.id]
	await place(body, Vector2(180, 180))
	body.freeze = true
	body.teleport(Vector2(180, 180))
	await frames(3)
	DirAccess.make_dir_recursive_absolute(review_dir)
	await capture_motion("resident")
	at = body_point(body)
	_motion(at)
	_mouse(at, true)
	check(storage.grabbed == body, "Pointer picks up real stash body")
	await process_frame
	await capture_motion("held")
	preview_updates = 0
	started = Time.get_ticks_usec()
	for tick in 120:
		_motion(at + Vector2(tick % 12, 0))
	measurements.stash_input_ms = float(Time.get_ticks_usec() - started) / 1000.0
	measurements.stash_preview_updates = preview_updates
	check(preview_updates <= 2, "Stash-only movement does not recalculate unchanged backpack effects")
	check(storage.drag_overlay.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Detached drag visual uses nearest filtering")
	check(storage.pile_visuals.get_viewport() == test_viewport and storage.pile_visuals.clip_contents, "Stash art renders at UI resolution with its original clipping")
	check(storage.pile_visuals.get_viewport() == test_viewport and storage.pile_visuals.clip_contents, "Stash art renders at UI resolution with its original clipping")
	_mouse(at, false)
	# Deliberately run physics slower than rendering to expose visible tick stepping.
	Engine.physics_ticks_per_second = 20
	body.freeze = false
	body.release_at(Vector2(120, 120), 0.0, Vector2(80, 0))
	var last := Transform2D.IDENTITY
	var changed_frames := 0
	var physics_ticks := Engine.get_physics_frames()
	for tick in 45:
		await process_frame
		var pose: Transform2D = body.visual_transform() if body.has_method("visual_transform") else body.transform
		if not pose.is_equal_approx(last): changed_frames += 1
		last = pose
	measurements.visual_changes = changed_frames
	measurements.physics_ticks = Engine.get_physics_frames() - physics_ticks
	check(changed_frames > measurements.physics_ticks + 5, "Falling item presentation advances between physics ticks")
	Engine.physics_ticks_per_second = 60
	body.teleport(Vector2(300, 180))
	body._visual_previous = Transform2D(0.0, Vector2(100, 180))
	body._visual_current = body._visual_previous
	check(storage.hit_body(Vector2(100, 180)) == body, "Moving-item picking follows its displayed pose rather than a later physics pose")
	await capture_motion("falling")
	print("ITEM MOTION MEASUREMENTS: " + JSON.stringify(measurements))
	report("ITEM MOTION RESULT")
	await preload("res://tests/support/automatic_combat_cleanup.gd").release(self, game, test_viewport)
	quit(1 if failures else 0)

func capture_motion(label: String) -> void:
	if not render: return
	await RenderingServer.frame_post_draw
	var suffix := "after" if OS.get_cmdline_user_args().has("--after") else "before"
	test_viewport.get_texture().get_image().save_png(review_dir + "/" + label + "-" + suffix + ".png")
