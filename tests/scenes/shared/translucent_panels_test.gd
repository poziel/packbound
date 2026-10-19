extends "res://tests/support/menu_support.gd"

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.start_run("warrior", 42)
	await process_frame
	await process_frame
	var divider: ColorRect = game.combat.get_node_or_null("CharacterDivider")
	check(divider != null, "A shared-color divider separates the character and monster areas")
	var idle: StyleBox = game.character_tabs.get_theme_stylebox("tab_unselected")
	check(idle.get("bg_color") == Color(0.333, 0.365, 0.424, 1), "Inactive tabs match the opaque frame gray")
	check(idle.get_script() != null, "Inactive tabs have a native editable pixel-rounded style")
	check(game.storage.has_node("Backdrop"), "Unused items have a dedicated frosted backdrop")
	check(game.modal.has_node("DialogFrame/Backdrop"), "Floating dialogs share the frosted backdrop")
	var frame_style: StyleBox = game.application_frame.get_node("Border").get_theme_stylebox("panel")
	var panel: Control = game.combat.get_node("CharacterPanel")
	check(divider.size.x == 5 and divider.get_global_rect().end.x == panel.global_position.x, "Divider is exactly five pixels wide and meets the character sheet")
	check(divider.color == frame_style.get("border_color") and divider.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Divider matches the outer frame without intercepting input")
	check(idle.get("corner_radius") == 8 and idle.get("round_bottom") == true and idle.get("round_top") == false, "Connected inactive tabs round only their exposed lower endpoints")
	var selected: StyleBox = game.character_tabs.get_theme_stylebox("tab_selected")
	var sheet: StyleBox = panel.get_node("Frame").get_theme_stylebox("panel")
	check(selected.get("bg_color") == sheet.bg_color and sheet.bg_color.a < 1.0 and sheet.bg_color.a > 0.75, "Selected tab matches the lightly translucent sheet surface")
	check(is_equal_approx(panel.get_node("Frame").global_position.y, game.character_tabs.get_tab_bar().get_global_rect().end.y), "Selected tab and sheet meet without stacking translucent fills")
	check(game.storage.get_node("Backdrop").opacity < sheet.bg_color.a and game.storage.get_node("Backdrop").blur_radius > 0, "Central panels use more translucency with blur")
	check(game.storage.material == null and game.storage.get_node("Title").material == null, "Blur is isolated from labels and inventory controls")
	for tab in range(game.character_tabs.get_tab_count()):
		game.character_tabs.current_tab = tab
		await snapshot("translucent-panels/character-" + game.character_tabs.get_tab_control(tab).name.to_lower())
	game.character_tabs.current_tab = 0
	game.run.add_item("healing_herbs")["cell"] = null
	game._refresh()
	game._toggle_storage()
	await process_frame
	await process_frame
	check(game.storage.visible and game.board.is_visible_in_tree(), "Frosted storage opens alongside the backpack")
	await snapshot("translucent-panels/unused-items")
	game._close_storage()
	game._open_reward(true)
	await snapshot("translucent-panels/reward")
	check(game.modal.visible and game.choice_buttons[0].visible, "Frosted dialogs retain reward controls")
	await preload("res://tests/support/automatic_combat_cleanup.gd").release(self, game)
	report("TRANSLUCENT PANELS RESULT")
	quit(1 if failures else 0)
