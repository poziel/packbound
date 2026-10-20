extends "res://tests/support/menu_support.gd"

var click_count: int = 0

func _count_click() -> void:
	click_count += 1

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var menu: PackMenuFlow = game.front
	var saved: Dictionary = menu.settings.duplicate(true)
	# Detect a denied user-data write explicitly instead of accepting coincidental
	# default values as evidence that runtime persistence worked.
	var config_probe: ConfigFile = ConfigFile.new()
	for setting_key: String in saved:
		config_probe.set_value("options", setting_key, saved[setting_key])
	var save_error: Error = config_probe.save("user://packbound_settings.cfg")
	check(save_error == OK, "Settings storage is writable: %s (%s)" % [OS.get_user_data_dir(), error_string(save_error)])
	var sound: PackMenuAudio = menu.audio
	sound.click_played.connect(_count_click)
	check(game.action.pressed.is_connected(sound.play_click), "Existing gameplay buttons receive click sound")
	check(sound.fx.stream is AudioStreamWAV and sound.fx.stream.resource_path == "res://assets/audio/sfx/ui/button_activate.wav", "FX uses the replacement UI click WAV")
	var click_decoder: AudioStreamPlayback = sound.fx.stream.instantiate_playback()
	click_decoder.start()
	var click_frames: PackedVector2Array = click_decoder.mix_audio(1.0, 8192)
	var click_peak: float = 0.0
	for frame in click_frames:
		click_peak = maxf(click_peak, maxf(absf(frame.x), absf(frame.y)))
	check(click_peak > 0.001, "Supplied click decodes non-silent samples")
	click_decoder.stop()
	var song: AudioStreamMP3 = sound.music.stream
	check(song.loop and song.loop_offset == 0.0, "Song loops from its beginning")
	check(song.get_length() > 190 and song.get_length() < 195, "Entire supplied composition is loaded")
	check(sound.music.bus == "Music" and sound.fx.bus == "FX", "Music and effects use separate buses")
	check(AudioServer.get_bus_send(AudioServer.get_bus_index("Music")) == &"Master", "Music routes through Master")
	check(AudioServer.get_bus_send(AudioServer.get_bus_index("FX")) == &"Master", "FX routes through Master")
	check(sound.music.playing and not sound.music.stream_paused, "Main menu autoplays song")
	_check_fonts(menu.home, menu)
	_check_fonts(menu.options, menu)
	_check_fonts(menu.selection, menu)
	# Decode real samples independently of the output device, including two wraps.
	var playback: AudioStreamPlayback = song.instantiate_playback()
	playback.start(10.0)
	var frames: PackedVector2Array = playback.mix_audio(1.0, 8192)
	var peak: float = 0.0
	for frame in frames:
		peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
	check(frames.size() == 8192 and peak > 0.001, "Godot decodes non-silent stereo song samples")
	for index in range(2):
		playback.seek(song.get_length() - 0.04)
		playback.mix_audio(1.0, 24000)
		check(playback.is_playing() and playback.get_playback_position() < 1.0, "Audio decoder crosses loop boundary %d" % (index + 1))
	playback.stop()
	await create_timer(0.1).timeout
	var position_before: float = sound.music.get_playback_position()
	click(game.settings_button)
	check(click_count == 1, "Pointer button activation plays exactly one click")
	var before_clicks: int = click_count
	menu.flash_toggle.set_pressed_no_signal(not menu.flash_toggle.button_pressed)
	check(click_count == before_clicks, "Restoring checkbox state stays silent")
	menu.option_tabs.current_tab = 1
	await process_frame
	before_clicks = click_count
	click(menu.flash_toggle)
	check(click_count == before_clicks + 1, "Checkbox activation plays exactly one click")
	before_clicks = click_count
	menu.resolution.item_selected.emit(menu.resolution.selected)
	check(click_count == before_clicks + 1, "Dropdown selection plays exactly one click")
	var late_button: Button = Button.new()
	game.add_child(late_button)
	before_clicks = click_count
	late_button.pressed.emit()
	check(click_count == before_clicks + 1, "Dynamically created gameplay button receives click sound")
	late_button.queue_free()
	menu.back_button.grab_focus()
	before_clicks = click_count
	key(KEY_ENTER)
	check(click_count == before_clicks + 1 and menu.home.visible, "Keyboard activation plays exactly one click")
	click(game.settings_button)
	await create_timer(0.1).timeout
	check(sound.music.get_playback_position() >= position_before, "Opening Options does not restart the song")
	check(menu.volume_sliders.size() == 4, "Four independent audio sliders including ambience")
	menu.option_tabs.current_tab = 2
	await process_frame
	for key_name: String in PackMenuAudio.BUS_NAMES:
		var slider: HSlider = menu.volume_sliders[key_name]
		var bus: int = AudioServer.get_bus_index(PackMenuAudio.BUS_NAMES[key_name])
		slider.value = 37
		check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(bus)), 0.37), key_name + " changes real bus gain")
		check(menu.volume_labels[key_name].text == "37%", key_name + " shows current percentage")
		slider.grab_focus()
		key(KEY_RIGHT)
		check(slider.value == 38 and menu.settings[key_name] == 38, key_name + " supports keyboard adjustment")
		slider.value = 0
		check(AudioServer.is_bus_mute(bus), key_name + " at zero is truly muted")
		slider.value = 100
		check(not AudioServer.is_bus_mute(bus) and is_zero_approx(AudioServer.get_bus_volume_db(bus)), key_name + " unmutes at full gain")
		click(slider)
		check(slider.value >= 48 and slider.value <= 52, key_name + " supports pointer track input")
		check(int(menu.settings[key_name]) == int(slider.value), key_name + " stores pointer value")
	menu.volume_sliders["music"].value = 0
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("FX")), "Music mute leaves FX independent")
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Ambience")), "Music mute leaves ambience audible")
	menu.volume_sliders["music"].value = 70
	menu.volume_sliders["ambience"].value = 0
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")) and not AudioServer.is_bus_mute(AudioServer.get_bus_index("FX")), "Ambience mute leaves music and FX independent")
	menu.volume_sliders["ambience"].value = 15
	menu.volume_sliders["fx"].value = 0
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "FX mute leaves Music independent")
	menu.volume_sliders["fx"].value = 60
	menu.volume_sliders["volume"].value = 80
	var restored: PackMenuFlow = PackMenuFlow.new()
	restored._load_settings()
	for key_name: String in PackMenuAudio.BUS_NAMES:
		check(restored.settings[key_name] == menu.settings[key_name], "%s persists to a fresh settings instance (saved=%s, loaded=%s)" % [key_name, menu.settings[key_name], restored.settings[key_name]])
	restored.free()
	sound.play_click()
	check(sound.fx.playing and sound.fx.stream.get_length() > 0.04, "FX preview produces a click stream")
	await snapshot("menus-options-audio")
	click(menu.back_button)
	click(menu.play_button)
	await game.loading_screen.finished
	check(sound.music.playing and not sound.music.stream_paused, "Class selection keeps music playing")
	await snapshot("menus-delvers")
	click(menu.class_buttons["mage"])
	await game.loading_screen.finished
	await create_timer(PackMenuAudio.CROSSFADE_SECONDS + 0.1).timeout
	check(sound.music.stream_paused, "Starting gameplay pauses menu music")
	await create_timer(0.1).timeout
	position_before = sound.music.get_playback_position()
	await create_timer(0.15).timeout
	check(absf(sound.music.get_playback_position() - position_before) < 0.08, "Paused music does not advance")
	game.show_menu()
	await create_timer(0.1).timeout
	check(not sound.music.stream_paused and sound.music.get_playback_position() >= position_before, "Returning to menu resumes previous song position")
	sound.music.seek(song.get_length() - 0.05)
	await create_timer(0.3).timeout
	check(sound.music.playing and sound.music.get_playback_position() < 1.0, "Live player also crosses loop boundary without stopping")
	for dimensions in [Vector2i(960, 600), Vector2i(1600, 900), Vector2i(800, 900)]:
		if DisplayServer.get_name() != "headless":
			root.size = dimensions
			await create_timer(0.1).timeout
		menu.show_options()
		await process_frame
		_check_layout(menu.options)
		await snapshot("menus-options-%dx%d" % [dimensions.x, dimensions.y])
		menu.show_classes()
		await process_frame
		_check_layout(menu.selection)
		await snapshot("menus-delvers-%dx%d" % [dimensions.x, dimensions.y])
	for key_name: String in PackMenuAudio.BUS_NAMES:
		menu._set_option(key_name, saved[key_name])
	report("FRONTEND AUDIO RESULT")
	await preload("res://tests/support/automatic_combat_cleanup.gd").release(self, game)
	quit(1 if failures else 0)

func _check_fonts(parent: Node, menu: PackMenuFlow) -> void:
	for child in parent.get_children():
		if child is Label or child is Button:
			var font: Font = child.get_theme_font("font")
			var expected: String = "Pixel Operator"
			check(font.get_font_name().contains(expected), "Consistent menu font: " + child.text)
		_check_fonts(child, menu)

func _check_layout(parent: Control) -> void:
	var previous: Rect2 = Rect2()
	for child in parent.get_children():
		if child is Control and child.is_visible_in_tree():
			check(Rect2(0, 0, 1280, 800).encloses(child.get_global_rect()), "Menu content fits logical canvas: %s %s" % [child.name, child.get_global_rect()])
		if child is Button and not child is OptionButton:
			check(not previous.intersects(child.get_rect()), "Menu buttons do not overlap: %s/%s %s vs %s" % [parent.name, child.name, child.get_rect(), previous])
			previous = child.get_rect()
			for inner in child.get_children():
				if inner is Control:
					check(Rect2(Vector2.ZERO, child.size).encloses(inner.get_rect()), "Delver content fits its tile")
