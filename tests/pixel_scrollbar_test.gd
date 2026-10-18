extends SceneTree

const SCROLLER: PackedScene = preload("res://components/pixel_scrollbar/pixel_scroll_container.tscn")
const SKIN: Theme = preload("res://themes/gameplay/theme.tres")
const MENU_SKIN: Theme = preload("res://themes/menu/theme.tres")
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _settle() -> void:
	for frame in range(6):
		await process_frame


func _mouse(at: Vector2, button: MouseButton, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = button
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed and button == MOUSE_BUTTON_LEFT else 0
	root.push_input(event, true)


func _motion(at: Vector2, dragging: bool = false) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if dragging else 0
	root.push_input(event, true)


func _key(code: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event, true)
	event = InputEventKey.new()
	event.keycode = code
	event.pressed = false
	root.push_input(event, true)


func _run() -> void:
	var scroll: ScrollContainer = SCROLLER.instantiate()
	scroll.theme = SKIN
	scroll.position = Vector2(32, 32)
	scroll.size = Vector2(320, 240)
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	root.add_child(scroll)
	await _settle()
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	check(not bar.visible, "Empty lists hide the scrollbar")
	for index in range(12):
		var item: Button = Button.new()
		item.text = "Item %d" % index
		item.custom_minimum_size = Vector2(80, 48)
		list.add_child(item)
	await _settle()
	check(bar.visible and bar.max_value > bar.page, "Adding items reveals a scrollable range")
	check(bar.size.x == 24, "Pixel track has a 24-pixel interaction width")
	check(not scroll.get_h_scroll_bar().visible, "Vertical lists do not create horizontal overflow")
	check(list.size.x <= scroll.size.x - bar.size.x, "Scrollbar reserves space beside content")
	check(bar.get_theme_stylebox("grabber") == SKIN.get_stylebox("grabber", "VScrollBar"), "Container uses the shared skin")
	_motion(Vector2(80, 80))
	_mouse(Vector2(80, 80), MOUSE_BUTTON_WHEEL_DOWN, true)
	_mouse(Vector2(80, 80), MOUSE_BUTTON_WHEEL_DOWN, false)
	await _settle()
	check(scroll.scroll_vertical > 0, "Wheel input over an item scrolls its parent")
	scroll.scroll_vertical = 0
	await _settle()
	var bottom: Vector2 = bar.global_position + Vector2(12, bar.size.y - 10)
	_motion(bottom)
	_mouse(bottom, MOUSE_BUTTON_LEFT, true)
	_mouse(bottom, MOUSE_BUTTON_LEFT, false)
	await _settle()
	check(scroll.scroll_vertical > 0, "Clicking the track pages the content")
	scroll.scroll_vertical = 0
	await _settle()
	var grab: Vector2 = bar.global_position + Vector2(12, 12)
	_motion(grab)
	_mouse(grab, MOUSE_BUTTON_LEFT, true)
	_motion(bottom, true)
	_mouse(bottom, MOUSE_BUTTON_LEFT, false)
	await _settle()
	check(is_equal_approx(bar.value, bar.max_value - bar.page), "Dragging the thumb reaches the last item")
	var native_scroll := ScrollContainer.new()
	var native_bar := native_scroll.get_v_scroll_bar()
	check(scroll.get_script() == null, "Container uses native scrolling without a script")
	check(bar.focus_mode == native_bar.focus_mode, "Scrollbar keeps native focus behavior")
	check(bar.custom_step == native_bar.custom_step, "Scrollbar keeps native step behavior")
	native_scroll.free()
	scroll.scroll_vertical = 0
	await _settle()
	list.get_child(-1).grab_focus()
	await _settle()
	check(scroll.get_global_rect().encloses(list.get_child(-1).get_global_rect()), "Focus following reveals offscreen items")
	scroll.size.y = 720
	await _settle()
	check(not bar.visible and scroll.scroll_vertical == 0, "Growing the viewport hides the bar and clamps the offset")
	scroll.size.y = 240
	await _settle()
	check(bar.visible, "Shrinking the viewport restores overflow")
	for item: Node in list.get_children():
		item.queue_free()
	await _settle()
	check(not bar.visible and bar.value == 0, "Removing all items clears overflow")
	scroll.queue_free()
	await _settle()

	var horizontal: ScrollContainer = SCROLLER.instantiate()
	horizontal.theme = SKIN
	horizontal.size = Vector2(300, 100)
	horizontal.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	horizontal.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var row: HBoxContainer = HBoxContainer.new()
	horizontal.add_child(row)
	for index in range(10):
		var item: Button = Button.new()
		item.custom_minimum_size = Vector2(100, 48)
		row.add_child(item)
	root.add_child(horizontal)
	await _settle()
	check(horizontal.get_h_scroll_bar().visible and not horizontal.get_v_scroll_bar().visible, "Horizontal mode shows only its own scrollbar")
	check(horizontal.get_h_scroll_bar().size.y == 24, "Horizontal skin has matching thickness")
	row.get_child(-1).grab_focus()
	await _settle()
	check(horizontal.scroll_horizontal > 0 and horizontal.get_global_rect().encloses(row.get_child(-1).get_global_rect()), "Horizontal focus reaches the final item")
	horizontal.queue_free()
	await _settle()

	var roster: Control = load("res://scenes/menus/class_selection.tscn").instantiate()
	root.add_child(roster)
	await _settle()
	var roster_scroll: ScrollContainer = roster.get_node("RosterScroll")
	check(not roster_scroll.get_v_scroll_bar().visible, "Current roster fits without a scrollbar")
	var grid: GridContainer = roster.get_node("RosterScroll/Margin/Characters")
	for index in range(25):
		var tile: Button = load("res://scenes/menus/delver_tile.tscn").instantiate()
		tile.class_key = "mage"
		grid.add_child(tile)
	await _settle()
	check(roster_scroll.get_v_scroll_bar().visible and roster_scroll.get_v_scroll_bar().get_theme_stylebox("grabber") == MENU_SKIN.get_stylebox("grabber", "VScrollBar"), "Expanded roster reveals the shared scrollbar")
	grid.get_child(-1).grab_focus()
	await _settle()
	check(roster_scroll.get_global_rect().encloses(grid.get_child(-1).get_global_rect()), "Expanded roster's final row remains reachable by focus")
	roster.queue_free()
	await _settle()

	var panel: Control = load("res://scenes/game/character/character_panel.tscn").instantiate()
	# Exercise the authored log and its inherited theme without starting inventory.
	var inventory: Node = panel.get_node("Tabs/Backpack/Inventory")
	inventory.free()
	var history: RichTextLabel = panel.find_child("History", true, false)
	root.add_child(panel)
	panel.get_node("Tabs").current_tab = panel.get_node("Tabs").get_tab_idx_from_control(history.get_parent())
	history.text = "A turn in the dungeon.\n".repeat(100)
	await _settle()
	check(history.get_v_scroll_bar().visible, "Long Battle Record remains scrollable")
	check(history.get_v_scroll_bar().get_theme_stylebox("grabber") == SKIN.get_stylebox("grabber", "VScrollBar"), "Battle Record uses the same scrollbar skin")
	check(history.get_theme_font_size("normal_font_size") == 24, "Scrollbar theme preserves inherited record typography")
	check(history.get_v_scroll_bar().value > 0, "Battle Record still follows new entries")
	panel.queue_free()
	await _settle()
	var demo: Control = load("res://components/pixel_scrollbar/demo.tscn").instantiate()
	root.add_child(demo)
	await _settle()
	check(demo.get_node("ItemScroll").get_v_scroll_bar().visible, "Demo opens with overflow")
	if DisplayServer.get_name() != "headless":
		_motion(Vector2(8, 8))
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/output/pixel-scrollbar-demo.png")
	demo._clear_items()
	await _settle()
	check(not demo.get_node("ItemScroll").get_v_scroll_bar().visible, "Demo clear action hides the scrollbar")
	demo.queue_free()
	await _settle()
	print("PIXEL SCROLLBAR RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
