extends "res://tests/support/test_case.gd"
## Run through tests/run_tests.ps1 -Test pixel_search_field. Artifacts use the isolated run directory.

const FIELD: PackedScene = preload("res://components/ui/inputs/pixel_search_field/pixel_search_field.tscn")
const DEMO: PackedScene = preload("res://components/ui/inputs/pixel_search_field/demo.tscn")
var submitted: String = ""
var changes: Array[String] = []

func _initialize() -> void:
	if not require_isolation():
		return
	_run.call_deferred()


func _key(code: Key, unicode_value: int = 0) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.unicode = unicode_value
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)

func _click(at: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	root.push_input(motion, true)
	for down: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)

func _visible_rows(list: Container) -> int:
	var count: int = 0
	for child: Node in list.get_children():
		if child is Control and child.visible:
			count += 1
	return count

func _capture(file_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(preload("res://tests/support/artifact_paths.gd").path("") + file_name)

func _run() -> void:
	root.size = Vector2i(1280, 800)
	root.notify_mouse_entered()
	var demo: Control = DEMO.instantiate()
	root.add_child(demo)
	await process_frame
	await process_frame
	var stats: Control = demo.get_node("Margin/Layout/Lists/Statistics/Inset/Content")
	var items: Control = demo.get_node("Margin/Layout/Lists/Items/Inset/Content")
	var search: PixelSearchField = stats.get_node("Search")
	var item_search: PixelSearchField = items.get_node("Search")
	var rows: Container = stats.get_node("Scroll/Rows")
	var item_rows: Container = items.get_node("Scroll/Rows")
	search.text_changed.connect(func(value: String) -> void: changes.append(value))
	search.text_submitted.connect(func(value: String) -> void: submitted = value)
	check(_visible_rows(rows) == 8 and _visible_rows(item_rows) == 8, "Both instances begin with every row")
	check(search.has_focus(), "Demo starts ready to type")
	check(search.get_theme_stylebox("normal") is StyleBoxTexture, "Native input uses the custom pixel frame")
	await _capture("pixel-search-default.png")
	_key(KEY_A, 97)
	await process_frame
	_key(KEY_T, 116)
	await process_frame
	_key(KEY_T, 116)
	await process_frame
	check(search.text == "att" and _visible_rows(rows) == 2, "Real typing filters physical and magic attack immediately")
	check(changes.size() == 3, "Each native text change is emitted once")
	check(_visible_rows(item_rows) == 8 and item_search.text.is_empty(), "Second search remains independent")
	_key(KEY_ENTER)
	check(submitted == "att" and search.is_editing(), "Enter submits without leaving edit mode")
	_key(KEY_ESCAPE)
	check(search.text.is_empty() and _visible_rows(rows) == 8 and search.has_focus(), "Escape clears and restores rows while retaining focus")
	_key(KEY_ESCAPE)
	check(not search.has_focus(), "Escape on an empty field releases focus")
	search.set_query("  AtTaCk   PHYS  ")
	check(_visible_rows(rows) == 1 and rows.get_node("Row1").visible, "Case, whitespace, word order and partial names are tolerated")
	item_search.set_query("weapon poison")
	check(_visible_rows(item_rows) == 1 and item_rows.get_node("Row3").visible, "Metadata searches across item names and effects")
	check(stats.get_node("Heading/Count").text == "1 / 8", "Result count follows live filtering")
	await _capture("pixel-search-filtered.png")
	search.set_query("no such statistic")
	check(_visible_rows(rows) == 0 and stats.get_node("Empty").visible, "Unmatched search displays recovery text")
	await _capture("pixel-search-empty.png")
	var clear_at: Vector2 = search.global_position + Vector2(search.size.x - 24, search.size.y / 2)
	_click(clear_at)
	await process_frame
	check(search.text.is_empty() and _visible_rows(rows) == 8 and not stats.get_node("Empty").visible, "Native clear button resets query, rows and empty state")
	check(item_search.text == "weapon poison", "Clearing one instance does not clear another")
	search.grab_focus()
	_key(KEY_TAB)
	check(item_search.has_focus(), "Tab moves to the next search field")
	search.set_query("mana")
	var added: Label = Label.new()
	added.text = "Mana recovery"
	rows.add_child(added)
	await process_frame
	check(added.visible and _visible_rows(rows) == 2, "New rows join the active query automatically")
	added.text = "Critical damage"
	search.refresh_filter()
	check(not added.visible, "Refresh picks up changed row content")
	added.queue_free()
	await process_frame
	await process_frame
	check(stats.get_node("Heading/Count").text == "1 / 8", "Removed rows update totals without stale references")
	var hidden: Label = Label.new()
	hidden.text = "Mana secret"
	hidden.hide()
	rows.add_child(hidden)
	await process_frame
	search.set_query("")
	check(not hidden.visible and _visible_rows(rows) == 8, "Clearing does not expose initially hidden rows")
	rows.get_node("Row1").set_meta("search_excluded", true)
	search.refresh_filter()
	check(_visible_rows(rows) == 7, "Eligibility metadata can exclude a row independently of the query")
	search.list_path = NodePath()
	check(rows.get_node("Row1").visible and not hidden.visible, "Unbinding restores original row visibility")
	var standalone: PixelSearchField = FIELD.instantiate()
	root.add_child(standalone)
	standalone.set_query("  magic\tattack ")
	check(standalone.matches("Attack from MAGIC") and not standalone.matches("Physical Attack"), "Unbound field supports custom data filtering")
	standalone.set_query("   ")
	check(standalone.matches("Anything"), "Whitespace-only query matches every entry")
	standalone.editable = false
	standalone.set_query("Locked")
	standalone.grab_focus()
	_key(KEY_A, 97)
	_key(KEY_ESCAPE)
	check(standalone.text == "Locked", "Read-only field rejects typing and Escape does not clear its value")
	standalone.queue_free()
	demo.queue_free()
	await process_frame
	report("PIXEL SEARCH RESULT")
	quit(1 if failures else 0)
