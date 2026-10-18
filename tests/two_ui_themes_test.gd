extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func settle() -> void:
	for i in range(8):
		await process_frame

func active_themes(path: String) -> PackedStringArray:
	var found := PackedStringArray()
	if FileAccess.file_exists(path + "/.gdignore"):
		return found
	var dir := DirAccess.open(path)
	for folder in dir.get_directories():
		found.append_array(active_themes(path + "/" + folder))
	for file in dir.get_files():
		if file.ends_with(".tres") and FileAccess.get_file_as_string(path + "/" + file).contains("[gd_resource type=\"Theme\""):
			found.append(path + "/" + file)
	return found

func _run() -> void:
	var game: Theme = load("res://themes/gameplay/theme.tres")
	var menu: Theme = load("res://themes/menu/theme.tres")
	check((active_themes("res://assets") + active_themes("res://components")).size() == 2, "Exactly two active UI themes")
	check(not FileAccess.file_exists("res://themes/delver-tile/theme.tres"), "No separate delver theme")
	check(not FileAccess.file_exists("res://components/pixel_scrollbar/scrollbar_theme.tres"), "No separate scrollbar theme")
	for skin: Theme in [game, menu]:
		check(skin.has_color("face_color", "PackPixelButton"), "Theme defines pixel button appearance")
		check(skin.has_color("accent_color", "PixelSearchField"), "Theme defines search appearance")
		for kind in ["HSeparator", "VSeparator"]:
			check(skin.get_stylebox("separator", kind) is StyleBoxLine, "Native separator line style")
	var parent := Control.new()
	parent.theme = game.duplicate(true)
	root.add_child(parent)
	var button = load("res://components/pixel_button/pixel_button.tscn").instantiate()
	parent.add_child(button)
	var search = load("res://components/pixel_search_field/pixel_search_field.tscn").instantiate()
	parent.add_child(search)
	var stat = load("res://components/pixel_stat_bar/pixel_stat_bar.tscn").instantiate()
	parent.add_child(stat)
	var scroll: ScrollContainer = load("res://components/pixel_scrollbar/pixel_scroll_container.tscn").instantiate()
	parent.add_child(scroll)
	await settle()
	check(button.theme == null and search.theme == null, "Custom controls do not assign private themes")
	check(scroll.get_script() == null, "Scroll container has no script")
	check(button.face_color == parent.theme.get_color("face_color", "PackPixelButton"), "Button inherits palette")
	check(search.accent_color == parent.theme.get_color("accent_color", "PixelSearchField"), "Search inherits palette")
	check(stat.accent_color == parent.theme.get_color("accent_color", "PixelStatBar"), "Stat bar inherits palette")
	check(scroll.get_v_scroll_bar().get_theme_stylebox("grabber") == parent.theme.get_stylebox("grabber", "VScrollBar"), "Native bars inherit theme")
	parent.theme.set_color("face_color", "PackPixelButton", Color.MAGENTA)
	await settle()
	check(button.face_color == Color.MAGENTA, "Editing active theme updates button")
	button.face_color = Color.CYAN
	parent.theme = menu
	await settle()
	check(button.face_color == Color.CYAN, "Explicit appearance survives theme switch")
	if button.has_method("reset_appearance_overrides"):
		button.reset_appearance_overrides()
		await settle()
		check(button.face_color == menu.get_color("face_color", "PackPixelButton"), "Reset restores inheritance")
	else:
		check(false, "Appearance reset is available")
	check(search.accent_color == menu.get_color("accent_color", "PixelSearchField"), "Search follows switched theme")
	for control in [button, search, stat]:
		var packed := PackedScene.new()
		check(packed.pack(control) == OK, "Themed control packs")
		var path: String = "res://tests/output/two-ui-themes/" + control.name + ".tscn"
		check(ResourceSaver.save(packed, path) == OK, "Themed control saves")
		var saved_text := FileAccess.get_file_as_string(path)
		check(not saved_text.contains("PackedByteArray") and not saved_text.contains("type=\"Image\""), "Scene omits generated pixel data")
		var restored = load(path).instantiate()
		parent.add_child(restored)
		await settle()
		check(restored._appearance_overrides.is_empty(), "Saving does not freeze inherited appearance")
		if restored is PackPixelButton:
			check(restored.face_color == menu.get_color("face_color", "PackPixelButton"), "Reloaded button inherits new theme")
		if restored is PixelSearchField:
			check(restored.get_theme_stylebox("normal").texture != null, "Reloaded field rebuilds pixels")
		if restored is PixelStatBar:
			check(restored.value_label.text == stat.value_label.text, "Reloaded stat keeps value formatting")
		control.theme = game
		check(packed.pack(control) == OK, "Explicit node theme packs")
		var found_theme := false
		for i in range(packed.get_state().get_node_property_count(0)):
			found_theme = found_theme or packed.get_state().get_node_property_name(0, i) == &"theme"
		check(found_theme, "An explicitly assigned node theme remains serializable")
		control.reset_appearance_overrides()
		var visual_property: String = "face_color" if control is PackPixelButton else "accent_color"
		var original_default := Color("536b47") if control is PackPixelButton else (Color("b8b879") if control is PixelSearchField else Color("e84061"))
		control.set(visual_property, original_default)
		packed.pack(control)
		var explicit_copy = packed.instantiate()
		parent.add_child(explicit_copy)
		await settle()
		check(explicit_copy._appearance_overrides.has(visual_property), "Explicit value equal to script default survives packing")
		check(explicit_copy.get(visual_property) == original_default, "Explicit default-valued color survives reload")
		explicit_copy.queue_free()
		restored.queue_free()
	parent.queue_free()
	await settle()
	print("TWO UI THEMES RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
