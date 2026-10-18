extends "res://tests/menu_test.gd"

const FRAME_GRAY := Color(0.333, 0.365, 0.424, 1)

func _run() -> void:
	# Render the authored gameplay scenes without the application controller:
	# this isolates tab rendering from unrelated live game-flow edits.
	game = Control.new()
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(game)
	game.add_child(load("res://scenes/gameplay/gameplay_background.tscn").instantiate())
	var combat: Control = load("res://scenes/game/game.tscn").instantiate()
	game.add_child(combat)
	var frame: Control = load("res://scenes/shared/application_frame.tscn").instantiate()
	game.add_child(frame)
	frame.get_node("SettingsDock").show()
	await process_frame
	await process_frame
	var tabs: TabContainer = combat.get_node("CharacterPanel/Tabs")
	for index in tabs.get_tab_count():
		tabs.current_tab = index
		await _check_strip(tabs, "character-" + tabs.get_tab_control(index).name.to_lower())
	# Hover retains the same connected silhouette, and keyboard selection still works.
	motion(tabs.get_tab_bar().global_position + tabs.get_tab_bar().get_tab_rect(1).get_center())
	await _check_strip(tabs, "hover")
	tabs.get_tab_bar().grab_focus()
	key(KEY_LEFT)
	await process_frame
	check(tabs.current_tab == 2, "Native keyboard selection remains available")
	await _check_strip(tabs, "keyboard")
	# Saved tab scenes may be reordered in the editor.
	tabs.move_child(tabs.get_node("Logs"), 1)
	tabs.current_tab = 1
	await _check_strip(tabs, "reordered")
	# Separate scene instances must not share selection-dependent style state.
	var preview: Control = load("res://scenes/game/character/character_panel.tscn").instantiate()
	root.add_child(preview)
	await process_frame
	check(preview.get_node("Tabs").get_theme_stylebox("tab_unselected") != tabs.get_theme_stylebox("tab_unselected"), "Connected tab surfaces are independent per scene instance")
	preview.queue_free()
	game.queue_free()
	await process_frame
	print("CONNECTED TABS RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _check_strip(tabs: TabContainer, filename: String) -> void:
	await snapshot("corner-joins/" + filename)
	if DisplayServer.get_name() == "headless":
		return
	var picture: Image = root.get_texture().get_image()
	var bar := tabs.get_tab_bar()
	for index in tabs.get_tab_count():
		var rect: Rect2 = bar.get_tab_rect(index)
		var left := Vector2i(bar.global_position + rect.position)
		var right := Vector2i(bar.global_position + rect.end) - Vector2i.ONE
		if index == tabs.current_tab:
			check(_is_gray(picture, left), filename + ": selected upper left joins the frame")
			check(_is_gray(picture, Vector2i(right.x, left.y)), filename + ": selected tab rounds into the separate header division")
			continue
		check(_is_gray(picture, left) and _is_gray(picture, Vector2i(right.x, left.y)), filename + ": inactive top corners continue the frame")
		var exposed_left: bool = index > 0 and index - 1 == tabs.current_tab
		var exposed_right: bool = index == tabs.get_tab_count() - 1 or index + 1 == tabs.current_tab
		check(_is_gray(picture, Vector2i(left.x, right.y)) != exposed_left, filename + ": lower left rounds only at a color transition for tab %d" % index)
		check(_is_gray(picture, right) != exposed_right, filename + ": lower right rounds only at a color transition for tab %d" % index)
	var last: Rect2 = bar.get_tab_rect(tabs.get_tab_count() - 1)
	var join := Vector2i(bar.global_position + Vector2(last.end.x, last.position.y))
	check(_is_gray(picture, join), filename + ": last tab meets the gray header separator")
	check(not _is_gray(picture, join + Vector2i(6, 14)), filename + ": header join returns to the straight edge beyond the separator")
	var panel: Control = tabs.get_parent_control()
	var bounds: Rect2 = panel.get_global_rect()
	var left_edge: int = roundi(bounds.position.x)
	var top: int = roundi(bounds.position.y)
	var bottom: int = roundi(bounds.end.y) - 1
	check(_is_gray(picture, Vector2i(left_edge, roundi(bar.get_global_rect().end.y))) == (tabs.current_tab != 0), filename + ": sheet upper left rounds below the inactive first tab")
	check(_is_gray(picture, Vector2i(left_edge, bottom)), filename + ": sheet lower left is always rounded")
	check(_is_gray(picture, Vector2i(left_edge - 6, top)), filename + ": room upper right is rounded")
	check(_is_gray(picture, Vector2i(left_edge - 6, bottom)), filename + ": room lower right is rounded")

func _is_gray(picture: Image, point: Vector2i) -> bool:
	var color: Color = picture.get_pixelv(point)
	return absf(color.r - FRAME_GRAY.r) < 0.01 and absf(color.g - FRAME_GRAY.g) < 0.01 and absf(color.b - FRAME_GRAY.b) < 0.01
