extends "res://tests/support/menu_support.gd"

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var audio = game.front.audio
	for player: AudioStreamPlayer in [audio.ui_hover_fx, audio.item_pickup_fx, audio.item_drop_fx]:
		check(player.bus == &"FX" and player.stream.get_length() > 0.02, "New placeholder has audible duration and shares FX bus")
	var hover_button := Button.new()
	root.add_child(hover_button)
	hover_button.mouse_entered.emit()
	check(audio.ui_hover_fx.playing, "Dynamically added UI button plays hover feedback")
	audio.ui_hover_fx.stop()
	hover_button.disabled = true
	hover_button.mouse_entered.emit()
	check(not audio.ui_hover_fx.playing, "Disabled button hover is silent")
	var pitches: Dictionary = {}
	for index in range(16):
		audio.play_item_hover()
		pitches[audio.item_hover_fx.pitch_scale] = true
	check(pitches.size() > 1, "Item hover pitch varies between entries")
	hover_button.disabled = false
	pitches.clear()
	for index in range(16):
		hover_button.mouse_entered.emit()
		pitches[audio.ui_hover_fx.pitch_scale] = true
	check(pitches.size() > 1, "UI hover pitch varies between entries")
	hover_button.queue_free()
	audio.item_hover_fx.stop()
	audio.ui_hover_fx.stop()
	check(game.combat_audio.stream.resource_path == "res://assets/audio/sfx/combat/enemy_hit.wav", "Enemy impact uses the new descriptive asset")
	check(game.front.audio.fx.stream.resource_path == "res://assets/audio/sfx/ui/button_activate.wav", "UI uses the replacement click")
	check(game.has_node("EnemyDeathAudio"), "Death has an independent player")
	check(game.front.audio.has_node("ItemHoverFX"), "Shared item hover has an independent player")
	if not game.has_node("EnemyDeathAudio") or not game.front.audio.has_node("ItemHoverFX"):
		quit(1)
		return
	var death: AudioStreamPlayer = game.get_node("EnemyDeathAudio")
	var hover: AudioStreamPlayer = game.front.audio.get_node("ItemHoverFX")
	for path: String in ["combat/enemy_hit", "combat/enemy_death", "ui/item_hover", "ui/button_activate"]:
		var stream: AudioStreamWAV = load("res://assets/audio/sfx/%s.wav" % path)
		check(stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, "Effect does not loop: " + path)
		var decoder: AudioStreamPlayback = stream.instantiate_playback()
		decoder.start()
		var peak: float = 0.0
		for frame: Vector2 in decoder.mix_audio(1.0, 8192):
			peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
		check(peak > 0.001, "Effect decodes audible samples: " + path)
		decoder.stop()
	for key: String in PackCatalog.classes():
		game.start_run(key, 42)
		game.enemy_card.play_hit(false)
		check(game.combat_audio.playing, "Hit reaction plays sound for " + key)
	game.start_run("warrior", 42)
	game._player_resolved({"dealt": 0, "poison_tick": 0, "burn_tick": 0, "special_taken": 0})
	check(not game.combat_audio.playing, "Zero-damage actions stay silent")
	game._monster_resolved({"taken": 0, "retaliation": 1, "playback_strikes": false})
	check(game.combat_audio.playing, "Retaliation uses the shared enemy hit sound")
	game.start_run("warrior", 42)
	game.enemy_card.play_hit(false, 1.0, true)
	check(not death.playing, "Death audio waits for disintegration")
	await create_timer(0.34).timeout
	check(game.enemy_card.defeated and death.playing, "Death audio starts with the pixel burst")
	# Exercise pause with live streams, independent of the short hit clip's tail.
	game.combat_audio.play()
	death.play()
	game._combat_pause_changed(true)
	check(death.stream_paused and game.combat_audio.stream_paused, "Combat pause pauses both effect tails")
	game._combat_pause_changed(false)
	game.show_menu()
	check(not death.playing and not game.combat_audio.playing, "Lobby cancels combat effect tails")
	game.start_run("warrior", 42)
	game.character_tabs.current_tab = game.character_tabs.get_tab_idx_from_control(game.combat.get_node("CharacterPanel/Tabs/Relics"))
	game.run.relics.clear()
	game._refresh_relics()
	game.relic_slots[0].mouse_entered.emit()
	check(not hover.playing, "Empty relic slots stay silent")
	game.run.relics.append("diagonal_thread")
	game._refresh_relics()
	game.relic_slots[0].mouse_entered.emit()
	check(hover.playing, "Occupied relic hover plays sound")
	if DisplayServer.get_name() != "headless":
		hover.stop()
		motion(Vector2(5, 5))
		await process_frame
		motion(game.relic_slots[0].get_global_rect().get_center())
		await process_frame
		check(hover.playing, "Real pointer entry over relic art plays hover sound")
		await create_timer(0.08).timeout
		var position: float = hover.get_playback_position()
		motion(game.relic_slots[0].get_global_rect().get_center() + Vector2.ONE)
		await process_frame
		check(hover.get_playback_position() >= position, "Motion inside a relic does not retrigger its sound")
	hover.stop()
	game.run.relic_rewards.append(1)
	game.run.roll_relics()
	game._open_reward(true)
	game.choice_buttons[0].mouse_entered.emit()
	check(hover.playing, "Relic reward hover plays sound")
	hover.stop()
	game.reward_is_relic = false
	game.run.offers.clear()
	game.run.offers.append("longsword")
	game.choice_buttons[0].mouse_entered.emit()
	check(hover.playing, "Item reward hover uses the same sound as relics")
	hover.stop()
	game._close_modal()
	game.character_tabs.current_tab = game.character_tabs.get_tab_idx_from_control(game.board.get_parent())
	await process_frame
	await process_frame
	var item: Dictionary = game.run.items[0]
	var at: Vector2 = game.board.item_rect(item).get_center()
	game.board.begin_drag(item, at)
	check(audio.item_pickup_fx.playing, "Picking up a board item plays pickup feedback")
	game.board.drop_at(at)
	check(audio.item_drop_fx.playing, "Dropping a board item plays drop feedback")
	game.board.item_motions.clear()
	game.board.hovered_id = -1
	var movement := InputEventMouseMotion.new()
	movement.position = at
	game.board._gui_input(movement)
	check(hover.playing, "Backpack item hover uses the shared sound")
	hover.stop()
	movement.position = at + Vector2.ONE
	game.board._gui_input(movement)
	check(not hover.playing, "Motion over the same backpack item stays silent")
	game.board.mouse_exited.emit()
	game.board._gui_input(movement)
	check(hover.playing, "Re-entering a backpack item plays the hover sound again")
	if DisplayServer.get_name() != "headless":
		# Direct _gui_input checks above do not update the viewport's hover owner.
		game.board.mouse_exited.emit()
		hover.stop()
		motion(Vector2(5, 5))
		await process_frame
		motion(game.board.global_position + at)
		await process_frame
		check(hover.playing, "Real pointer entry into a backpack item plays sound (target=%s, hovered=%s)" % [game.board.global_position + at, root.gui_get_hovered_control()])
	hover.stop()
	item["cell"] = null
	game._toggle_storage()
	game.storage.refresh()
	game.storage.item_hovered.emit()
	check(hover.playing, "Storage item hover uses the shared sound")
	if DisplayServer.get_name() != "headless":
		hover.stop()
		var entries := {"count": 0}
		var record_entry: Callable = func() -> void: entries.count += 1
		game.storage.item_hovered.connect(record_entry)
		var settled: RigidBody2D = game.storage.bodies[item.id]
		settled.freeze = true
		motion(Vector2(5, 5))
		await process_frame
		await process_frame
		var target: Vector2 = game.storage.pile.get_global_transform_with_canvas() * settled.visual_transform().origin
		# The physics stash polls the viewport pointer rather than GUI entry signals.
		root.warp_mouse(target)
		motion(target)
		await process_frame
		await process_frame
		check(entries.count > 0, "Real pointer entry into storage triggers item-hover audio (pointer=%s body=%s visible=%s hovered=%s dragging=%s)" % [game.storage.pile.get_local_mouse_position(), settled.visual_transform().origin, settled.visible, game.storage.hovered_id, game.board.dragging.get("id", -1)])
		game.storage.item_hovered.disconnect(record_entry)
		settled.freeze = false
	audio.item_pickup_fx.stop()
	var body: RigidBody2D = game.storage.bodies[item.id]
	var pickup := InputEventMouseButton.new()
	pickup.button_index = MOUSE_BUTTON_LEFT
	pickup.pressed = true
	pickup.position = game.storage.pile.position + body.position
	game.storage._panel_input(pickup)
	check(game.storage.grabbed == body and audio.item_pickup_fx.playing, "Picking up a gravity-stash item plays pickup feedback")
	audio.item_drop_fx.stop()
	game.storage._release_grab()
	check(audio.item_drop_fx.playing, "Releasing a gravity-stash item plays drop feedback")
	for player: AudioStreamPlayer in [death, hover, game.combat_audio, game.front.audio.fx]:
		check(player.bus == &"FX", "All sound effects share the FX setting")
	game.front.settings["fx"] = 0
	game.front.audio.apply_settings(game.front.settings)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("FX")), "FX mute covers all new sounds")
	for player: Node in game.find_children("*", "AudioStreamPlayer", true, false):
		player.stream_paused = false
		player.stop()
	game.front.audio.next_track_timer.stop()
	if game.front.audio.transition and game.front.audio.transition.is_valid():
		game.front.audio.transition.kill()
	await create_timer(0.1).timeout
	game.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	report("SOUND EFFECTS RESULT")
	quit(1 if failures else 0)
