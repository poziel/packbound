extends "res://tests/support/test_case.gd"

var swaps: int = 0

func _initialize() -> void:
	if not require_isolation():
		return
	_run.call_deferred()

func _run() -> void:
	if not ResourceLoader.exists("res://scenes/shared/loading_screen/loading_screen.tscn"):
		check(false, "Shared loading screen exists")
		report("loading_screen")
		quit(1)
		return
	var game: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var screen: Node = game.get_node("LoadingScreen")
	var scanned_audio: PackedStringArray = ResourceLoader.list_directory("res://assets/audio/")
	check(not scanned_audio.has("loading_screen_on.wav") and not scanned_audio.has("loading_screen_off.wav"), "Unsupported original WAVs stay outside Godot's import scan")
	check(not DirAccess.dir_exists_absolute("res://assets/audio/sources"), "Unused original recordings stay outside the runtime asset tree")
	if not screen.has_node("AppearSound") or not screen.has_node("DisappearSound"):
		check(false, "Loading screen has appear and disappear sound players")
		await preload("res://tests/support/automatic_combat_cleanup.gd").release(self, game)
		report("loading_screen")
		quit(1)
		return
	var appear: AudioStreamPlayer = screen.get_node("AppearSound")
	var disappear: AudioStreamPlayer = screen.get_node("DisappearSound")
	if appear.stream == null or disappear.stream == null:
		check(false, "Both loading clips import successfully")
		await preload("res://tests/support/automatic_combat_cleanup.gd").release(self, game)
		report("loading_screen")
		quit(1)
		return
	check(appear.stream.resource_path == "res://assets/audio/transitions/loading_screen_cover.wav", "Cover uses playback copy of supplied appear clip")
	check(disappear.stream.resource_path == "res://assets/audio/transitions/loading_screen_reveal.wav", "Reveal uses playback copy of supplied disappear clip")
	check(appear.bus == &"FX" and disappear.bus == &"FX", "Loading audio respects FX and Master settings")
	check(not appear.autoplay and not disappear.autoplay, "Loading audio stays silent on startup")
	var disappear_count: Array[int] = [0]
	disappear.finished.connect(func() -> void: disappear_count[0] += 1)
	screen.play(func() -> void:
		swaps += 1
		check(screen.coverage == 1.0, "Scene swap happens fully covered")
		check(not disappear.playing, "Disappear sound stays silent through the closing animation")
		game.front.show_classes()
	)
	check(screen.active, "Navigation locks immediately")
	check(appear.playing and not disappear.playing, "Appear sound begins with cover; disappear waits for disappear")
	check(game.front.home.visible, "Outgoing scene remains during close")
	screen.play(func() -> void: swaps += 100)
	while not disappear.playing:
		await process_frame
	check(disappear.get_playback_position() < 0.1, "Disappear clip starts from the beginning without the old seek offset")
	await screen.finished
	check(disappear.playing or disappear_count[0] == 1, "Disappear sound plays when destination is revealed")
	check(disappear.get_playback_position() < 0.5, "Disappear sound starts at disappear rather than during covered pause")
	check(swaps == 1, "Duplicate requests cannot execute a second swap")
	check(not screen.active and not screen.get_node("Cover").visible, "Overlay and input lock clear after disappear")
	check(game.front.selection.visible, "Destination remains visible after disappear")
	game.front._choose_class("warrior")
	check(screen.active and not game.combat.visible, "Class click waits for cover before entering run")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	await screen.finished
	check(game.combat.visible and not game.front.visible and not game.modal.visible, "Keyboard cannot divert run entry")
	game._transition_to_menu()
	check(screen.active and game.combat.visible, "Return to menu keeps gameplay until covered")
	await screen.finished
	check(game.front.home.visible and not game.combat.visible, "Return reaches title")
	check(game.front.play_button.has_focus(), "Return restores safe keyboard focus")
	game.front.play_button.pressed.emit()
	check(screen.active and game.front.home.visible, "Play button animates title to selection")
	await screen.finished
	game.front.selection.back_requested.emit()
	check(screen.active and game.front.selection.visible, "Back animates selection to title")
	await screen.finished
	check(game.front.home.visible, "Back reaches title")
	paused = true
	screen.play(func() -> void: swaps += 1)
	await screen.finished
	check(swaps == 2 and not screen.active, "Transition finishes even while scene tree is paused")
	paused = false
	root.size = Vector2i(960, 540)
	await process_frame
	check(screen.get_node("Cover").size == root.get_visible_rect().size, "Cover fills resized viewport")
	check(screen.get_node("Cover").material.get_shader_parameter("canvas_size") == screen.get_node("Cover").size, "Pixel grid tracks resized cover")
	print("LOADING SCREEN: ", checks, " checks, ", failures, " failures")
	await preload("res://tests/support/automatic_combat_cleanup.gd").release(self, game)
	report("loading_screen")
	quit(1 if failures else 0)
