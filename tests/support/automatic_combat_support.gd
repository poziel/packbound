extends "res://tests/support/battle_ui_support.gd"

func _fixture(speed: int) -> void:
	# Generic playback timing does not depend on the ranger's required quiver.
	game.start_run("warrior", 42)
	game._open_reward(true)
	game._choose(0)
	game.front.settings["combat_speed"] = speed
	game.front.settings["player_response_delay"] = 1.5
	game.front.settings["enemy_response_delay"] = 1.5
	game.run.relics.clear()
	game.run.items.clear()
	game.run.hp = 30
	game.run.enemy["hp"] = 1000
	game.run.enemy["max_hp"] = 1000
	game.run.enemy["attacks"] = [3]
	game.run.add_item("rusty_knife", Vector2i.ZERO)[GameplayTypes.Stat.DAMAGE] = 8
	game._refresh()

func _freed_scene_checks() -> void:
	for paused_first: bool in [false, true]:
		var disposable: Control = load("res://scenes/main.tscn").instantiate()
		test_viewport.add_child(disposable)
		await process_frame
		disposable.run_saves.directory = preload("res://tests/support/artifact_paths.gd").path("legacy_logs/automatic-combat-saves")
		disposable.start_run("warrior", 42)
		disposable.run.enemy["hp"] = 1000
		disposable.run.enemy["max_hp"] = 1000
		disposable.front.settings["combat_speed"] = 4
		disposable._act()
		disposable.playback.set_paused(paused_first)
		var retained_run: PackRun = disposable.run
		var before: Array = [retained_run.hp, retained_run.total_turns, retained_run.history.duplicate(true)]
		# Direct freeing tests _exit_tree cancellation, without show_menu first.
		for player: Node in disposable.find_children("*", "AudioStreamPlayer", true, false):
			player.stop()
		disposable.queue_free()
		await process_frame
		await create_timer(0.55).timeout
		check(not is_instance_valid(disposable), "Active/paused disposable UI is freed")
		check(before == [retained_run.hp, retained_run.total_turns, retained_run.history], "Freeing active/paused UI cancels callbacks without further model commits")

func _frozen_check(label: String, duration: float) -> void:
	game.playback.set_paused(true)
	var state: Array = [game.run.hp, game.run.mana, game.run.block, game.run.turn, game.run.total_turns, game.run.history.duplicate(true)]
	var remaining: float = game.playback.remaining_seconds
	var old_elapsed: float = game.elapsed
	var transform: Array = [game.enemy_art.position, game.enemy_art.scale, game.enemy_art.modulate, game.hp_bar._glow_amount, game.enemy_bar._glow_amount]
	await create_timer(duration).timeout
	check(state == [game.run.hp, game.run.mana, game.run.block, game.run.turn, game.run.total_turns, game.run.history], label + " pause freezes complete checkpoint")
	check(is_equal_approx(remaining, game.playback.remaining_seconds), label + " pause preserves remaining wait")
	check(is_equal_approx(old_elapsed, game.elapsed), label + " pause freezes descent clock")
	check(transform == [game.enemy_art.position, game.enemy_art.scale, game.enemy_art.modulate, game.hp_bar._glow_amount, game.enemy_bar._glow_amount], label + " pause freezes feedback")

func _reset_check() -> void:
	game.start_run("ranger", 8)
	var logs: Array = game.run.history.duplicate(true)
	var hp: int = game.run.hp
	await create_timer(0.1).timeout
	check(not game.playback.active and game.run.total_turns == 0 and game.run.hp == hp and game.run.history == logs, "Reset cannot receive old checkpoints")
	check(game.enemy_art.scale == Vector2.ONE and game.enemy_art.position == game.enemy_card.rest_position, "Reset restores feedback transforms")
