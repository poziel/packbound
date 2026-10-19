extends "res://tests/support/test_case.gd"

var game
var view: SubViewport

func _initialize() -> void:
	if not require_isolation():
		return
	_run.call_deferred()

func settle() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func capture(name: String) -> void:
	view.get_texture().get_image().save_png(preload("res://tests/support/artifact_paths.gd").path("stash-drag-review/") + name + ".png")

func _run() -> void:
	create_timer(30).timeout.connect(func(): quit(2))
	view = SubViewport.new()
	view.size = Vector2i(1280, 800)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	game = load("res://scenes/main.tscn").instantiate()
	view.add_child(game)
	await process_frame
	game.start_run("warrior", 42)
	game.run.items.clear()
	game.run.relics.clear()
	var item: Dictionary = game.run.add_item("bandage", Vector2i.ZERO)
	var shield: Dictionary = game.run.add_item("cracked_shield", Vector2i(4, 0))
	game._refresh()
	await settle()
	game._toggle_storage()
	await settle()
	check(game.storage.z_index > game.enemy_vitals.z_index, "Stash draws above projected enemy vitals")
	capture("stash-panel")
	game._close_storage()
	var board: BackpackBoard = game.board
	board.begin_drag(item, board.item_rect(item).get_center())
	board.pointer += Vector2(17, 0)
	board.queue_redraw()
	await settle()
	var socket: CanvasItem = board.get_node("Cell2_1")
	var transform: Transform2D = board.get_global_transform_with_canvas()
	var region := Rect2i(Vector2i(transform * (BackpackBoard.ORIGIN + Vector2(25, 8))), Vector2i(Vector2(48, 48) * transform.get_scale()))
	var with_socket := view.get_texture().get_image().get_region(region)
	socket.hide()
	await RenderingServer.frame_post_draw
	var without_socket := view.get_texture().get_image().get_region(region)
	check(with_socket.get_data() == without_socket.get_data(), "Socket cannot draw grid lines over the floating item")
	socket.show()
	capture("floating-item")
	var before: Array[Dictionary] = game.run.items.duplicate(true)
	var resources: Dictionary = game.run.starting_resources()
	board.pointer = BackpackBoard.ORIGIN + Vector2(shield["cell"]) * BackpackBoard.STEP + board.grab
	check(board.candidate_valid(), "Overlap still provides a valid swap destination")
	check(board.preview_starting_resources() == resources, "Hovering shield keeps its displayed resources until drop")
	check(board.preview_effects() == game.run.effects(), "Swap hover keeps current item effects")
	check(game.run.items == before, "Hover does not mutate inventory")
	game._refresh()
	await settle()
	capture("hover-shield")
	board.drop_at(board.pointer)
	check(shield["cell"] == null and board.dragging == shield, "Actual drop still hands shield to cursor")
	check(board.preview_starting_resources()["block"] == 0, "Dropped swap updates resources after shield leaves backpack")
	board.cancel_drag()
	await settle()
	check(board.get_node("Cell2_1").visible, "Grid cell returns after drag ends")
	game.run.items.clear()
	var herbs: Dictionary = game.run.add_item("healing_herbs", Vector2i(1, 1))
	game._refresh()
	await settle()
	board.begin_drag(herbs, board.item_rect(herbs).position + Vector2(32, 32))
	var sockets_remain := true
	for offset: Vector2 in [Vector2(17, 0), Vector2(34, 17), Vector2(51, 34), Vector2(68, 51), Vector2(85, 68)]:
		board.pointer = BackpackBoard.ORIGIN + Vector2(1, 1) * BackpackBoard.STEP + board.grab + offset
		board.queue_redraw()
		await settle()
		for y in PackRun.GRID.y:
			for x in PackRun.GRID.x:
				sockets_remain = sockets_remain and board.get_node("Cell%d_%d" % [x + 1, y + 1]).visible
	check(sockets_remain, "Dragging Moonleaf Herbs between cells never hides empty sockets")
	capture("herbs-between-cells")
	board.drop_at(board.pointer)
	await settle()
	var sliding_sockets_remain := true
	for y in PackRun.GRID.y:
		for x in PackRun.GRID.x:
			sliding_sockets_remain = sliding_sockets_remain and board.get_node("Cell%d_%d" % [x + 1, y + 1]).visible
	check(sliding_sockets_remain, "Slide animation never hides empty sockets")
	report("STASH DRAG RESULT")
	await preload("res://tests/support/automatic_combat_cleanup.gd").release(self, game, view)
	quit(1 if failures else 0)
