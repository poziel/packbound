extends SceneTree
class Trail extends Control:
	const CELL: float = 64.0
	var _crafting_clock: float = 0.0
	var direction: Vector2 = Vector2.RIGHT
	var strength: float = 0.0
	var opacity: float = 1.0
	func _draw() -> void:
		preload("res://scripts/crafting_presentation.gd").wisp(self, Vector2(100, 100), Vector2(100, 100) + direction * 400, Color("67dff2"), strength, opacity)
var checks: int = 0
var failures: int = 0
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(200, 200)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var trail := Trail.new()
	viewport.add_child(trail)
	for strength: float in [0.0, 1.0]:
		trail.strength = strength
		for index in range(8):
			trail.direction = Vector2.RIGHT.rotated(index * PI / 4.0)
			trail._crafting_clock = 0.37 + index * 0.19
			trail.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var image: Image = viewport.get_texture().get_image()
			var outside: int = 0
			var visible: int = 0
			for y in image.get_height():
				for x in image.get_width():
					if image.get_pixel(x, y).a < 0.01:
						continue
					visible += 1
					if Vector2(x + 0.5, y + 0.5).distance_to(Vector2(100, 100)) > 64.0:
						outside += 1
			checks += 1
			if outside > 0 or visible == 0:
				failures += 1
				printerr("FAIL: trail exceeds half a tile beyond the cell edge (strength %s direction %s)" % [strength, index])
	# Compare adjacent rendered frames across the previous clock reset and a
	# moving-light wrap. A loop boundary must not introduce a visible hard cut.
	trail.direction = Vector2.RIGHT
	for boundary: float in [20.0, 1.0 / 0.55]:
		var captures: Array[Image] = []
		for offset: float in [-0.0005, 0.0005]:
			trail._crafting_clock = boundary + offset
			trail.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			captures.append(viewport.get_texture().get_image())
		var difference: float = 0.0
		var active: int = 0
		for y in range(200):
			for x in range(200):
				var a: Color = captures[0].get_pixel(x, y)
				var b: Color = captures[1].get_pixel(x, y)
				if maxf(a.a, b.a) < 0.01:
					continue
				active += 1
				difference += absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) + absf(a.a - b.a)
		checks += 1
		if active == 0 or difference / maxf(1.0, active * 4.0) > 0.02:
			failures += 1
			printerr("FAIL: discontinuous rendered trail at time %s" % boundary)
	trail.direction = Vector2.RIGHT
	trail.strength = 0.0
	trail.opacity = 0.25
	trail._crafting_clock = 0.37
	trail.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var fading: Image = viewport.get_texture().get_image()
	var samples: Array[float] = []
	for t: float in [0.25, 0.72]:
		var at: Vector2 = preload("res://scripts/crafting_presentation.gd")._trail_point(Vector2(100, 100), Vector2.RIGHT, Vector2.DOWN, 56.0, t, 0.37)
		var peak: float = 0.0
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				peak = maxf(peak, fading.get_pixel(int(at.x) + dx, int(at.y) + dy).a)
		samples.append(peak)
	checks += 1
	if samples[0] < 0.05 or samples[1] < samples[0] * 0.65:
		failures += 1
		printerr("FAIL: the far trail body must fade together with its near body, without apparent tip growth")
	for t: float in [0.02, 0.98]:
		var at: Vector2 = preload("res://scripts/crafting_presentation.gd")._trail_point(Vector2(100, 100), Vector2.RIGHT, Vector2.DOWN, 56.0, t, 0.37)
		var peak: float = 0.0
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				peak = maxf(peak, fading.get_pixel(int(at.x) + dx, int(at.y) + dy).a)
		checks += 1
		if peak >= samples[0] * 0.8:
			failures += 1
			printerr("FAIL: both trail ends must dissolve gently below body opacity")
	viewport.queue_free()
	await process_frame
	print("CRAFTING TRAIL BOUNDS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
