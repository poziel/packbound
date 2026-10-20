extends "res://tests/support/test_case.gd"

func _run() -> void:
	var path := "res://systems/audio/sound_playback.gd"
	check(ResourceLoader.exists(path), "Reusable sound playback service exists")
	if ResourceLoader.exists(path):
		var playback = load(path)
		var player := AudioStreamPlayer.new()
		player.stream = AudioStreamWAV.new()
		root.add_child(player)
		var pitches: Dictionary = {}
		for i in 64:
			playback.play_random_pitch(player)
			check(player.pitch_scale >= 0.9 and player.pitch_scale <= 1.1, "Default pitch remains within ten percent")
			pitches[player.pitch_scale] = true
		check(pitches.size() > 1, "Repeated playback varies pitch")
		playback.play_random_pitch(player, 0.8, 0.8, 1.5)
		check(is_equal_approx(player.pitch_scale, 1.2), "Caller can choose range and base pitch")
		playback.play_random_pitch(player, 1.1, 0.9)
		check(player.pitch_scale >= 0.9 and player.pitch_scale <= 1.1, "Reversed range is normalized")
		seed(9182)
		var expected := randi()
		seed(9182)
		playback.play_random_pitch(player)
		check_equal(randi(), expected, "Cosmetic sound randomness does not consume gameplay RNG")
		player.free()
	report("RANDOM PITCH")
	quit(1 if failures else 0)
