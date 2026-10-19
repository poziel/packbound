extends SceneTree

var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var run := PackRun.new()
	run.reset(42)
	run.items.clear()
	var first: Dictionary = run.add_item("rusty_knife", Vector2i.ZERO)
	var second: Dictionary = run.add_item("rusty_knife", Vector2i.RIGHT)
	var crafting = PackRun.CRAFTING.new()
	check(crafting.has_method("toggle_lock"), "Pending crafts can be locked")
	if crafting.has_method("toggle_lock"):
		crafting.toggle_lock(run, first)
		check(PackRun.CRAFTING.plans(run).is_empty(), "Locked ingredient blocks automatic crafting")
		check(PackRun.CRAFTING.attempts(run).is_empty(), "Locked ingredients are excluded from crafting previews")
		second["cell"] = Vector2i(5, 5)
		PackRun.CRAFTING.plans(run)
		second["cell"] = Vector2i.RIGHT
		check(PackRun.CRAFTING.plans(run).is_empty(), "Separating ingredients preserves the lock")
		crafting.toggle_lock(run, first)
		check(PackRun.CRAFTING.plans(run).size() == 1, "Right-click toggles the lock off")
		run.items.clear()
		var bandage: Dictionary = run.add_item("bandage", Vector2i.ZERO)
		run.add_item("antidote", Vector2i.RIGHT)
		crafting.toggle_lock(run, bandage)
		run.add_item("bandage", Vector2i.ONE)
		check(PackRun.CRAFTING.plans(run).is_empty() and bandage.has("craft_lock"), "Completing a partial recipe preserves its ingredient lock")
		check(run.start_combat() and run.items.size() == 3, "Starting battle does not consume locked recipe ingredients")
		check(bandage.has("craft_lock"), "Unchanged crafting positions retain locks across battle start")
		run.combat_state = PackRun.CombatState.PREPARING
		check(PackRun.CRAFTING.plans(run).is_empty(), "Unchanged locked ingredients remain protected in the next preparation")
	check(crafting.has_method("recipe_inspection"), "Alt inspection exposes every recipe")
	if crafting.has_method("recipe_inspection"):
		var data: Dictionary = crafting.recipe_inspection(run, first)
		check(data.get("definitions", {}).size() == 2, "Recipe includes inspectable ingredient and output")
		check(data["recipes"][0]["ingredients"][0]["key"] == "rusty_knife" and data["recipes"][0]["output"]["key"] == "longsword", "Recipe exposes ingredient and result items")
		for amount in [4, 5, 6]:
			run.reset(42)
			run.items.clear()
			var keys: Array = []
			for x in amount:
				run.add_item("bandage", Vector2i(x, 0))
				keys.append("bandage")
			var recipe: Dictionary = {"id": "large_test", "ingredients": keys, "result": "healing_herbs"}
			var chosen: Array[Dictionary] = []
			var matched: Dictionary = PackRun.CRAFTING._match(run, recipe, run.packed(), chosen, 0)
			check(matched.get("components", []).size() == amount, "%d-ingredient recipe matches without a pair limit" % amount)
		await _ui_checks()
	print("CRAFT LOCK: %d failures" % failures)
	quit(1 if failures else 0)

func _ui_checks() -> void:
	var board: BackpackBoard = load("res://scenes/game/inventory/backpack.tscn").instantiate()
	board.run = PackRun.new()
	board.run.reset(42)
	board.run.items.clear()
	var item: Dictionary = board.run.add_item("rusty_knife", Vector2i.ZERO)
	var partner: Dictionary = board.run.add_item("rusty_knife", Vector2i.RIGHT)
	root.add_child(board)
	board.set_process(false)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	click.position = board.item_rect(item).get_center()
	board._gui_input(click)
	check(item.has("craft_lock"), "Right-click through the board locks a pending ingredient")
	board.hovered_id = item["id"]
	board._process(0.1)
	check(board._crafting_hover.is_empty(), "Locked crafts have no connection trails even while hovered")
	board.begin_drag(partner, board.item_rect(partner).get_center())
	check(item.has("craft_lock"), "Picking up a partner preserves independent locks")
	board.cancel_drag()
	item["mask"] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)]
	item["shape"] = Vector2i(3, 3)
	check(board.craft_lock_rect(item).position == board.item_rect(item).position + Vector2(board.STEP + board.CELL - 22, 6), "Cross mask places its lock at the top-right occupied tile")
	item["mask"] = [Vector2i.ZERO]
	item["shape"] = Vector2i.ONE
	var inspector := PackInspector.new()
	inspector.lock_delay = 0.8
	root.add_child(inspector)
	inspector.set_process(false)
	var data: Dictionary = PackRun.CRAFTING.recipe_inspection(board.run, item)
	inspector.source = board
	inspector.source_rect = board.get_global_rect()
	inspector.pointer = Vector2(40, 40)
	var alt := InputEventKey.new()
	alt.keycode = KEY_ALT
	alt.pressed = true
	Input.parse_input_event(alt.duplicate())
	inspector._spawn(data, Rect2(200, 30, 40, 40), -1)
	inspector._process(0.5)
	check(not inspector.windows[0].locked, "Alt preview waits for the shared tooltip delay")
	inspector._process(0.4)
	check(inspector.windows[0].locked, "Alt preview pins after the shared tooltip delay")
	alt.pressed = false
	Input.parse_input_event(alt.duplicate())
	inspector._process(0.01)
	check(inspector.windows.size() == 1, "Pinned recipe survives releasing Alt")
	inspector._open_keyword_link("recipe_item_longsword", 0)
	check(inspector.windows.size() == 2 and inspector.windows[1].key == "recipe_item_longsword", "Result link opens the official nested item inspector")
	inspector.pointer = Vector2(-500, -500)
	inspector._process(0.5)
	check(inspector.windows.is_empty(), "Leaving the inspection chain dismisses the pinned recipe")
	alt.pressed = true
	Input.parse_input_event(alt.duplicate())
	inspector.source = board
	inspector._spawn(data, Rect2(200, 30, 40, 40), -1)
	inspector._process(0.1)
	alt.pressed = false
	Input.parse_input_event(alt.duplicate())
	inspector._process(0.01)
	check(inspector.windows.is_empty(), "Releasing Alt before pinning dismisses the preview")
	inspector.queue_free()
	board.queue_free()
	await process_frame
