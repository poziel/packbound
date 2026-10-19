extends SceneTree
var checks: int = 0
var failures: int = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func fixture() -> PackRun:
	var run := PackRun.new()
	run.reset(42)
	run.items.clear()
	run.relics.clear()
	return run
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var crafting: Variant = PackRun.CRAFTING.new()
	var run := fixture()
	run.add_item("bandage", Vector2i.ZERO)
	run.add_item("bandage", Vector2i.RIGHT)
	run.add_item("antidote", Vector2i(2, 0))
	run.start_combat()
	check(run.items.size() == 1 and run.items[0]["key"] == "healing_herbs", "Crafting can place an output beyond its ingredients' old footprint")
	run = fixture()
	run.add_item("bandage", Vector2i.ZERO)
	run.add_item("bandage", Vector2i.RIGHT)
	run.add_item("antidote", Vector2i(2, 0))
	for y in PackRun.GRID.y:
		for x in PackRun.GRID.x:
			if y == 0 and x < 3:
				continue
			run.add_item("iron_charm", Vector2i(x, y))
	var before: int = run.items.size()
	run.start_combat()
	var herbs: Array[Dictionary] = run.items.filter(func(item: Dictionary) -> bool: return item["key"] == "healing_herbs")
	check(herbs.size() == 1 and herbs[0]["cell"] == null, "Crafted result goes to stash when no rotation fits the grid")
	check(run.items.size() == before - 2, "Stash fallback consumes ingredients exactly once without losing the result")
	run = fixture()
	var a: Dictionary = run.add_item("rusty_knife", Vector2i.ZERO)
	run.add_item("rusty_knife", Vector2i.RIGHT)
	var playback := PackCombatPlayback.new()
	root.add_child(playback)
	check(playback.start(run, 4.0, 0.18, 0.18), "Crafting starts through combat playback")
	check(run.pending_turn.is_empty() and run.enemy["hp"] == run.enemy["max_hp"], "First attack waits for the craft animation")
	check(playback.snapshot().get("crafting_wait", false), "Craft presentation wait is saved explicitly")
	playback.set_paused(true)
	var remaining: float = playback.remaining_seconds
	playback._process(0.2)
	check(playback.remaining_seconds == remaining, "Pause freezes the precombat crafting wait")
	var snapshot: Dictionary = playback.snapshot()
	playback.cancel()
	playback.restore(run, snapshot)
	check(playback.snapshot().get("crafting_wait", false) and playback.paused, "Saved crafting wait restores paused without crafting twice")
	playback.set_paused(false)
	playback._process(2.0)
	check(not run.pending_turn.is_empty(), "First attack starts when crafting presentation ends")
	playback.cancel()
	playback.queue_free()
	check(crafting.has_method("attempts"), "Partial crafting attempts are exposed for presentation")
	if crafting.has_method("attempts"):
		run = fixture()
		var bandage: Dictionary = run.add_item("bandage", Vector2i.ZERO)
		run.add_item("antidote", Vector2i.RIGHT)
		var attempts: Array = crafting.attempts(run)
		check(attempts.size() == 1 and attempts[0]["count"] == 2 and attempts[0]["total"] == 3 and not attempts[0]["ready"], "Adjacent incomplete recipe shows 2/3")
		check(PackRun.CRAFTING.plans(run).is_empty(), "Partial recipe cannot merge")
		var extra: Dictionary = run.add_item("bandage", Vector2i(5, 5))
		check(crafting.partners(run, extra).size() == 2, "Hover partners include compatible packed items at a distance")
		extra["cell"] = Vector2i(1, 1)
		attempts = crafting.attempts(run)
		check(attempts.size() == 1 and attempts[0]["count"] == 3 and attempts[0]["ready"], "Third connected ingredient upgrades attempt to 3/3")
		extra["cell"] = null
		check(crafting.partners(run, extra).size() == 2, "Held or stashed ingredient can discover packed partners")
		check(crafting.attempts(run)[0]["count"] == 2, "Stashed ingredient does not satisfy the nearby count")
	await _presentation_checks()
	await _stash_and_resume_checks()
	await process_frame
	print("CRAFTING EXPERIENCE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _stash_and_resume_checks() -> void:
	var game: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.run_saves.directory = "res://.tmp/crafting-experience-saves"
	game.start_run("warrior", 42)
	game.run.items.clear()
	game.run.add_item("bandage", Vector2i.ZERO)
	game.run.add_item("bandage", Vector2i.RIGHT)
	game.run.add_item("antidote", Vector2i(2, 0))
	for y in PackRun.GRID.y:
		for x in PackRun.GRID.x:
			if y != 0 or x >= 3:
				game.run.add_item("iron_charm", Vector2i(x, y))
	game._refresh()
	game._act()
	var output: Dictionary = game.run.items.filter(func(item: Dictionary) -> bool: return item["key"] == "healing_herbs")[0]
	check(output["cell"] == null and game.board.is_crafting_hidden(output["id"]), "Stash result stays hidden until its craft animation finishes")
	check(game.run.pending_turn.is_empty(), "Real game does not attack during convergence")
	var saved: Dictionary = game.run_saves.capture(game.run, 0.0, game.playback)
	saved["id"] = "crafting-resume"
	game.start_run("warrior", 42, saved)
	check(game.playback.paused and game.board._crafting_bursts.size() == 1, "Real game rebuilds the paused convergence effect after restore")
	check(game.run.items.filter(func(item: Dictionary) -> bool: return item["key"] == "healing_herbs").size() == 1, "Restore does not duplicate the result")
	game.playback.set_paused(false)
	game.board._process(PackRun.CRAFTING.ANIMATION_SECONDS + 0.1)
	check(game.board._crafting_bursts.is_empty(), "Presentation ends after the convergence and travel")
	check(game.storage.bodies.has(output["id"]), "Completed stash fallback creates the real physics item")
	check(game.board.unpacked().size() == 1, "Stash result remains in owned inventory after the animation")
	await preload("res://tests/automatic_combat_cleanup.gd").release(self, game)

func _presentation_checks() -> void:
	var board: BackpackBoard = load("res://scenes/game/inventory/backpack.tscn").instantiate()
	board.run = fixture()
	var source: Dictionary = board.run.add_item("rusty_knife", Vector2i.ZERO)
	board.run.add_item("rusty_knife", Vector2i(5, 0))
	root.add_child(board)
	board.set_process(false)
	board.hovered_id = source["id"]
	var presentation: Variant = board.CRAFTING_PRESENTATION.new()
	check(presentation.has_method("advance"), "Crafting presentation has timed hover transitions and label lifetimes")
	if presentation.has_method("advance"):
		board._process(0.035)
		check(board._crafting_hover.size() == 1 and board._crafting_hover.values()[0]["alpha"] > 0.0 and board._crafting_hover.values()[0]["alpha"] < 1.0, "Hover effect fades in instead of snapping on")
		board._process(0.035)
		check(is_equal_approx(float(board._crafting_hover.values()[0]["alpha"]), 1.0), "Hover trail completes its fade-in within 0.07 seconds")
		var flow_key: String = board._crafting_hover.keys()[0]
		board.run.items[1]["cell"] = Vector2i.RIGHT
		board._process(0.01)
		check(board._crafting_hover.has(flow_key) and is_equal_approx(float(board._crafting_hover[flow_key]["alpha"]), 1.0), "Touching preserves the existing trail instead of restarting its fade")
		board._process(0.25)
		check(float(board._crafting_hover[flow_key].get("strength", 0.0)) > 0.99, "Existing trail blends to the brighter ready state")
		var moved: Dictionary = board.run.items[1]
		board._start_motion(moved, board.item_rect(moved).position - Vector2(30, 0), false)
		board._process(0.01)
		check(board._crafting_hover.has(flow_key) and float(board._crafting_hover[flow_key]["alpha"]) > 0.99, "Drop settling preserves the same uninterrupted ready trail")
		board._process(0.25)
		board._crafting_clock = 19.99
		board._process(0.02)
		check(board._crafting_clock > 20.0, "Craft animation clock never jumps backwards at the old loop boundary")
		board.run.items[1]["cell"] = Vector2i(5, 0)
		board.hovered_id = -1
		board._process(0.05)
		check(not board._crafting_hover.is_empty(), "Hover effect remains briefly during fade out")
		board._process(0.4)
		check(board._crafting_hover.is_empty(), "Hover effect disappears completely after its fade")
		board.run = fixture()
		board.run.add_item("bandage", Vector2i.ZERO)
		var before_partial: Array[String] = board.crafting_opportunity_keys()
		board.run.add_item("antidote", Vector2i.RIGHT)
		board.notify_craft_placement(before_partial)
		board._process(0.2)
		var attempt: Dictionary = board.crafting_attempts()[0]
		check(presentation.label_opacity(board, attempt) > 0.0, "New attempt briefly shows its name and ingredient count")
		var tooltips: Variant = board.get("_crafting_tooltips")
		check(tooltips is Dictionary and tooltips.size() == 1 and tooltips.values()[0] is PackInspectWindow, "Crafting popup instances the game's official inspection tooltip")
		board._process(5.0)
		check(presentation.label_opacity(board, attempt) == 0.0, "Recipe name and count disappear by five seconds")
		check(board._crafting_tooltips.is_empty(), "Official recipe tooltip is removed at its five-second limit")
		board._process(1.0)
		check(presentation.label_opacity(board, attempt) == 0.0, "Unchanged nearby items cannot restart the label timer")
		var before_complete: Array[String] = board.crafting_opportunity_keys()
		board.run.add_item("bandage", Vector2i.ONE)
		board.notify_craft_placement(before_complete)
		board._process(0.2)
		attempt = board.crafting_attempts()[0]
		check(attempt["ready"] and presentation.label_opacity(board, attempt) > 0.0, "Changing requirements reopens the label briefly with the new count")
	board.queue_free()
	await process_frame
