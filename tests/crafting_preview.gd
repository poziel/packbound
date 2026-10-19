extends SceneTree
## Isolated backpack preview. --capture saves frames and exits; otherwise interactive.
var board: BackpackBoard

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.content_scale_size = Vector2i(584, 568)
	var run := PackRun.new()
	run.reset(42)
	run.items.clear()
	run.add_item("rusty_knife", Vector2i(0, 0))
	run.add_item("rusty_knife", Vector2i(1, 0))
	run.add_item("cracked_shield", Vector2i(3, 0))
	run.add_item("cracked_shield", Vector2i(4, 0))
	run.add_item("bandage", Vector2i(0, 2))
	run.add_item("bandage", Vector2i(1, 2))
	run.add_item("antidote", Vector2i(1, 3))
	var backdrop := ColorRect.new()
	backdrop.color = Color("101317")
	backdrop.size = Vector2(584, 568)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(backdrop)
	board = load("res://scenes/game/inventory/backpack.tscn").instantiate()
	board.run = run
	root.add_child(board)
	var start := Button.new()
	start.text = "Start battle · merge linked items"
	start.position = Vector2(22, 510)
	start.size = Vector2(540, 38)
	start.pressed.connect(func() -> void:
		if run.start_combat():
			board.show_crafting_merges(run.crafting_events)
			start.disabled = true)
	root.add_child(start)
	if not OS.get_cmdline_user_args().has("--capture"):
		return
	board.run.items[1]["cell"] = Vector2i(6, 1)
	board.hovered_id = int(board.run.items[0]["id"])
	await _capture("crafting-hover", 0.25)
	board.run.items[1]["cell"] = Vector2i(1, 0)
	board.hovered_id = -1
	board.run.items[6]["cell"] = Vector2i(6, 4)
	await _capture("crafting-partial", 0.25)
	board.run.items[6]["cell"] = Vector2i(1, 3)
	await _capture("crafting-ready-a", 0.2)
	await _capture("crafting-ready-b", 0.4)
	start.pressed.emit()
	await _capture("crafting-converging", 0.30)
	await _capture("crafting-burst", 0.32)
	await _capture("crafting-reveal", 0.20)
	await _capture("crafting-result", 0.65)
	print("CRAFTING PREVIEW: eight rendered stages saved")
	quit()

func _capture(label: String, seconds: float) -> void:
	await create_timer(seconds).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://workspace/logs/" + label + ".png")
