extends "res://tests/support/storage_ui_support.gd"

func _run() -> void:
	create_timer(30).timeout.connect(func() -> void: quit(2))
	test_viewport = SubViewport.new()
	test_viewport.size = Vector2i(1280, 720)
	test_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(test_viewport)
	test_viewport.notify_mouse_entered()
	game = load("res://scenes/main.tscn").instantiate()
	test_viewport.add_child(game)
	await frames(3)
	game.start_run("warrior", 42)
	game.waiting_at_entrance = false
	game.run.items.clear()
	game.run.phase = PackRun.Phase.FIGHT
	game.run.add_item("rusty_knife", Vector2i.ZERO)
	game.run.offers.assign(["rusty_knife"])
	game.run.item_rewards.assign([{"floor": 1}])
	game._refresh()
	game._open_reward(false)
	await frames(5)
	var button: Button = game.choice_buttons[0]
	_motion(button.get_global_rect().get_center())
	await frames(5)
	check(game.board.reward_craft_item.get("key") == "rusty_knife", "Native reward hover registers offered ingredient")
	check(not game.board._crafting_hover.is_empty(), "Reward hover creates crafting links to backpack")
	check(not game.board._crafting_trails.nodes.is_empty(), "Reward links reach GPU renderer")
	for node: Polygon2D in game.board._crafting_trails.nodes.values():
		check(not node.z_as_relative and node.z_index == 90, "Reward link appears above chooser and below tooltips")
	await RenderingServer.frame_post_draw
	test_viewport.get_texture().get_image().save_png(artifact_path("reward-crafting-hover.png"))
	_motion(Vector2(1200, 650))
	await create_timer(0.5).timeout
	check(game.board._crafting_hover.is_empty(), "Reward links fade away after hover ends")
	await preload("res://tests/support/automatic_combat_cleanup.gd").release(self, game, test_viewport)
	report("REWARD CRAFTING HOVER")
	quit(1 if failures else 0)
