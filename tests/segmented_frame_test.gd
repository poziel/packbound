extends SceneTree
const FRAME = preload("res://components/item_slot/item_frame.gd")
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr(label)
func points(rows: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(rows.size()):
		for x in range(rows[y].length()):
			if rows[y][x] == "#": result.append(Vector2i(x, y))
	return result
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var single := points(["#"])
	var mask := FRAME.skin(single, Vector2(32, 32), 0)
	var border: Image = mask.border.get_image()
	var fill: Image = mask.fill.get_image()
	check(border.get_pixel(17, 1).a == 1 and border.get_pixel(17, 2).a == 1, "Two pixel rim")
	check(border.get_pixel(17, 3).a == 0 and fill.get_pixel(17, 3).a == 0, "Transparent one pixel gap")
	check(fill.get_pixel(17, 4).a == 1, "Face begins after gap")
	check(border.get_pixel(1, 1).a == 0, "Stepped corner")
	for rows in [["##..", ".##.", "..##"], ["###", "#.#", "###"], ["###", ".#."]]:
		var shape := points(rows)
		var skin := FRAME.skin(shape, Vector2(32, 32), 0)
		var face: Image = skin.fill.get_image()
		var rim: Image = skin.border.get_image()
		for y in range(rows.size()):
			for x in range(rows[y].length()):
				var center := Vector2i(x * 32 + 17, y * 32 + 17)
				check((face.get_pixelv(center).a == 1) == (rows[y][x] == "#"), "Mask center " + str([rows, x, y]))
		for socket in FRAME.segments(shape, Vector2(32, 32), 0):
			check(socket.rect.size.x >= 2 and socket.rect.size.y >= 2, "Usable segment")
		# Shared edge between first two cells must be fill, never rim or gap.
		check(face.get_pixel(33, 17).a == 1 and rim.get_pixel(33, 17).a == 0, "Continuous shared edge")
	var rounded_hole := FRAME.skin(points(["###", "#.#", "###"]), Vector2(32, 32), 0)
	check(rounded_hole.border.get_image().get_pixel(34, 34).a > 0 or rounded_hole.fill.get_image().get_pixel(34, 34).a > 0, "Hole corner has stepped rounding")
	check(rounded_hole.border.get_image().get_pixel(38, 38).a == 0 and rounded_hole.fill.get_image().get_pixel(38, 38).a == 0, "Hole remains transparent beyond rounded corner")
	var tee := points(["###", ".#."])
	var top_segments: Array = FRAME.segments(tee, Vector2(32, 32), 2).filter(func(segment: Dictionary) -> bool: return segment.side == "top")
	check(top_segments.size() == 1 and top_segments[0].cells.size() == 3, "T top merges into one segment")
	var tee_rim: Image = FRAME.skin(tee, Vector2(32, 32), 2).border.get_image()
	for x in range(10, 91):
		check(tee_rim.get_pixel(x, 1).a == 1, "T top remains unbroken across cell joins")
	var vertical := points(["#", "#", "#"])
	var left_segments: Array = FRAME.segments(vertical, Vector2(32, 32), 0).filter(func(segment: Dictionary) -> bool: return segment.side == "left")
	check(left_segments.size() == 1 and left_segments[0].cells.size() == 3, "Vertical edges merge")
	var middle_override: Array[Dictionary] = [{"cell": Vector2i(1, 0), "side": "top", "kind": "caret_up"}]
	var replaced_rim: Image = FRAME.skin(tee, Vector2(32, 32), 2, middle_override).border.get_image()
	check(replaced_rim.get_pixel(51, 1).a == 0, "Member cell replaces center of merged run")
	var replacements: Array[Dictionary] = [{"side": "bottom", "kind": "caret_up"}]
	var custom := FRAME.skin(single, Vector2(32, 32), 0, replacements)
	check(custom.border.get_image().get_pixel(17, 31).a == 0, "Replacement removes default border")
	# Native-size contact sheet uses the actual cached frame masks.
	var sheet := Image.create(420, 150, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("343039"))
	var offset := Vector2i(8, 8)
	for rows in [["#"], ["##..", ".##.", "..##"], ["###", "#.#", "###"], ["###", ".#."]]:
		var skin := FRAME.skin(points(rows), Vector2(32, 32), 0)
		var face: Image = skin.fill.get_image()
		var rim: Image = skin.border.get_image()
		for y in range(face.get_height()):
			for x in range(face.get_width()):
				if face.get_pixel(x, y).a > 0: face.set_pixel(x, y, Color("687c48"))
				if rim.get_pixel(x, y).a > 0: rim.set_pixel(x, y, Color("c0df79"))
		sheet.blend_rect(face, Rect2i(Vector2i.ZERO, face.get_size()), offset)
		sheet.blend_rect(rim, Rect2i(Vector2i.ZERO, rim.get_size()), offset)
		offset.x += face.get_width() + 12
	sheet.save_png("res://tests/output/segmented-frame-review.png")
	var demo = load("res://components/item_slot/segmented_frame_demo.tscn").instantiate()
	root.add_child(demo)
	await process_frame
	await process_frame
	check(demo.custom_draw_count > 0, "Custom segment callback executes during drawing")
	demo.queue_free()
	print("SEGMENTED FRAME: ", failures, " failures")
	quit(1 if failures else 0)
