extends "res://tests/support/test_case.gd"

func _run() -> void:
	for paused: bool in [false, true]:
		var audio: Node = load("res://scenes/menus/menu_audio/menu_audio.tscn").instantiate()
		root.add_child(audio)
		audio.set_menu_active(true)
		audio.set_menu_active(false)
		audio.play_item_hover()
		audio.play_item_pickup()
		var players: Array[Node] = audio.find_children("*", "AudioStreamPlayer", true, false)
		var playback_handles: Array[WeakRef] = []
		for player: AudioStreamPlayer in players:
			if player.has_stream_playback():
				playback_handles.append(weakref(player.get_stream_playback()))
		check(audio.ambience_layers[0].playing, "Gameplay starts looping ambience before teardown")
		check(audio.item_pickup_fx.has_stream_playback(), "Pickup owns a playback before teardown")
		for player: AudioStreamPlayer in players:
			player.stream_paused = paused
		# Removing the owner must release playback without a timer or test-only cleanup.
		root.remove_child(audio)
		check(audio.next_track_timer.is_stopped(), "Leaving tree cancels queued music")
		check(not audio.transition.is_valid(), "Leaving tree cancels crossfade callbacks")
		for player: AudioStreamPlayer in players:
			check(player.stream == null, "Leaving tree releases %s stream (paused=%s)" % [player.name, paused])
			check(not player.has_stream_playback(), "Leaving tree releases %s playback (paused=%s)" % [player.name, paused])
		audio.free()
		var deadline: int = Time.get_ticks_msec() + 1000
		while playback_handles.any(func(handle: WeakRef) -> bool: return handle.get_ref() != null) and Time.get_ticks_msec() < deadline:
			await process_frame
		check(playback_handles.all(func(handle: WeakRef) -> bool: return handle.get_ref() == null), "Mixer releases stopped playback handles within deadline")
	await _application_shutdown_checks()
	report("MENU AUDIO LIFETIME")
	quit(1 if failures else 0)

func _application_shutdown_checks() -> void:
	for gameplay: bool in [false, true]:
		var game: Control = load("res://scenes/main.tscn").instantiate()
		root.add_child(game)
		await process_frame
		if gameplay:
			game.start_run("warrior", 1729)
		game.front.audio.play_item_pickup()
		game.combat_audio.play()
		var handles: Array[WeakRef] = []
		var players: Array[Node] = game.find_children("*", "AudioStreamPlayer", true, false)
		for player: AudioStreamPlayer in players:
			if player.has_stream_playback():
				handles.append(weakref(player.get_stream_playback()))
		check(not handles.is_empty(), "Application has live playback before graceful shutdown")
		check(await game.shutdown_audio(), "Application shutdown completes mixer release within deadline")
		check(handles.all(func(handle: WeakRef) -> bool: return handle.get_ref() == null), "Application shutdown releases actual playback handles before quit")
		for player: AudioStreamPlayer in players:
			check(player.stream == null and not player.has_stream_playback(), "Application shutdown detaches %s" % player.name)
		game.queue_free()
		await process_frame
