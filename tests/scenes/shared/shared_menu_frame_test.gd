extends "res://tests/support/menu_support.gd"

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var menu: PackMenuFlow = game.front
	var dungeon_id: int = game.gameplay_background.get_instance_id()
	var room_id: int = game.gameplay_background.world.active_room.get_instance_id()
	var artwork: Control = menu.home.get_node("Background")
	check(artwork.get_global_rect() == menu.home.get_global_rect().grow(-5), "Main-menu artwork fits the five-pixel application frame")
	check(artwork.clip_contents, "Animated artwork cannot spill into the application frame")
	check(artwork.get_node("Artwork").scale == Vector2(2, 2), "Original menu art retains its integer pixel scale")
	check(artwork.get_node("Artwork").global_position == Vector2.ZERO, "The inset preserves the existing artwork registration")
	await snapshot("shared-menu-frame/home")
	menu.show_options()
	await process_frame
	var panel: ColorRect = menu.options.get_node("Background")
	check(panel.get_global_rect() == menu.options.get_global_rect().grow(-5), "Options uses the same five-pixel application frame")
	check(panel.color.a == 1.0, "Settings keeps a solid surface behind the controls")
	for tab in range(3):
		menu.option_tabs.current_tab = tab
		await snapshot("shared-menu-frame/options-" + menu.option_tabs.get_tab_title(tab).to_lower())
	menu.show_classes()
	await process_frame
	var classes_panel: ColorRect = menu.selection.get_node("Background")
	check(classes_panel.visible and classes_panel.get_global_rect() == menu.selection.get_global_rect().grow(-5), "Class selection shares the padded menu surface")
	await snapshot("shared-menu-frame/classes")
	check(game.gameplay_background.get_global_rect() == game.get_global_rect(), "Shared dungeon covers the application behind every screen")
	check(game.gameplay_background.get_instance_id() == dungeon_id and game.gameplay_background.world.active_room.get_instance_id() == room_id, "Menus reuse one live 3D dungeon")
	game.start_run("warrior", 42)
	game.show_pause()
	game._open_options()
	await process_frame
	check(panel.get_global_rect() == menu.options.get_global_rect().grow(-5) and not game.combat.visible, "Options from gameplay uses the same padded panel")
	await snapshot("shared-menu-frame/options-from-game")
	click(menu.back_button)
	check(game.combat.visible and not menu.visible, "Back restores gameplay with the shared dungeon")
	await snapshot("shared-menu-frame/gameplay")
	check(game.gameplay_background.get_instance_id() == dungeon_id and game.gameplay_background.world.active_room.get_instance_id() == room_id, "Gameplay also uses the same dungeon instance")
	await preload("res://tests/support/automatic_combat_cleanup.gd").release(self, game)
	report("SHARED MENU FRAME RESULT")
	quit(1 if failures else 0)
