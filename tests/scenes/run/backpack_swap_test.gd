extends "res://tests/support/test_case.gd"

var viewport: SubViewport

func _initialize() -> void:
	if not require_isolation():
		return
	_run.call_deferred()


func fixture() -> PackRun:
	var state := PackRun.new()
	state.reset(42)
	state.choose_relic(state.relic_offers[0])
	state.items.clear()
	state.relics.clear()
	return state

func _run() -> void:
	create_timer(30.0).timeout.connect(func() -> void: quit(2))
	_plan_checks()
	_displacement_checks()
	_preview_checks()
	await _input_checks()
	report("BACKPACK SWAP RESULT")
	quit(1 if failures else 0)

func _check_handoff(state: PackRun, item: Dictionary, at: Vector2i, rotation: int = -1) -> void:
	var before: Array[Dictionary] = state.items.duplicate(true)
	var moves: Array[Dictionary] = state.placement_plan(item, at, rotation)
	check(state.items == before, "Planning a swap never mutates inventory")
	check(moves.size() == 2, "Overlapping one item creates exactly two moves")
	if moves.size() != 2:
		return
	check(moves[0]["cell"] == at, "Dragged item keeps the requested destination")
	check(moves[1]["cell"] == null and moves[1].get("held", false), "Single displaced item is handed to the cursor")
	check(moves[1]["rotation"] == moves[1]["item"]["rotation"], "Displaced item keeps its orientation")
	for move in moves:
		move["item"]["cell"] = move["cell"]
		move["item"]["rotation"] = move["rotation"]
		move["item"]["shape"] = move["shape"]
	for packed in state.packed():
		check(state.can_place(packed, packed["cell"]), "Committed swap has no overlaps or out-of-bounds cells")
	check(state.items.size() == before.size(), "Swapping preserves every item")

func _plan_checks() -> void:
	var state := fixture()
	var first: Dictionary = state.add_item("rusty_knife", Vector2i.ZERO)
	state.add_item("cracked_shield", Vector2i(4, 2))
	_check_handoff(state, first, Vector2i(4, 2))

	state = fixture()
	first = state.add_item("thorn_mail", Vector2i.ZERO)
	state.add_item("rusty_knife", Vector2i(5, 3))
	_check_handoff(state, first, Vector2i(5, 3))

	state = fixture()
	first = state.add_item("rusty_knife", PackRun.GRID - Vector2i.ONE)
	state.add_item("thorn_mail", Vector2i(3, 2))
	_check_handoff(state, first, Vector2i(3, 2))

	state = fixture()
	first = state.add_item("rusty_knife", Vector2i(2, 2))
	state.add_item("thorn_mail", Vector2i(5, 3))
	var neighbor: Dictionary = state.add_item("bandage", Vector2i(3, 2))
	_check_handoff(state, first, Vector2i(5, 3))
	check(neighbor["cell"] == Vector2i(3, 2), "Nearest-fit search leaves unrelated neighbors in place")

	state = fixture()
	first = state.add_item("thorn_mail", Vector2i.ZERO)
	state.add_item("rusty_knife", Vector2i(2, 0))
	_check_handoff(state, first, Vector2i(1, 0))

	state = fixture()
	first = state.add_item("shortbow", Vector2i.ZERO)
	neighbor = state.add_item("rusty_knife", Vector2i(1, 0))
	check(state.placement_plan(first, Vector2i.ZERO).size() == 1, "An item in the empty L corner does not trigger a swap")
	state.add_item("bandage", Vector2i(3, 1))
	_check_handoff(state, first, Vector2i(3, 0))
	check(neighbor["cell"] == Vector2i(1, 0), "An interlocked neighbor stays in its empty corner")

	state = fixture()
	first = state.add_item("rusty_knife", Vector2i.ZERO)
	var rotated: Dictionary = state.add_item("quiver", Vector2i(4, 2))
	rotated["rotation"] = 1
	rotated["shape"] = PackRun.dimensions(rotated)
	_check_handoff(state, first, Vector2i(4, 2))
	check(rotated["rotation"] == 1 and rotated["shape"] == Vector2i(2, 1), "A displaced horizontal item stays horizontal")

	state = fixture()
	first = state.add_item("frost_wand", Vector2i.ZERO)
	state.add_item("rusty_knife", Vector2i(4, 2))
	_check_handoff(state, first, Vector2i(4, 2), 1)
	check(first["rotation"] == 1 and first["shape"] == Vector2i(3, 1), "Swap commits the held item's new rotation")

	state = fixture()
	first = state.add_item("thorn_mail", Vector2i.ZERO)
	state.add_item("rusty_knife", Vector2i(4, 2))
	state.add_item("bandage", Vector2i(5, 2))
	var before: Array[Dictionary] = state.items.duplicate(true)
	check(state.placement_plan(first, Vector2i(4, 2)).size() == 3, "Multiple overlaps produce a complete displacement plan")
	check(state.placement_plan(first, Vector2i(7, 6)).is_empty(), "Swaps cannot place a shape beyond the grid")
	check(state.placement_plan(first, Vector2i(-1, 0)).is_empty(), "Swaps cannot use negative grid cells")
	check(state.items == before, "Rejected plans preserve all inventory state")

	state = fixture()
	first = state.add_item("rusty_knife", Vector2i(7, 6))
	state.add_item("thorn_mail", Vector2i.ZERO)
	for y in range(PackRun.GRID.y):
		for x in range(PackRun.GRID.x):
			if (x < 2 and y < 2) or Vector2i(x, y) == Vector2i(7, 6):
				continue
			state.add_item("bandage", Vector2i(x, y))
	before = state.items.duplicate(true)
	check(state.placement_plan(first, Vector2i.ZERO).size() == 2, "A full backpack still allows a displaced item onto the cursor")
	check(state.items == before, "No-fit failure does not lose or unpack an item")

	state = fixture()
	first = state.add_item("rusty_knife")
	state.add_item("thorn_mail", Vector2i(3, 2))
	_check_handoff(state, first, Vector2i(3, 2))
	check(state.packed().size() == 1, "A storage swap returns the displaced item to storage")

func _displacement_checks() -> void:
	var state := fixture()
	var dropped: Dictionary = state.add_item("thorn_mail")
	var small: Dictionary = state.add_item("rusty_knife", Vector2i(4, 2))
	var large: Dictionary = state.add_item("quiver", Vector2i(3, 2))
	var before: Array[Dictionary] = state.items.duplicate(true)
	var moves: Array[Dictionary] = state.placement_plan(dropped, Vector2i(3, 2))
	check(moves.size() == 3 and moves[1]["item"] == large, "Largest occupied footprint goes to cursor regardless of insertion order")
	check(moves[2]["item"] == small and moves[2]["cell"] == Vector2i(4, 1), "Other item moves to nearest free location with reading-order tie break")
	check(state.items == before, "Multi-item planning does not mutate any item")
	for hole in [Vector2i(6, 4), Vector2i(7, 2), Vector2i(7, 3), Vector2i(7, 5)]:
		state = fixture()
		dropped = state.add_item("quiver")
		# Deliberately insert the right item first to verify natural order.
		small = state.add_item("bandage", Vector2i(4, 2))
		large = state.add_item("rusty_knife", Vector2i(3, 2))
		for y in range(PackRun.GRID.y):
			for x in range(PackRun.GRID.x):
				var at := Vector2i(x, y)
				if at not in [hole, Vector2i(3, 2), Vector2i(4, 2)]:
					state.add_item("bandage", at)
		before = state.items.duplicate(true)
		moves = state.placement_plan(dropped, Vector2i(3, 2), 1)
		check(moves.size() == 3 and moves[1]["item"] == large, "Equal footprints select original reading order")
		var expected: Variant = hole if (hole - Vector2i(4, 2)).length_squared() <= 9 else null
		check(moves[2]["cell"] == expected, "Circular radius correctly handles offset %s" % str(hole - Vector2i(4, 2)))
		check(state.items == before, "Crowded planning remains non-mutating")
		for move in moves:
			move["item"]["cell"] = move["cell"]
			move["item"]["rotation"] = move["rotation"]
			move["item"]["shape"] = move["shape"]
		for packed in state.packed():
			check(state.can_place(packed, packed["cell"]), "Crowded displacement has no overlaps")
	state = fixture()
	dropped = state.add_item("thorn_mail", Vector2i.ZERO)
	for at in [Vector2i(4, 3), Vector2i(3, 3), Vector2i(4, 2), Vector2i(3, 2)]:
		state.add_item("bandage", at)
	moves = state.placement_plan(dropped, Vector2i(3, 2))
	check(moves.size() == 5 and moves[1]["item"]["cell"] == Vector2i(3, 2), "Four overlaps choose the top-left original item")
	var destinations: Array[Vector2i] = []
	for move in moves.slice(2):
		check(move["cell"] != null and not destinations.has(move["cell"]), "Relocations reserve distinct destinations")
		destinations.append(move["cell"])

func _preview_checks() -> void:
	var board := BackpackBoard.new()
	board.run = fixture()
	var knife: Dictionary = board.run.add_item("rusty_knife", Vector2i.ZERO)
	var shield: Dictionary = board.run.add_item("cracked_shield", Vector2i(4, 0))
	board.run.add_item("blood_gem", Vector2i(5, 0))
	board.begin_drag(knife, BackpackBoard.ORIGIN + Vector2(11, 23))
	board.pointer = BackpackBoard.ORIGIN + Vector2(4, 0) * BackpackBoard.STEP + board.grab
	var before: Array[Dictionary] = board.run.items.duplicate(true)
	check(board.candidate_valid(), "Valid swap receives a valid placement preview")
	var forecast: Dictionary = board.preview_effects()
	check(forecast == board.run.effects() and forecast["damage"] == 4, "Swap hover keeps current effects until committed")
	check(board.run.items == before, "Preview restores both items without changing live inventory")
	board.cancel_drag()
	check(board.run.items == before, "Canceling a swap leaves both items untouched")
	board.begin_drag(knife, BackpackBoard.ORIGIN + Vector2(11, 23))
	board.pointer = BackpackBoard.ORIGIN + Vector2(4, 0) * BackpackBoard.STEP + board.grab
	board.rotate_held()
	forecast = board.preview_effects()
	board.drop_at(board.pointer)
	check(knife["cell"] == Vector2i(4, 0) and shield["cell"] == null, "Releasing packs the dropped item and lifts the shield")
	check(knife["rotation"] == 1, "Square rotation remains intact during swaps")
	check(board.run.effects()["damage"] == 6 and board.run.effects()["block"] == 0, "Committed swap applies new adjacency and removes lifted shield")
	check(board.dragging == shield and board.cursor_held, "Displaced shield follows the cursor without holding a button")
	check(not board.unpacked().has(shield), "Cursor-held item is not simultaneously shown in unused items")
	board.cancel_drag()
	check(board.unpacked().has(shield), "Scene interruption safely stores the displaced item")
	board.free()

func _input_checks() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.notify_mouse_entered()
	var game: Control = load("res://scenes/main.tscn").instantiate()
	viewport.add_child(game)
	await process_frame
	game.start_run("warrior", 42)
	game._open_reward(true)
	game._choose(0)
	await process_frame
	await process_frame
	var board: BackpackBoard = game.board
	var first: Dictionary = game.run.items[0]
	var second: Dictionary = game.run.items[1]
	var origin: Vector2i = first["cell"]
	var destination: Vector2i = second["cell"]
	var at: Vector2 = board.global_position + board.item_rect(first).get_center()
	_motion(at)
	_mouse(at, true)
	check(board.dragging == first, "Real pointer starts the drag")
	at = board.global_position + board.item_rect(second).get_center()
	_motion(at)
	check(board.candidate_valid(), "Real pointer over an occupied slot previews a valid swap")
	var forecast: Dictionary = board.preview_effects()
	check(first["cell"] == origin and second["cell"] == destination, "Hovering the swap does not commit it")
	check(game.values["block"].text == str(forecast["block"]), "Live HUD uses the swap forecast")
	await _snapshot("item-swap-preview")
	_mouse(at, false)
	check(first["cell"] == destination and second["cell"] == null and board.dragging == second, "Real release hands off the displaced item")
	check(board.preview_effects() == game.run.effects() and game.values["block"].text == str(game.run.effects()["block"]), "Real drop updates effects and HUD to committed inventory")
	check(game.action.disabled, "Combat stays locked while a displaced item is held")
	# Clicking another occupied item chains the handoff; its release must not
	# accidentally drop the next held item again.
	_mouse(at, true)
	check(board.dragging == first, "A click chains displacement without holding the button")
	_mouse(at, false)
	check(board.dragging == first, "Release after a sticky click cannot place twice")
	at = board.global_position + BackpackBoard.ORIGIN + Vector2(origin) * BackpackBoard.STEP + board.grab
	_motion(at)
	_mouse(at, true)
	check(board.dragging.is_empty() and first["cell"] == origin, "Next click places the held item")
	_mouse(at, false)
	check(board.dragging.is_empty() and not game.action.disabled, "Combat resumes after placement")
	await create_timer(0.25).timeout
	# Pick up again and displace; an off-grid click now throws into storage.
	at = board.global_position + board.item_rect(first).get_center()
	_mouse(at, true)
	at = board.global_position + board.item_rect(second).get_center()
	_motion(at)
	_mouse(at, false)
	_motion(Vector2(2, 2))
	_mouse(Vector2(2, 2), true)
	_mouse(Vector2(2, 2), false)
	check(board.dragging.is_empty() and board.unpacked().has(second), "Off-grid click throws the cursor-held item into storage")
	board.begin_drag(second, board.item_rect(second).get_center())
	board.cursor_held = true
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	viewport.push_input(escape, true)
	check(board.dragging.is_empty() and board.unpacked().has(second), "Escape sends the handoff to unused items")
	check(game.storage.bodies.has(second["id"]) and game.storage.bodies[second["id"]].returning, "Escape starts a physics flight toward the stash")
	check(not game.modal.visible, "Escape storing an item does not open pause")
	await create_timer(0.45).timeout
	check(board.item_motions.is_empty() and board.z_index == 0, "Animations finish and restore the board draw order")
	await _snapshot("item-swap-complete")
	game.run.items.clear()
	var mail: Dictionary = game.run.add_item("thorn_mail", Vector2i.ZERO)
	var quiver: Dictionary = game.run.add_item("quiver", Vector2i(3, 2))
	var knife: Dictionary = game.run.add_item("rusty_knife", Vector2i(4, 2))
	var gem: Dictionary = game.run.add_item("blood_gem", Vector2i(4, 3))
	board.begin_drag(mail, board.item_rect(mail).get_center())
	board.drop_at(BackpackBoard.ORIGIN + Vector2(3, 2) * BackpackBoard.STEP + board.grab)
	check(board.dragging == quiver, "Multiple overlap holds the largest item")
	check(board.item_motions.has(knife["id"]) and board.item_motions.has(gem["id"]), "Both automatically relocated items animate")
	await create_timer(0.07).timeout
	var motion: Dictionary = board.item_motions[knife["id"]]
	var displayed: Vector2 = board._motion_position(motion)
	check(displayed != motion["from"] and displayed != motion["to"], "Slide has an intermediate position instead of teleporting")
	await _snapshot("item-displacement-sliding")
	board.stash_held()
	await create_timer(0.13).timeout
	check(game.storage.bodies.has(quiver["id"]) and game.storage.bodies[quiver["id"]].returning and game.storage.drag_overlay.is_visible_in_tree(), "Stash physics flight remains visible during travel")
	await _snapshot("item-displacement-stash-flight")
	await create_timer(0.45).timeout
	check(board.item_motions.is_empty(), "Multi-item movement completes")
	await _snapshot("item-displacement-settled")
	viewport.queue_free()
	await process_frame

func _motion(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	viewport.push_input(event, true)

func _mouse(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	viewport.push_input(event, true)

func _snapshot(filename: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(preload("res://tests/support/artifact_paths.gd").path("%s.png") % filename)
