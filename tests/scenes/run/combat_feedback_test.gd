extends "res://tests/support/battle_ui_support.gd"

func _run() -> void:
	render = DisplayServer.get_name() != "headless"
	create_timer(30).timeout.connect(func() -> void: printerr("Combat feedback test timed out"); quit(1))
	game = load("res://scenes/main.tscn").instantiate()
	test_viewport = SubViewport.new()
	test_viewport.size = Vector2i(1280, 800)
	test_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(test_viewport)
	test_viewport.notify_mouse_entered()
	test_viewport.add_child(game)
	await process_frame
	await process_frame
	var sound: AudioStreamPlayer = game.combat_audio
	var sample: AudioStreamWAV = sound.stream
	check(sample.loop_mode == AudioStreamWAV.LOOP_DISABLED and sample.resource_path == "res://assets/audio/sfx/combat/enemy_hit.wav", "Impact uses the new non-looping supplied WAV")
	var decoder: AudioStreamPlayback = sample.instantiate_playback()
	decoder.start()
	var peak: float = 0.0
	for frame: Vector2 in decoder.mix_audio(1.0, 24000):
		peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
	decoder.stop()
	check(peak > 0.1, "Godot decodes audible impact samples")
	check(sound.bus == &"FX" and AudioServer.get_bus_send(AudioServer.get_bus_index("FX")) == &"Master", "Slash uses existing FX and Master volume routing")
	check(not sound.playing, "No impact audio on the title screen")

	for class_key: String in PackCatalog.classes():
		game.start_run(class_key, 42)
		if game.run.needs_arrows():
			game._choose(0)
		game.run.enemy["hp"] = 100
		game.run.enemy["max_hp"] = 100
		game.front.settings["combat_speed"] = 1
		game.run.relic_rewards.append(1)
		game.run.roll_relics()
		game._open_reward(true)
		check(game.modal.visible and not sound.playing and game.run.total_turns == 0, "Reward selection starts without combat feedback: " + class_key)
		game._choose(0)
		await process_frame
		# Flash-off must still animate, and must still protect against duplicate turns.
		game.front.settings["flash"] = false
		var forecast: Dictionary = game.run.outcome(game.run.effects())
		var bar_rect: Rect2 = game.enemy_bar.get_global_rect()
		_click(game.action)
		check(game.run.total_turns == 1 and game.busy and not game.action.disabled, "Exactly one turn while impact is running: " + class_key)
		check(game.run.enemy["hp"] == forecast["player_state"]["enemy_hp"] and game.run.hp == forecast["player_state"]["hp"], "Initial feedback shows only the player's action: " + class_key)
		check(sound.playing, "Every class plays the enemy hit sound: " + class_key)
		check(is_zero_approx(game.enemy_card.flash_color.a), "Flash-off leaves sprite tint unchanged: " + class_key)
		check(game.enemy_card.hit_tween.is_running(), "Attack starts monster reaction: " + class_key)
		game._act()
		check(game.playback.paused and game.run.total_turns == 1, "Second action pauses without another champion action: " + class_key)
		game._act()
		check(not game.playback.paused and game.run.total_turns == 1, "Resume does not replay champion feedback: " + class_key)
		await create_timer(0.065).timeout
		# Exact intermediate poses are covered by monster_animation_test's
		# deterministic tween stepping; audio warmup can skip this brief peak.
		check(game.enemy_bar.get_global_rect().is_equal_approx(bar_rect), "Health bar does not move during the pulse: " + class_key)
		if class_key == "warrior":
			await _snapshot("combat-feedback-impact")
		await create_timer(0.3).timeout
		check(game.gameplay_background.enemy.scale.is_equal_approx(Vector3.ONE) and is_zero_approx(game.enemy_card.flash_color.a), "Sprite returns exactly to rest: " + class_key)
		await _wait_for_action()
		check(game.run.enemy["hp"] == forecast["enemy_hp_after"] and game.run.hp == forecast["hp_after"], "Delayed feedback preserves combat outcome: " + class_key)
		check(not game.busy and not game.action.disabled, "Explicit cancellation permits isolated feedback verification: " + class_key)
		check(not game.enemy_card.hit_particles.emitting, "Particle burst does not loop: " + class_key)

	game.start_run("warrior", 42)
	game._open_reward(true)
	game._choose(0)
	game.front.settings["flash"] = true
	game.run.enemy["hp"] = 1
	game._act()
	await create_timer(0.07).timeout
	check(game.enemy_card.flash_color.a > 0, "Enabled combat flash still tints the hit")
	check(game.run.enemy["hp"] == 0 and not game.modal.visible, "Killing blow remains visible before loot")
	await _wait_for_action()
	check(not game.modal.visible and not game.busy and game.run.fight == 1, "Impact settles and descends without a loot prompt")
	game._open_reward(true)
	game._choose(0)
	await _wait_for_action()
	check(game.gameplay_background.enemy.scale.is_equal_approx(Vector3.ONE) and is_zero_approx(game.enemy_card.flash_color.a), "Next monster inherits no hit transform or tint")
	game.show_menu()
	check(not sound.playing, "Menu return stops the remaining impact tail")

	game.start_run("warrior", 42)
	game._open_reward(true)
	game._choose(0)
	game.front.settings["fx"] = 0
	game.front.audio.apply_settings(game.front.settings)
	game._act()
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(sound.bus)), "FX zero mutes combat audio through its routed bus")
	await _wait_for_action()
	check(not game.busy and game.gameplay_background.enemy.scale.is_equal_approx(Vector3.ONE), "Muted attacks still finish their animation")
	game.start_run("warrior", 42)
	game._open_reward(true)
	game._choose(0)
	game.run.enemy["hp"] = 999
	game.run.enemy["attacks"] = [999]
	game.run.relics.clear()
	game.run.hp = 1
	game._act()
	check(game.run.hp == 1 and not game.modal.visible, "Fatal enemy response waits until after the player's impact")
	await _wait_for_action()
	check(game.modal.visible and not game.busy and game.gameplay_background.enemy.scale.is_equal_approx(Vector3.ONE), "Defeat dialog follows settled feedback")
	report("COMBAT FEEDBACK RESULT")
	# Let the audio mixer release playback handles before the process exits.
	game.front.audio.next_track_timer.stop()
	if game.front.audio.transition and game.front.audio.transition.is_valid():
		game.front.audio.transition.kill()
	for player: Node in game.find_children("*", "AudioStreamPlayer", true, false):
		player.stream_paused = false
		player.stop()
	await create_timer(0.1).timeout
	test_viewport.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	quit(1 if failures else 0)

func _wait_for_action() -> void:
	if game.playback.active and game.run.phase == PackRun.Phase.FIGHT:
		while not game.run.pending_turn.is_empty():
			await process_frame
		if game.run.combat_state == PackRun.CombatState.FINISHED:
			while game.busy:
				await process_frame
			return
		game.playback.cancel()
		await create_timer(0.32).timeout
		game.busy = false
		game.board.mouse_filter = Control.MOUSE_FILTER_STOP
		game._refresh()
	else:
		while game.busy:
			await process_frame
