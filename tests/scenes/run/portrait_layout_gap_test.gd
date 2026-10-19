extends "res://tests/support/test_case.gd"
func _initialize() -> void:
	if not require_isolation():
		return
	call_deferred("run_check")
func run_check() -> void:
	root.size = Vector2i(1280, 720)
	var menu = load("res://scenes/menus/run_selection/run_selection.tscn").instantiate()
	root.add_child(menu)
	for key in ["warrior", "assassin", "necromancer", "ranger", "mage"]:
		menu._add_run({"id": key, "state": {"class_key": key, "fight": 0, "items": []}, "elapsed": 0})
	await process_frame
	await process_frame
	for row in menu.rows.get_children():
		var portrait: Control = row.get_child(0).get_child(0)
		print(row.name, " frame=", portrait.size, " art=", portrait.get_node("Art").size, " offset=", portrait.get_node("Art").position)
		checks += 1
		if portrait.size != Vector2(104, 104): failures += 1
		checks += 1
		if row.name in ["Run_warrior", "Run_assassin", "Run_necromancer", "Run_ranger"] and portrait.get_node("Art").position != Vector2(3, 3): failures += 1
	var player = load("res://scenes/run/character/player/player.tscn").instantiate()
	root.add_child(player)
	var tile = load("res://scenes/menus/delver_tile/delver_tile.tscn").instantiate()
	root.add_child(tile)
	await process_frame
	for portrait: Control in [player.get_node("Portrait"), tile.get_node("Portrait")]:
		print(portrait.get_parent().name, " frame=", portrait.size)
		checks += 1
		if portrait.size.x != portrait.size.y: failures += 1
	print("PORTRAIT LAYOUT: ", failures, " failures")
	report("portrait_layout_gap")
	quit(1 if failures else 0)
