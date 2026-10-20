extends "res://tests/support/menu_support.gd"

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var audio = game.front.audio
	game.start_run("warrior", 42)
	check(not audio.gameplay_music.playing and audio.next_track_timer.time_left >= 3.0 and audio.next_track_timer.time_left <= 4.0, "First gameplay song waits 3 to 4 seconds")
	check(audio.has_node("AmbienceOne") and audio.has_node("AmbienceTwo"), "Both ambience layers are present")
	if not audio.has_node("AmbienceOne"):
		quit(1)
		return
	await create_timer(audio.next_track_timer.time_left + 0.2).timeout
	var layers: Array[AudioStreamPlayer] = [audio.get_node("AmbienceOne"), audio.get_node("AmbienceTwo")]
	for layer in layers:
		check(layer.playing and layer.bus == &"Ambience", "Ambience autoplays on independent bus")
		var loop: AudioStreamOggVorbis = layer.stream
		check(loop.loop, "Ambience loops continuously")
		var playback: AudioStreamPlayback = loop.instantiate_playback()
		playback.start(loop.get_length() - 0.04)
		playback.mix_audio(1.0, 24000)
		check(playback.is_playing() and playback.get_playback_position() < 1.0, "Ambience decoder crosses loop boundary")
		playback.seek(1.0)
		var peak: float = 0.0
		for frame: Vector2 in playback.mix_audio(1.0, 8192):
			peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
		check(peak > 0.00001, "Ambience decodes non-silent audio")
		playback.stop()
	check(game.front.settings["ambience"] == 15, "Ambience defaults to a quiet 15 percent")
	game.show_pause()
	game._open_options()
	await create_timer(1.2).timeout
	check(audio.music.stream_paused, "Gameplay options leave lobby music paused")
	check(audio.has_node("GameplayMusic"), "Gameplay has its own music player")
	if not audio.has_node("GameplayMusic"):
		report("GAMEPLAY MUSIC RESULT")
		quit(1)
		return
	var player: AudioStreamPlayer = audio.get_node("GameplayMusic")
	check(player.playing and not player.stream_paused, "Gameplay music continues in options")
	var song: AudioStream = player.stream
	var position: float = player.get_playback_position()
	game.front._options_back()
	await create_timer(0.2).timeout
	check(player.stream == song and player.get_playback_position() >= position, "Closing options preserves track and position")
	game.show_menu()
	await create_timer(0.4).timeout
	check(audio.music.volume_linear > 0.0 and audio.music.volume_linear < 1.0, "Lobby fades in gradually")
	check(player.volume_linear > 0.0 and player.volume_linear < 1.0, "Gameplay fades out simultaneously")
	await create_timer(0.8).timeout
	check(player.stream_paused and not audio.music.stream_paused, "Lobby owns playback after crossfade")
	game.start_run("warrior", 43)
	await create_timer(1.2).timeout
	check(audio.music.stream_paused and player.playing, "Entering gameplay crossfades automatically")
	check(audio.gameplay_tracks.size() == 4, "Only the four replacement songs are in the playlist")
	for path: String in audio.gameplay_tracks:
		var stream: AudioStreamOggVorbis = load(path)
		check(stream != null and not stream.loop and stream.get_length() > 1.0, "Playlist track loads without looping: " + path)
		var decoder: AudioStreamPlayback = stream.instantiate_playback()
		decoder.start(10.0)
		var peak: float = 0.0
		for frame: Vector2 in decoder.mix_audio(1.0, 8192):
			peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
		check(peak > 0.001, "Playlist track decodes audible samples: " + path)
		decoder.stop()
	player.seek(player.stream.get_length() - 0.1)
	await create_timer(0.5).timeout
	check(not player.playing and not audio.next_track_timer.is_stopped(), "Natural track end schedules next track")
	check(audio.next_track_timer.wait_time >= 10.0 and audio.next_track_timer.wait_time <= 30.0, "Gap is randomly chosen between 10 and 30 seconds")
	var gaps: Dictionary = {}
	for index in range(8):
		audio._gameplay_finished()
		var gap: float = audio.next_track_timer.wait_time
		check(gap >= 10.0 and gap <= 30.0, "Each generated gap stays within range")
		gaps[gap] = true
	check(gaps.size() > 1, "Successive song gaps vary")
	for layer in layers:
		check(layer.playing and not layer.stream_paused, "Ambience continues through music silence")
	game.show_pause()
	game._open_options()
	await create_timer(0.2).timeout
	check(not player.playing and not audio.next_track_timer.paused, "Options preserve the silent gap")
	for layer in layers:
		check(layer.playing and not layer.stream_paused, "Options keep ambience playing")
	game.show_menu()
	await create_timer(1.2).timeout
	check(audio.next_track_timer.paused and not player.playing, "Lobby pauses the playlist gap")
	for layer in layers:
		check(layer.stream_paused and is_zero_approx(layer.volume_linear), "Lobby fades out and pauses ambience")
	game.start_run("warrior", 44)
	await create_timer(0.5).timeout
	check(not player.playing, "Returning during the gap does not start a track early")
	# The real 10–30 second gap is asserted above. Exercise its timeout without
	# allowing a valid random gap plus the other transitions to exceed test budget.
	audio.next_track_timer.start(0.05)
	await audio.next_track_timer.timeout
	check(player.playing and player.stream != song, "Timer starts another random track without immediate repeat")
	game.show_menu()
	game.start_run("warrior", 45)
	game.show_menu()
	await create_timer(1.2).timeout
	check(not audio.music.stream_paused and player.stream_paused, "Rapid transitions settle on the latest destination")
	await preload("res://tests/support/automatic_combat_cleanup.gd").release(self, game)
	report("GAMEPLAY MUSIC RESULT")
	quit(1 if failures else 0)
