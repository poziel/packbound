extends "res://tests/support/test_case.gd"

class Trail extends Control:
	const CELL: float = 64.0
	var _crafting_clock: float = 0.0
	var direction := Vector2.RIGHT
	var strength: float = 0.0
	var alpha: float = 1.0
	var gpu: bool = false
	var trails = preload("res://scenes/run/inventory/backpack/crafting_trails.gd").new()
	func _draw() -> void:
		var start := Vector2(100, 100)
		if gpu:
			trails.draw(self, {"pair": {"start": start, "finish": start + direction * 400, "tint": Color("67dff2"), "strength": strength, "alpha": alpha}}, _crafting_clock)
		else:
			preload("res://scenes/run/inventory/backpack/crafting_presentation.gd").wisp(self, start, start + direction * 400, Color("67dff2"), strength, smoothstep(0.0, 1.0, alpha))


func _initialize() -> void:
	if not require_isolation():
		return
	_run.call_deferred()

func _run() -> void:
	var views: Array[SubViewport] = []
	var trails: Array[Trail] = []
	for gpu: bool in [false, true]:
		var view := SubViewport.new()
		view.size = Vector2i(200, 200)
		view.transparent_bg = true
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(view)
		var trail := Trail.new()
		trail.gpu = gpu
		view.add_child(trail)
		views.append(view)
		trails.append(trail)
	var worst_error: float = 0.0
	for angle: float in [0.0, PI * 0.25, PI * 1.25]:
		for strength: float in [0.0, 1.0]:
			for alpha: float in [0.25, 1.0]:
				for trail: Trail in trails:
					trail.direction = Vector2.RIGHT.rotated(angle)
					trail._crafting_clock = 0.37
					trail.strength = strength
					trail.alpha = alpha
					trail.queue_redraw()
				await process_frame
				await process_frame
				await RenderingServer.frame_post_draw
				var reference: Image = views[0].get_texture().get_image()
				var result: Image = views[1].get_texture().get_image()
				var active: int = 0
				var outside: int = 0
				var error: float = 0.0
				for y in range(200):
					for x in range(200):
						var a: Color = reference.get_pixel(x, y)
						var b: Color = result.get_pixel(x, y)
						if maxf(a.a, b.a) < 0.01: continue
						active += 1
						error += absf(a.a - b.a) + absf(a.r * a.a - b.r * b.a) + absf(a.g * a.a - b.g * b.a) + absf(a.b * a.a - b.b * b.a)
						if b.a >= 0.01 and Vector2(x + 0.5, y + 0.5).distance_to(Vector2(100, 100)) > 64: outside += 1
				var average: float = error / maxf(1, active * 4)
				worst_error = maxf(worst_error, average)
				check(active > 0 and outside == 0, "GPU trails stay within the approved reach")
				check(average < 0.035, "GPU trails preserve the reference color, halo, and fade (%f)" % average)
	DirAccess.make_dir_recursive_absolute("res://workspace/reviews/item-motion")
	views[0].get_texture().get_image().save_png("res://workspace/reviews/item-motion/trail-reference.png")
	views[1].get_texture().get_image().save_png("res://workspace/reviews/item-motion/trail-gpu.png")
	for view: SubViewport in views: view.queue_free()
	await process_frame
	print("GPU TRAIL COMPARISON: worst average premultiplied channel error %.5f" % worst_error)
	report("GPU TRAIL RESULT")
	quit(1 if failures else 0)
