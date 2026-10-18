extends SceneTree

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _count_nodes(node: Node) -> int:
	var count: int = 1
	for child in node.get_children():
		# Decorative corridor meshes are intentionally generated at runtime;
		# the saved gameplay/menu layout must retain every authored node.
		if child.name in ["CorridorLife", "PhysicsPile"]:
			count += 1
			continue
		count += _count_nodes(child)
	return count

func _run() -> void:
	var game: Control = load("res://scenes/main.tscn").instantiate()
	# Inspect before entering the tree: these are authored assets, not _ready output.
	check(game.has_node("MenuFlow/MainMenu/PlayButton"), "Title controls exist before scripts run")
	check(game.has_node("Combat/ActionFrame/Action"), "Gameplay controls exist before scripts run")
	check(game.has_node("Overlay/RewardPanel/Choices/ChoiceButton1/Content/Footprint"), "Reward controls exist before scripts run")
	check(game.has_node("MenuFlow/Audio/MenuMusic"), "Audio players are saved nodes")
	for button: Button in game.get_node("Combat").find_children("*", "Button", true, false):
		check(button is PackPixelButton or button.theme_type_variation == &"IconButton", "Gameplay button uses a shared component: " + button.name)
	for button_name: String in ["ChoiceButton1", "ChoiceButton2", "ChoiceButton3"]:
		check(game.get_node("Overlay/RewardPanel/Choices/" + button_name) is PackPixelButton, "Gameplay dialog uses the shared button: " + button_name)
	for button_name: String in ["CloseButton", "DeathScreen/ResultActions/ResultButton1", "DeathScreen/ResultActions/ResultButton2", "DeathScreen/ResultActions/ResultButton3"]:
		check(not game.get_node("Overlay/" + button_name) is PackPixelButton, "End-of-run menus use native menu buttons: " + button_name)
	for index in range(1, 4):
		check(game.get_node("Overlay/PauseScreen").get_node("%%PauseButton%d" % index) is Button, "Full-screen pause uses authored menu buttons")
	for button: BaseButton in game.get_node("MenuFlow").find_children("*", "BaseButton", true, false):
		check(not button is PackPixelButton, "Front-end menus retain their original controls: " + button.name)
	var play: Button = game.get_node("MenuFlow/MainMenu/PlayButton")
	var action: Button = game.get_node("Combat/ActionFrame/Action")
	play.position.x += 3
	action.position.y += 3
	var menu_position: Vector2 = play.position
	var action_position: Vector2 = action.position
	var node_count: int = _count_nodes(game)
	root.add_child(game)
	await process_frame
	var inactive_tab: StyleBox = game.character_tabs.get_theme_stylebox("tab_unselected")
	check(inactive_tab.get_content_margin(SIDE_BOTTOM) == 12, "Inactive tabs retain the authored vertical padding")
	check(_count_nodes(game) == node_count, "Startup uses saved nodes without recreating layouts (before %d, after %d)" % [node_count, _count_nodes(game)])
	check(play.position == menu_position, "Menu layout edits survive startup")
	game.start_run("warrior", 42)
	check(action.position == action_position, "Gameplay layout edits survive starting a run")
	check(game.board.scene_file_path == "res://scenes/game/inventory/backpack.tscn", "Backpack is a reusable scene instance")
	for y in range(PackRun.GRID.y):
		for x in range(PackRun.GRID.x):
			var cell: Control = game.board.get_node("Cell%d_%d" % [x + 1, y + 1])
			check(cell.position == BackpackBoard.ORIGIN + Vector2(x, y) * BackpackBoard.STEP, "Saved cell matches drag/drop geometry")
			check(cell.size == Vector2.ONE * BackpackBoard.CELL, "Saved cell matches item dimensions")
	check(not game.board.has_node("UnpackedTray"), "Backpack no longer contains an unused-item tray")
	check(game.storage.scene_file_path == "res://scenes/game/inventory/storage_inventory.tscn" and game.storage.pile != null, "Saved stash scene initializes its physics pile")
	var options: Control = load("res://scenes/menus/options.tscn").instantiate()
	check(options.visible and options.theme != null, "Options previews independently with its theme")
	options.free()
	var home: Control = load("res://scenes/menus/main_menu.tscn").instantiate()
	check(home.theme != null, "Title previews independently with its theme")
	home.free()
	print("SCENE ASSET RESULT: %d checks, %d failures" % [checks, failures])
	# Gameplay starts and the assertions finish in one frame. Let its queued
	# audio start reach the mixer before the teardown issues stop requests.
	await create_timer(0.12).timeout
	await preload("res://tests/automatic_combat_cleanup.gd").release(self, game)
	quit(1 if failures else 0)
