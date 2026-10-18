extends SceneTree
func _initialize() -> void:
	call_deferred("run_check")
func run_check() -> void:
	root.size = Vector2i(1280, 720)
	var menu = load("res://scenes/menus/run_selection.tscn").instantiate()
	root.add_child(menu)
	for key in ["warrior", "assassin", "necromancer", "ranger", "mage"]:
		menu._add_run({"id": key, "state": {"class_key": key, "fight": 0, "items": []}, "elapsed": 0})
	await process_frame
	await process_frame
	var failures := 0
	for row in menu.rows.get_children():
		var portrait: Control = row.get_child(0).get_child(0)
		print(row.name, " frame=", portrait.size, " art=", portrait.get_node("Art").size, " offset=", portrait.get_node("Art").position)
		if portrait.size != Vector2(104, 104): failures += 1
		if row.name in ["Run_warrior", "Run_assassin", "Run_necromancer", "Run_ranger"] and portrait.get_node("Art").position != Vector2(3, 3): failures += 1
	var player = load("res://scenes/game/character/player.tscn").instantiate()
	root.add_child(player)
	var tile = load("res://scenes/menus/delver_tile.tscn").instantiate()
	root.add_child(tile)
	await process_frame
	for portrait: Control in [player.get_node("Portrait"), tile.get_node("Portrait")]:
		print(portrait.get_parent().name, " frame=", portrait.size)
		if portrait.size.x != portrait.size.y: failures += 1
	print("PORTRAIT LAYOUT: ", failures, " failures")
	quit(1 if failures else 0)
