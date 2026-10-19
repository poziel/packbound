extends "res://tests/support/test_case.gd"

func _initialize() -> void:
	if not require_isolation():
		return
	_run.call_deferred()

func _run() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(1280, 900)
	root.add_child(view)
	var inspector := PackInspector.new()
	view.add_child(inspector)
	inspector.source = inspector
	inspector.source_rect = Rect2(1200, 800, 20, 20)
	var locations: Array[Vector2] = [Vector2(10, 10), Vector2(650, 10), Vector2(10, 400), Vector2(650, 400)]
	for key in ["curse", "damage", "poison", "cleanse"]:
		inspector._spawn(PackKeywordLinks.entry(key), Rect2(), inspector.windows.size() - 1)
		inspector.windows.back().set_locked(true)
	# Placement measures content across several frames before showing the windows.
	while inspector.windows.any(func(window: PackInspectWindow) -> bool: return not window._placed):
		await process_frame
	for i in 4:
		inspector.windows[i].position = locations[i]
	inspector.pointer = locations[3] + Vector2(20, 15)
	inspector._process(0.01)
	check(inspector.windows.size() == 4, "Entering deepest tooltip keeps ancestors")
	inspector.pointer = locations[2] + Vector2(20, 15)
	inspector._process(inspector.closing_delay + 0.01)
	check(inspector.windows.size() == 3, "Returning to Poison removes Cleanse")
	inspector.pointer = locations[0] + Vector2(20, 15)
	inspector._process(inspector.closing_delay + 0.01)
	check(inspector.windows.size() == 1, "Returning to root removes all descendants")
	inspector.pointer = Vector2(1270, 890)
	inspector._process(1)
	check(inspector.windows.is_empty(), "Leaving entire stack closes all tooltips")
	view.queue_free()
	await process_frame
	report("TOOLTIP STACK RETURN")
	quit(1 if failures else 0)
