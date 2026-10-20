extends "res://tests/support/test_case.gd"

var viewport: SubViewport
var board: BackpackBoard

func _initialize() -> void:
	if not require_isolation():
		return
	_run.call_deferred()


func _run() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(584, 568)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	board = load("res://scenes/run/inventory/backpack/backpack.tscn").instantiate()
	board.run = PackRun.new()
	board.run.reset(42, "ranger")
	board.run.choose_relic(board.run.relic_offers[0])
	board.run.relics.clear()
	board.run.items.clear()
	viewport.add_child(board)
	await process_frame
	_geometry_checks()
	_grab_center_checks()
	_rotation_checks()
	if DisplayServer.get_name() != "headless":
		await _render_checks()
		await _screenshots()
	viewport.queue_free()
	await process_frame
	report("BACKPACK ITEM RESULT")
	quit(1 if failures else 0)

func _geometry_checks() -> void:
	for key in PackCatalog.ROSTER:
		board.run.items.clear()
		var item: Dictionary = board.run.add_item(key)
		item["cell"] = Vector2i.ZERO
		for rotation in range(4):
			item["rotation"] = rotation
			item["shape"] = PackRun.dimensions(item)
			var points: Array[Vector2i] = PackRun.offsets(item)
			for y in range(item["shape"].y):
				for x in range(item["shape"].x):
					var cell := Vector2i(x, y)
					var center: Vector2 = BackpackBoard.ORIGIN + Vector2(cell) * BackpackBoard.STEP + Vector2(32, 32)
					check((board.hit_item(center) == item) == points.has(cell), "%s rotation %d respects occupied and empty cells" % [key, rotation])
			for point in points:
				for direction in [Vector2i.RIGHT, Vector2i.DOWN]:
					if not points.has(point + direction):
						continue
					# Check the old gap close to both ends, not just the old narrow link.
					for along in [8, 32, 55]:
						var seam := Vector2(66, along) if direction == Vector2i.RIGHT else Vector2(along, 66)
						var at: Vector2 = BackpackBoard.ORIGIN + Vector2(point) * BackpackBoard.STEP + seam
						check(board.hit_item(at) == item, "%s rotation %d has a full-width draggable join" % [key, rotation])
	# An item in an L's empty corner still owns that entire slot.
	board.run.items.clear()
	var bow: Dictionary = board.run.add_item("shortbow")
	bow["cell"] = Vector2i.ZERO
	var knife: Dictionary = board.run.add_item("rusty_knife")
	knife["cell"] = Vector2i(1, 0)
	check(board.hit_item(BackpackBoard.ORIGIN + Vector2(100, 32)) == knife, "Empty L corner remains available to another item")
	board.begin_drag(bow, BackpackBoard.ORIGIN + Vector2(32, 66))
	var initial_grab: Vector2 = board.grab
	for quarter in range(4):
		board.rotate_held()
	check(board.grab.is_equal_approx(initial_grab), "Grabbing the filled seam survives four rotations")
	board.cancel_drag()

func _grab_center_checks() -> void:
	board.run.items.clear()
	var item: Dictionary = board.run.add_item("shortbow", Vector2i.ZERO)
	# The requested #### / ...# / ...# footprint.
	item["mask"] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(3, 1), Vector2i(3, 2)]
	for rotation in range(4):
		item["rotation"] = rotation
		item["shape"] = PackRun.dimensions(item)
		for cell in PackRun.offsets(item):
			var center: Vector2 = Vector2(cell) * BackpackBoard.STEP + Vector2.ONE * BackpackBoard.CELL * 0.5
			for corner in [Vector2(2, 2), Vector2(62, 2), Vector2(2, 62), Vector2(62, 62)]:
				var at: Vector2 = BackpackBoard.ORIGIN + Vector2(cell) * BackpackBoard.STEP + corner
				board.begin_drag(item, at)
				check(board.grab == center, "Each occupied tile corner snaps to its own center")
				check(board.pointer == at and board.candidate() == Vector2i.ZERO, "Snapping preserves pointer position and original drop cell")
				for quarter in range(4):
					board.rotate_held()
					var held_cell := Vector2i((board.grab / BackpackBoard.STEP).floor())
					check(PackRun.offsets(item, board.drag_rotation).has(held_cell), "Rotation keeps an occupied tile under the cursor")
					check(board.grab == Vector2(held_cell) * BackpackBoard.STEP + Vector2(32, 32), "Rotation stays anchored to the tile center")
				check(board.grab == center, "Four rotations return to the same centered grab")
				board.cancel_drag()
	item["rotation"] = 0
	item["shape"] = PackRun.dimensions(item)
	check(board._nearest_grab_center(item, Vector2(66, 32)) == Vector2(32, 32), "Seam ties use reading order")
	check(board._nearest_grab_center(item, Vector2(100, 168)) == Vector2(100, 32), "Empty footprint cells select the nearest occupied tile")

func _rotation_checks() -> void:
	# Off-center grabs must not move any fully occupied square, at any size.
	for side in range(1, mini(PackRun.GRID.x, PackRun.GRID.y) + 1):
		board.run.items.clear()
		var square: Dictionary = board.run.add_item("thorn_mail")
		var mask: Array[Vector2i] = []
		for y in range(side):
			for x in range(side):
				mask.append(Vector2i(x, y))
		square["mask"] = mask
		square["shape"] = Vector2i(side, side)
		square["cell"] = Vector2i.ZERO
		for offset in [Vector2(11, 23), board.footprint(square["shape"]) - Vector2(19, 9)]:
			for direction in [-1, 1]:
				board.begin_drag(square, BackpackBoard.ORIGIN + offset)
				var initial_origin: Vector2 = board.pointer - board.grab
				var initial_candidate: Vector2i = board.candidate()
				for quarter in range(1, 5):
					board.rotate_held(direction)
					check(board.pointer - board.grab == initial_origin, "%dx%d square rotates in place from an off-center grab" % [side, side])
					check(board.candidate() == initial_candidate, "Square rotation preserves the drop cell")
					check(board.drag_rotation == posmod(quarter * direction, 4), "Square sprite still turns in the requested direction")
				board.cancel_drag()
	# L shapes have square bounds but are not squares; rectangles also retain
	# the same grabbed point on the item as they turn around the cursor.
	for key in ["shortbow", "frost_wand"]:
		board.run.items.clear()
		var item: Dictionary = board.run.add_item(key)
		item["cell"] = Vector2i.ZERO
		board.begin_drag(item, BackpackBoard.ORIGIN + Vector2(11, 23))
		var extent: Vector2 = board.footprint(item["shape"])
		board.rotate_held()
		check(board.grab == Vector2(extent.y - 32, 32), key + " retains its centered tile pivot")
		board.rotate_held(-1)
		check(board.grab == Vector2(32, 32), key + " reverses around the same centered tile pivot")
		board.cancel_drag()

func _capture() -> Image:
	board.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func _color_at(image: Image, at: Vector2) -> Color:
	var pixel: Vector2i = Vector2i(BackpackBoard.ORIGIN + at)
	return image.get_pixelv(pixel)

func _render_checks() -> void:
	board.run.items.clear()
	board.selected_id = -1
	var empty: Image = await _capture()
	# Deliberately use a wider atlas and an opaque empty corner to catch both
	# incorrect AtlasTexture UVs and any sprite leakage outside the L.
	var source: Image = Image.create(192, 64, false, Image.FORMAT_RGBA8)
	source.fill(Color.MAGENTA)
	source.fill_rect(Rect2i(64, 0, 32, 32), Color.RED)
	source.fill_rect(Rect2i(96, 0, 32, 32), Color.GREEN)
	source.fill_rect(Rect2i(64, 32, 32, 32), Color.BLUE)
	source.fill_rect(Rect2i(96, 32, 32, 32), Color.YELLOW)
	var texture := AtlasTexture.new()
	texture.atlas = ImageTexture.create_from_image(source)
	texture.region = Rect2(64, 0, 64, 64)
	board.icons["shortbow"] = texture
	var bow: Dictionary = board.run.add_item("shortbow")
	bow["cell"] = Vector2i.ZERO
	var samples: Array[Vector2] = [Vector2(32, 32), Vector2(100, 32), Vector2(32, 100), Vector2(100, 100)]
	var expected: Array = [
		[Color.RED, null, Color.BLUE, Color.YELLOW],
		[Color.BLUE, Color.RED, Color.YELLOW, null],
		[Color.YELLOW, Color.BLUE, null, Color.RED],
		[null, Color.YELLOW, Color.RED, Color.BLUE],
	]
	for rotation in range(4):
		bow["rotation"] = rotation
		bow["shape"] = PackRun.dimensions(bow)
		var rendered: Image = await _capture()
		for index in range(samples.size()):
			var color: Color = expected[rotation][index] if expected[rotation][index] != null else _color_at(empty, samples[index])
			check(_color_at(rendered, samples[index]).is_equal_approx(color), "Atlas sprite spans the rotated footprint and leaves its hole clear: %d/%d" % [rotation, index])
	bow["rotation"] = 0
	bow["shape"] = PackRun.dimensions(bow)
	# Full-width interior joins must have the texture, with no cell borders.
	var rendered: Image = await _capture()
	for y in [8, 32, 55]:
		for x in [63, 64, 65, 66, 67, 68]:
			check(_color_at(rendered, Vector2(x, y + 68)) in [Color.BLUE, Color.YELLOW], "Sprite stays continuous through the entire horizontal join")
	for x in [8, 32, 55]:
		for y in [63, 64, 65, 66, 67, 68]:
			check(_color_at(rendered, Vector2(x, y)) in [Color.RED, Color.BLUE], "Sprite stays continuous through the entire vertical join")
	var before: PackedByteArray = rendered.get_data()
	bow[GameplayTypes.Stat.DAMAGE] = 987
	bow[GameplayTypes.Stat.BLOCK] = 654
	bow[GameplayTypes.Stat.HEALING] = 321
	bow["activation_costs"][GameplayTypes.ResourceType.MANA] = 2
	board.run.mana = 12
	rendered = await _capture()
	check(before == rendered.get_data(), "Damage, block, healing and mana values never draw over the sprite")
	board.begin_drag(bow, BackpackBoard.ORIGIN + Vector2(32, 32))
	board.pointer += Vector2(3, 3) * BackpackBoard.STEP
	board.rotate_held()
	rendered = await _capture()
	var held_origin: Vector2 = board.pointer - board.grab - BackpackBoard.ORIGIN
	check(_color_at(rendered, held_origin + Vector2(32, 32)) == Color.BLUE, "Held sprite rotates with the drag footprint")
	check(_color_at(rendered, held_origin + Vector2(100, 32)) == Color.RED, "Held sprite reaches the other occupied cell")
	board.cancel_drag()
	board.icons.clear()

func _screenshots() -> void:
	board.run.items.clear()
	board.selected_id = -1
	var layout: Dictionary = {
		"shortbow": Vector2i(0, 0), "frost_wand": Vector2i(2, 0),
		"hunting_trap": Vector2i(3, 0), "quiver": Vector2i(6, 0),
		"rusty_knife": Vector2i(7, 0), "cracked_shield": Vector2i(7, 1),
		"battle_axe": Vector2i(0, 3), "warding_sigil": Vector2i(5, 3),
		"thorn_mail": Vector2i(0, 5), "hourglass": Vector2i(2, 5),
		"ember_tome": Vector2i(3, 2), "bandage": Vector2i(7, 6),
	}
	for key in layout:
		var item: Dictionary = board.run.add_item(key)
		check(board.run.can_place(item, layout[key]), "Review layout fits: " + key)
		item["cell"] = layout[key]
	var rendered: Image = await _capture()
	rendered.save_png(preload("res://tests/support/artifact_paths.gd").path("grid-item-shapes.png"))
	var game_viewport := SubViewport.new()
	game_viewport.size = Vector2i(1280, 800)
	game_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(game_viewport)
	var game: Control = load("res://scenes/main.tscn").instantiate()
	game_viewport.add_child(game)
	await process_frame
	game.start_run("ranger", 42)
	game._open_reward(true)
	game._choose(0)
	game.run.items = board.run.items.duplicate(true)
	game.run.mana = 12
	game._refresh()
	await process_frame
	await RenderingServer.frame_post_draw
	game_viewport.get_texture().get_image().save_png(preload("res://tests/support/artifact_paths.gd").path("grid-item-game.png"))
	game_viewport.queue_free()
