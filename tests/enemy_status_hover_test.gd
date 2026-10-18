extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.run.enemy_poison = 3
	game.run.enemy_burn = 2
	game._update_status_rows()
	var status = game.enemy_vitals.get_node("Statuses/Content")
	assert("[url=poison]" in status.text and "[url=burn]" in status.text)
	status.meta_hover_started.emit("poison")
	assert(game._enemy_status_inspection()["key"] == "poison")
	status.meta_hover_started.emit("burn")
	assert(game._enemy_status_inspection()["key"] == "burn")
	status.meta_hover_ended.emit("burn")
	assert(game._enemy_status_inspection().is_empty())
	print("ENEMY STATUS HOVER: passed")
	quit()
