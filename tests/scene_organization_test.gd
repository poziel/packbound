extends SceneTree

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _run() -> void:
	create_timer(20).timeout.connect(func() -> void: printerr("Scene organization test timed out"); quit(2))
	var app: Control = load("res://scenes/main.tscn").instantiate()
	var combat: Control = app.get_node("Combat")
	var battle: Control = combat.get_node("BattleArea")
	var actions: Control = combat.get_node("ActionFrame")
	var panel: Control = combat.get_node("CharacterPanel")
	var tabs: TabContainer = panel.get_node("Tabs")
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/main.tscn", "There is one application entry point")
	check(not FileAccess.file_exists("res://scenes/prototype_main.tscn"), "The obsolete prototype scene is removed")
	check(combat.get_child_count() == 4 and combat.has_node("CharacterDivider") and actions.has_node("StorageButton") and actions.has_node("ItemRewardButton") and actions.has_node("RelicRewardButton") and app.has_node("GameplayBackground") and app.has_node("CombatPlayback"), "Game composes three UI areas and their divider; navigation buttons belong to the action frame")
	check(app.get_node("MenuFlow").scene_file_path == "res://scenes/menus/menu_flow.tscn", "Menu navigation has a distinct scene")
	check(app.get_node("MenuFlow/MainMenu").scene_file_path == "res://scenes/menus/main_menu.tscn", "Title screen is a child of menu navigation")
	check(battle.scene_file_path == "res://scenes/game/battle_area.tscn", "Battle area is an editable scene instance")
	check(actions.scene_file_path == "res://scenes/game/action_frame.tscn", "Action frame is an editable scene instance")
	check(panel.scene_file_path == "res://scenes/game/character/character_panel.tscn", "The whole right panel is an editable scene instance")
	for tab_name: String in ["Backpack", "Relics", "Statistics", "Logs"]:
		var tab: Control = tabs.get_node(NodePath(tab_name))
		check(tab.scene_file_path == "res://scenes/game/character/tabs/%s.tscn" % tab_name.to_lower(), "Tab has its own saved scene: " + tab_name)
	check(tabs.get_node("Backpack/Player").scene_file_path == "res://scenes/game/character/player.tscn", "Player display is separate from the backpack grid")
	for control: String in ["EncounterLabel", "TimerLabel", "VSeparator"]:
		check(panel.has_node(NodePath(control)) and not combat.has_node(NodePath(control)), "Header control belongs to the right panel: " + control)
	root.add_child(app)
	await process_frame
	app.start_run("warrior", 42)
	app._open_reward(true)
	app._choose(0)
	await process_frame
	await process_frame
	for index in tabs.get_tab_count():
		check(tabs.get_tab_bar().get_tab_rect(index).end.x <= panel.get_node("Header").position.x, "Tab stays clear of the run controls: " + tabs.get_tab_control(index).name)
	for area in [battle, actions, panel, combat]:
		var targets: Array[Control] = []
		if area == battle:
			targets.assign([app.enemy_art, app.storage])
		elif area == actions:
			targets.assign([app.action])
		elif area == panel:
			targets.assign([app.board, app.character_portrait, app.timer_label, app.encounter_label, panel.get_node("VSeparator")])
		else:
			targets.assign([app.storage_button, app.item_reward_button, app.relic_reward_button])
		var positions: Array[Vector2] = []
		for target in targets:
			positions.append(target.global_position)
		var shift := Vector2(7, 11)
		area.position += shift
		for index in targets.size():
			check(targets[index].global_position.is_equal_approx(positions[index] + shift), "Moving an area carries its controls: " + targets[index].name)
		area.position -= shift
	# Reordering tabs in the editor must not redirect the record shortcut.
	tabs.move_child(tabs.get_node("Logs"), 1)
	app.show_record()
	check(tabs.get_current_tab_control().name == "Logs" and app.history_view.is_visible_in_tree(), "Record navigation follows the Logs scene after reordering")
	app.settings_button.pressed.emit()
	check(app.modal.visible and app.modal_kind == "pause", "Shared frame gear opens the full-screen pause screen")
	var paused_at: float = app.elapsed
	await create_timer(0.05).timeout
	check(is_equal_approx(app.elapsed, paused_at), "Pause freezes the timer")
	app._close_modal()
	await create_timer(0.05).timeout
	check(app.elapsed > paused_at, "Resume restarts the timer")
	tabs.move_child(tabs.get_node("Backpack"), 2)
	app._toggle_storage()
	check(tabs.get_current_tab_control().name == "Backpack" and app.storage.visible, "Storage navigation follows the Backpack scene after reordering")
	app.show_menu()
	check(app.front.home.is_visible_in_tree() and not combat.visible, "Returning to the menu still switches the whole game view")
	app.queue_free()
	await process_frame
	for path: String in ["battle_area", "action_frame", "character/character_panel", "character/player", "character/tabs/backpack", "character/tabs/relics", "character/tabs/statistics", "character/tabs/logs"]:
		var view: Control = load("res://scenes/game/%s.tscn" % path).instantiate()
		root.add_child(view)
		await process_frame
		await process_frame
		check(view.visible and view.theme != null and view.size.x > 0 and view.size.y > 0, "Subscene previews independently with a theme and size: " + path)
		view.queue_free()
		await process_frame
	print("SCENE ORGANIZATION RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
