extends "res://tests/prototype_test.gd"

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.run_saves.directory = "res://.godot/popup-transition-test-saves"
	game.start_run("warrior", 42)
	game.board.show_item_effects(game.run.effects())
	game.enemy_card.show_combat_effects({"dealt": 40})
	check(game.has_method("_preserve_transition_popups"), "Room transition can preserve running popups")
	if game.has_method("_preserve_transition_popups"):
		var count: int = game.board.effect_popups.size() + game.enemy_card.effect_popups.size()
		var position_before: Vector2 = game.enemy_card.effect_popups[0]["anchor"] + game.enemy_card.global_position
		game._preserve_transition_popups()
		game.board.clear_activation_feedback()
		game.enemy_card.hide()
		game.enemy_card.reset_feedback()
		check(game.transition_popups.effect_popups.size() == count, "Hiding and resetting old monster preserves every popup")
		var popup: Dictionary = game.transition_popups.effect_popups[-1]
		check((popup["anchor"] + game.transition_popups.global_position).is_equal_approx(position_before), "Transfer preserves on-screen position")
		game.transition_popups._process(0.4)
		check(popup["elapsed"] > 0, "Animation keeps advancing during travel")
		var elapsed_before: float = popup["elapsed"]
		game._combat_pause_changed(true)
		game.transition_popups._process(0.3)
		check(popup["elapsed"] == elapsed_before, "Transferred popups still respect combat pause")
		game._combat_pause_changed(false)
		if DisplayServer.get_name() != "headless":
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/popup-transition.png")
		game.transition_popups._process(4.0)
		check(game.transition_popups.effect_popups.is_empty(), "Transferred popups finish and expire naturally")
		game.enemy_card.show()
		game.enemy_card.show_combat_effects({"dealt": 2})
		game._preserve_transition_popups()
		game._cancel_combat()
		check(game.transition_popups.effect_popups.is_empty(), "Leaving run clears transferred popups")
	print("POPUP TRANSITION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
