extends "res://tests/support/test_case.gd"
func _initialize() -> void:
	if not require_isolation():
		return
	_run.call_deferred()
func _run() -> void:
	var inspector := PackInspector.new()
	root.add_child(inspector)
	inspector.set_process(false)
	inspector.source = inspector
	inspector._spawn({"key": "iron_charm", "title": "Iron Charm", "body": "Block"}, Rect2(10, 10, 64, 64), -1)
	for index in 55:
		var parent_index: int = inspector.windows.size() - 1
		var ancestor: PackInspectWindow = inspector.windows[parent_index]
		ancestor.set_locked(true)
		inspector.active_parent = parent_index
		inspector.active_trigger_id = "occurrence_%d" % index
		inspector.active_trigger_rect = Rect2(30, 30, 80, 24)
		var key: String = "block" if index % 2 == 0 else "plating"
		inspector._open_definition(PackKeywordLinks.entry(key), parent_index)
		check(inspector.windows.size() == index + 2, "Repeated subject adds descendant at depth %d" % (index + 1))
		if inspector.windows.size() != index + 2: break
		check(inspector.windows[parent_index] == ancestor, "Repeated subject preserves its containing tooltip")
		inspector._open_definition(PackKeywordLinks.entry(key), parent_index)
		check(inspector.windows.size() == index + 2, "Same trigger occurrence reuses its open descendant")
	check(inspector.windows.size() == 56, "Chain exceeds 50 tooltips without a depth limit")
	if inspector.windows.size() == 56:
		inspector.windows.back().set_locked(true)
		for frame in 10: await process_frame
		await create_timer(0.2).timeout
		var rendered: int = 0
		for window: PackInspectWindow in inspector.windows:
			if window._placed and window.modulate.a > 0.0:
				rendered += 1
		check(rendered == 56, "All 56 tooltip instances can be laid out and shown together")
	inspector.clear()
	check(inspector.windows.is_empty(), "Entire repeated chain closes normally")
	inspector.queue_free()
	await process_frame
	await process_frame
	report("REPEATED TOOLTIPS")
	quit(1 if failures else 0)
