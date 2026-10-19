extends "res://tests/support/test_case.gd"
var view: SubViewport
var inspector: PackInspector

func motion(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	view.push_input(event, true)

func frames() -> void:
	for i in 5: await process_frame

func _initialize() -> void:
	if not require_isolation():
		return
	_run.call_deferred()

func _run() -> void:
	create_timer(30).timeout.connect(func() -> void: quit(2))
	view = SubViewport.new()
	view.size = Vector2i(1100, 700)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	view.notify_mouse_entered()
	var trigger := Control.new()
	trigger.position = Vector2(20, 50)
	trigger.size = Vector2(60, 60)
	view.add_child(trigger)
	inspector = PackInspector.new()
	view.add_child(inspector)
	inspector.set_process(false)
	inspector.register(trigger, func() -> Dictionary: return {"key": "root", "title": "Root", "body": "Damage and damage."})
	await frames()
	motion(Vector2(40, 70))
	await process_frame
	inspector._process(0.14)
	check(inspector.windows.is_empty(), "Root waits for opening delay")
	motion(Vector2(1000, 650))
	await process_frame
	inspector._process(0.01)
	motion(Vector2(40, 70))
	await process_frame
	inspector._process(0.14)
	check(inspector.windows.is_empty(), "Leaving and returning resets continuous opening delay")
	inspector._process(0.02)
	check(inspector.windows.size() == 1 and not inspector.windows[0].locked, "Root appears unlocked after opening delay")
	await frames()
	inspector._process(1.2)
	var window: PackInspectWindow = inspector.windows[0]
	check(window.locked, "Lock completes on root trigger")
	await frames()
	var point := Vector2.INF
	for x in range(25, 190, 5):
		motion(window.body.global_position + Vector2(x, 10))
		await process_frame
		if inspector.active_keyword_link == "damage":
			point = inspector.pointer
			break
	check(point.is_finite(), "Native pointer reaches descendant trigger")
	inspector._process(0.14)
	check(inspector.windows.size() == 1, "Descendant uses opening delay too")
	inspector._process(0.02)
	check(inspector.windows.size() == 2 and not inspector.windows[1].locked, "Descendant appears unlocked")
	await frames()
	var descendant: PackInspectWindow = inspector.windows[1]
	var actual_trigger: Rect2 = window.trigger_rect(point)
	check(actual_trigger.has_point(point) and actual_trigger.size.x > 16, "Keyword anchor covers its rendered icon and text")
	check(not descendant.get_global_rect().has_point(point), "Descendant placement leaves hovered trigger accessible")
	check(absf(descendant.position.x - (actual_trigger.end.x + 12)) <= 1, "Descendant anchors to keyword bounds with 12px gap")
	inspector._process(1.2)
	check(descendant.locked, "Descendant locks by staying on its trigger")
	await frames()
	motion(descendant.get_global_rect().end - Vector2(25, 20))
	await process_frame
	inspector._process(0)
	check(descendant.entered and inspector.windows.size() == 2, "Entering locked descendant preserves chain")
	motion(window.global_position + Vector2(20, 15))
	await process_frame
	inspector._process(0.69)
	check(inspector.windows.size() == 2, "Ancestor return allows closing delay")
	inspector._process(0.02)
	check(inspector.windows.size() == 1, "Ancestor return dismisses descendant after delay")
	inspector.clear()
	inspector.show_delay = 0
	inspector.lock_delay = 0
	motion(Vector2(40, 70))
	await process_frame
	inspector._process(0)
	check(inspector.windows.size() == 1 and inspector.windows[0].locked, "Zero opening and lock delays work together")
	view.queue_free()
	await process_frame
	report("TOOLTIP OPENING")
	quit(1 if failures else 0)
