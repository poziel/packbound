extends SceneTree
var checks: int = 0
var failures: int = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func flow_for(board: BackpackBoard, item: Dictionary, partner: Dictionary) -> Dictionary:
	var ids: Array = [item["id"], partner["id"]]
	ids.sort()
	return board._crafting_hover.get(str(ids), {})
func endpoint(flow: Dictionary, item: Dictionary, partner: Dictionary) -> Vector2:
	return flow["start"] if int(item["id"]) < int(partner["id"]) else flow["finish"]
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var board: BackpackBoard = load("res://scenes/game/inventory/backpack.tscn").instantiate()
	board.run = PackRun.new()
	board.run.reset(42)
	board.run.items.clear()
	var item: Dictionary = board.run.add_item("cracked_shield", Vector2i(1, 4))
	var partner: Dictionary = board.run.add_item("cracked_shield", Vector2i(1, 0))
	root.add_child(board)
	board.set_process(false)
	var at: Vector2 = board.item_rect(item).get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	board._gui_input(motion)
	board._process(0.10)
	check(not flow_for(board, item, partner).is_empty(), "Initial hover discovers the recipe partner")
	board.begin_drag(item, at)
	board.pointer += Vector2(55, -23)
	board._process(0.01)
	var flow: Dictionary = flow_for(board, item, partner)
	check(not flow.is_empty() and endpoint(flow, item, partner).is_equal_approx(board.pointer - board.grab + Vector2.ONE * board.CELL * 0.5), "Held trail stays fixed to the displayed shield")
	# Drop off-center so a visible slide follows. Do not send any more mouse motion.
	board.drop_at(board.ORIGIN + Vector2(4, 3) * board.STEP + Vector2(40, 30))
	board.hovered_id = -1 # Native mouse-exit/settling can clear it at this boundary.
	board._process(0.01)
	flow = flow_for(board, item, partner)
	var displayed: Vector2 = board._motion_position(board.item_motions[item["id"]]) + Vector2.ONE * board.CELL * 0.5
	check(not flow.is_empty() and endpoint(flow, item, partner).distance_to(displayed) < 0.1, "During drop settling the trail follows the displayed sprite rather than its target tile")
	board._process(0.25)
	check(board.hovered_id == item["id"], "Hover refreshes after settling without a new mouse motion event")
	flow = flow_for(board, item, partner)
	check(not flow.is_empty() and float(flow["alpha"]) > 0.99, "Trail remains fully visible under the stationary cursor after drop")
	board.begin_drag(item, board.pointer)
	board.pointer += Vector2(-80, 55)
	board._process(0.01)
	flow = flow_for(board, item, partner)
	check(not flow.is_empty() and endpoint(flow, item, partner).distance_to(board.pointer - board.grab + Vector2.ONE * board.CELL * 0.5) < 0.1, "Regrabbing and moving keeps the same pair attached")
	board.drop_at(board.ORIGIN + Vector2(2, 5) * board.STEP + Vector2(35, 31))
	board._process(0.30)
	check(board.hovered_id == item["id"] and not flow_for(board, item, partner).is_empty(), "Repeated drop retains stationary hover and the trail")
	# Moving the other endpoint must also keep its trail attached.
	board._start_motion(partner, board.item_rect(partner).position + Vector2(60, 0), false)
	board._process(0.01)
	flow = flow_for(board, item, partner)
	displayed = board._motion_position(board.item_motions[partner["id"]]) + Vector2.ONE * board.CELL * 0.5
	check(not flow.is_empty() and endpoint(flow, partner, item).distance_to(displayed) < 0.1, "Moving partner endpoint follows its display position too")
	board._clear_hover()
	board._process(0.01)
	flow = flow_for(board, item, partner)
	displayed = board._motion_position(board.item_motions[partner["id"]]) + Vector2.ONE * board.CELL * 0.5
	check(not flow.is_empty() and endpoint(flow, partner, item).distance_to(displayed) < 0.1, "Even fading trails follow moving endpoints without leaving old-position ghosts")
	board._process(0.30)
	board._start_motion(item, board.item_rect(item).position + Vector2(40, 0), false)
	board._process(0.03)
	displayed = board._motion_position(board.item_motions[item["id"]]) + Vector2.ONE * board.CELL * 0.5
	check(board.hit_item(displayed) == item, "A settling item is hit at its visible location")
	board.begin_drag(item, displayed)
	check(not board.item_motions.has(item["id"]), "Regrab interrupts settling instead of rendering a duplicate slide")
	check(board.visual_item_cells(item)[0].distance_to(displayed) < 0.1, "Mid-slide regrab preserves the displayed item and trail anchor")
	board.queue_free()
	await process_frame
	print("CRAFTING DRAG ATTACHMENT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
