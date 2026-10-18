extends "res://tests/prototype_test.gd"

func _paths(node: Node) -> Array[String]:
	var result: Array[String] = []
	for child: Node in node.get_children():
		result.append(str(game.get_path_to(child)))
		result.append_array(_paths(child))
	return result

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	var before: Array[String] = _paths(game)
	root.add_child(game)
	await process_frame
	for path: String in _paths(game):
		if not before.has(path): print("RUNTIME NODE: ", path)
	game.start_run("warrior", 42)
	game.run.relic_offers.assign(["echo_clock", "echo_clock", "echo_clock"])
	game._open_reward(true)
	await process_frame
	await process_frame
	print("ECHO CARD: ", game.choice_buttons[0].size, " DETAIL: ", game.choice_details[0].get_rect())
	await preload("res://tests/automatic_combat_cleanup.gd").release(self, game)
	quit()
