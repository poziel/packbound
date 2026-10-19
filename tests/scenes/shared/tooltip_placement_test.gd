extends "res://tests/support/test_case.gd"
var view: SubViewport
var inspector: PackInspector

func motion(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	view.push_input(event, true)

func settle() -> void:
	for i in 10: await process_frame
	await create_timer(0.14).timeout

func _initialize() -> void:
	if not require_isolation():
		return
	_run.call_deferred()

func root_tooltip(data: Dictionary) -> PackInspectWindow:
	inspector.clear()
	inspector.source = inspector
	inspector.source_rect = Rect2(20, 30, 64, 64)
	inspector._spawn(data, inspector.source_rect, -1)
	inspector.windows[0].set_locked(true)
	return inspector.windows[0]

func _run() -> void:
	create_timer(30).timeout.connect(func() -> void: quit(2))
	view = SubViewport.new()
	view.size = Vector2i(1280, 900)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	view.notify_mouse_entered()
	inspector = PackInspector.new()
	view.add_child(inspector)
	inspector.set_process(false)
	var window: PackInspectWindow = root_tooltip({"key": "wrapped", "title": "Wrapped keyword", "body": "[url=block]Block protection can cover many consecutive attacks across several lines of explanatory text.[/url]"})
	await settle()
	var occurrence: String = window._link_keys.keys()[0]
	var fragments: Array[Rect2] = window._hover_effect.trigger_fragments(occurrence)
	check(fragments.size() > 1, "Wrapped keyword exposes separate rendered line fragments")
	for fragment: Rect2 in fragments:
		var expected: Rect2 = window.body.get_global_transform_with_canvas() * fragment
		motion(expected.get_center())
		await process_frame
		check(window._hovered_keyword == "block", "Rendered line fragment matches native hover")
		expected = window.body.get_global_transform_with_canvas() * fragment
		check(window.trigger_rect(expected.get_center()).is_equal_approx(expected), "Wrapped keyword anchors to hovered line rather than whole label")
	var fragment: Rect2 = window.trigger_rect(inspector.pointer)
	inspector._open_keyword_link("block", 0)
	await settle()
	var descendant: PackInspectWindow = inspector.windows[1]
	var original_position: Vector2 = descendant.position
	motion(fragment.position + Vector2(5, fragment.size.y * 0.5))
	await process_frame
	inspector._open_keyword_link("block", 0)
	await settle()
	check(inspector.windows.size() == 2 and descendant.position == original_position, "Moving within one keyword keeps placement and instance stable")
	var knife: Dictionary = PackCatalog.item("rusty_knife")
	var recipe_data: Dictionary = PackRun.CRAFTING.recipe_inspection(null, knife)
	recipe_data["recipes"] = [{"ingredients": [knife, knife], "output": knife}]
	window = root_tooltip(recipe_data)
	await settle()
	var first: Control = window.recipe_view.items[0]
	var second: Control = window.recipe_view.items[1]
	motion(first.get_global_rect().get_center())
	await process_frame
	var first_id: String = inspector.active_trigger_id
	inspector._open_keyword_link("recipe_item_rusty_knife", 0)
	await settle()
	descendant = inspector.windows[1]
	check(descendant.trigger_bounds.is_equal_approx(first.get_global_rect()), "Recipe tooltip anchors to complete ingredient bounds")
	original_position = descendant.position
	motion(first.get_global_rect().position + Vector2(8, 8))
	await process_frame
	inspector._open_keyword_link("recipe_item_rusty_knife", 0)
	await settle()
	check(inspector.windows[1] == descendant and descendant.position == original_position, "Different pointer positions within ingredient keep identical placement")
	motion(second.get_global_rect().get_center())
	await process_frame
	check(inspector.active_trigger_id != first_id, "Identical recipe ingredients have separate trigger occurrences")
	var previous_instance: int = descendant.get_instance_id()
	inspector._open_keyword_link("recipe_item_rusty_knife", 0)
	await settle()
	check(inspector.windows[1].get_instance_id() != previous_instance and inspector.windows[1].trigger_bounds.is_equal_approx(second.get_global_rect()), "Second identical ingredient opens at its own bounds")
	view.size = Vector2i(900, 650)
	await settle()
	await settle()
	check(inspector.windows.size() == 2 and inspector.windows[1].trigger_bounds.is_equal_approx(second.get_global_rect()), "Viewport resize reanchors descendant to its recipe trigger")
	for tooltip: PackInspectWindow in inspector.windows:
		check(tooltip.get_global_rect().end.x <= view.size.x - 12 and tooltip.get_global_rect().end.y <= view.size.y - 12, "Reflow keeps tooltip inside resized viewport")
	view.size = Vector2i(1280, 900)
	await settle()
	for anchor: Rect2 in [Rect2(20, 20, 64, 64), Rect2(1150, 20, 64, 64), Rect2(20, 600, 64, 64), Rect2(1150, 600, 64, 64), Rect2(150, 40, 980, 50), Rect2(150, 620, 980, 50)]:
		var rect: Rect2 = PackInspector.placement_rect(anchor, Vector2(400, 300), Vector2(1280, 720), 4)
		check(Rect2(12, 12, 1256, 692).encloses(rect), "Edge placement stays within viewport margins")
		check(not rect.intersects(anchor.grow(11.9)), "Edge placement preserves trigger padding")
	window = root_tooltip({"key": "long", "title": "Long explanation", "body": "A long explanation of the available effects. ".repeat(180)})
	await settle()
	check(window.body.scroll_active, "Oversized explanation scrolls instead of overflowing")
	check(window.get_global_rect().end.y <= view.size.y - 12, "Oversized tooltip fits viewport vertically")
	check(not window.get_global_rect().intersects(inspector.source_rect), "Oversized tooltip avoids covering its trigger")
	var log_label := RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.position = Vector2(10, 600)
	log_label.size = Vector2(700, 100)
	view.add_child(log_label)
	inspector.set_link_text(log_label, "[url=block]Block[/url] and [url=block]another Block[/url]")
	await settle()
	var geometry = log_label.get_meta("keyword_geometry")
	var log_ids: Array = geometry.fragments.keys()
	check(log_ids.size() == 2, "Repeated root log keywords have distinct measured occurrences")
	for id: String in log_ids:
		var local_rect: Rect2 = geometry.trigger_fragments(id)[0]
		var expected: Rect2 = log_label.get_global_transform_with_canvas() * local_rect
		check(inspector.link_rect(log_label, "block", expected.get_center()).is_equal_approx(expected), "Log keyword uses its actual occurrence bounds")
	view.queue_free()
	await process_frame
	report("TOOLTIP PLACEMENT")
	quit(1 if failures else 0)
