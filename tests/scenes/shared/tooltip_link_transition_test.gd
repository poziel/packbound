extends "res://tests/support/test_case.gd"
var inspector: PackInspector
var view: SubViewport
var root_window: PackInspectWindow

func _initialize() -> void:
	if not require_isolation():
		return
	_run.call_deferred()

func motion(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	view.push_input(event, true)

func find_link(key: String) -> Vector2:
	var rect: Rect2 = root_window.body.get_global_rect()
	for y in range(10, int(rect.size.y), 12):
		for x in range(12, 220, 12):
			motion(rect.position + Vector2(x, y))
			await process_frame
			if root_window._hovered_keyword == key:
				return rect.position + Vector2(x, y)
	return Vector2.INF

func _run() -> void:
	create_timer(30).timeout.connect(func() -> void: quit(2))
	view = SubViewport.new()
	view.size = Vector2i(1000, 720)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	view.notify_mouse_entered()
	inspector = PackInspector.new()
	inspector.show_delay = 0.08
	inspector.lock_delay = 0.15
	view.add_child(inspector)
	inspector.source = inspector
	inspector.source_rect = Rect2(8, 8, 20, 20)
	inspector.pointer = Vector2(12, 12)
	var item: Dictionary = PackCatalog.item("ember_tome")
	var data: Dictionary = preload("res://systems/items/item_presentation.gd").catalog_inspection("ember_tome")
	data["body"] = "Fire. Damage, damage, and damage. Burn and damage."
	inspector._spawn(data, Rect2(20, 30, 60, 60), -1)
	root_window = inspector.windows[0]
	root_window.set_locked(true)
	for i in 5: await process_frame
	var points: Dictionary = {}
	for key: String in ["damage", "burn", "fire"]:
		points[key] = await find_link(key)
		check(points[key].is_finite(), "Native pointer can locate " + key)
	for cycle in 4:
		for key: String in ["damage", "burn", "fire", "damage"]:
			if not points[key].is_finite(): continue
			motion(root_window.global_position + Vector2(12, 12))
			await create_timer(0.03).timeout
			motion(points[key])
			for tick in 30:
				for sample in 12:
					motion(points[key] + Vector2(sample % 2, 0))
				await create_timer(0.01).timeout
			check(inspector.windows.size() == 2 and inspector.windows[1].key == key, "Switching to %s opens its definition without clicking (cycle %d)" % [key, cycle])
			if inspector.windows.size() > 1:
				motion(inspector.windows[1].global_position + Vector2(15, 15))
				await create_timer(0.19).timeout
				check(inspector.windows.size() == 2 and inspector.windows[1].locked, "Crossing into nested tooltip locks it normally")
	view.queue_free()
	await process_frame
	report("TOOLTIP TRANSITIONS")
	quit(1 if failures else 0)
