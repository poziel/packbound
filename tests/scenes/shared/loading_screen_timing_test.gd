extends "res://tests/support/test_case.gd"
## Run with --fixed-fps 60 to measure sound lead against the rendered reveal.

func _initialize() -> void:
	if not require_isolation():
		return
	_run.call_deferred()

func _run() -> void:
	var screen: CanvasLayer = load("res://scenes/shared/loading_screen/loading_screen.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	print("Configured sound lead: ", screen.disappear_sound_lead_seconds, " seconds")
	for lead: float in [0.0, 0.1, 0.2]:
		screen.disappear_sound_lead_seconds = lead
		var frame: int = 0
		var sound_frame: int = -1
		var reveal_frame: int = -1
		screen.play(func() -> void: pass)
		while screen.active and frame < 120:
			# Fixed-fps advances tween time synthetically; let the real audio mixer
			# consume/retire playback handles at the same pace.
			OS.delay_msec(16)
			await process_frame
			frame += 1
			if sound_frame < 0 and screen.disappear_sound.playing:
				sound_frame = frame
			if sound_frame >= 0 and reveal_frame < 0 and screen.coverage < 1.0:
				reveal_frame = frame
		var measured: float = float(reveal_frame - sound_frame) / 60.0
		print("Requested lead: ", lead, " s; observed: ", measured, " s")
		checks += 1
		if sound_frame < 0 or reveal_frame < 0 or absf(measured - lead) > 2.0 / 60.0:
			failures += 1
			printerr("FAIL: Sound lead follows configured value")
		screen.appear_sound.stop()
		screen.disappear_sound.stop()
	for frame in range(8):
		OS.delay_msec(16)
		await process_frame
	await preload("res://tests/support/automatic_combat_cleanup.gd").release(self, screen)
	print("LOADING SOUND TIMING: ", failures, " failures")
	report("loading_screen_timing")
	quit(1 if failures else 0)
