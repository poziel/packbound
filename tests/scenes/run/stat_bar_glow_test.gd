extends "res://tests/support/test_case.gd"

const BAR: PackedScene = preload("res://components/ui/indicators/pixel_stat_bar/pixel_stat_bar.tscn")
var game: Control
var view: SubViewport


func _initialize() -> void:
	if not require_isolation():
		return
	call_deferred("_run")




func _run() -> void:
	create_timer(30).timeout.connect(func() -> void: printerr("Glow test timed out"); quit(2))
	view = SubViewport.new()
	view.size = Vector2i(1280, 800)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var bar: PixelStatBar = BAR.instantiate()
	var other: PixelStatBar = BAR.instantiate()
	view.add_child(bar)
	view.add_child(other)
	await process_frame
	check(not bar.glow_enabled and not bar.is_glowing(), "New instances rest without glow")
	bar.set_amount(8, 10)
	bar.value = 2
	bar.value = 9
	bar.size.x = 320
	check(not bar.is_glowing(), "Loading, damage, healing and resizing do not implicitly flash a reusable bar")
	var resting_rect: Rect2 = bar.get_rect()
	bar.flash_glow()
	check(bar.is_glowing() and not other.is_glowing(), "Explicit feedback affects only the requested instance")
	check(bar.get_rect() == resting_rect and bar.value == 9, "Feedback preserves bar geometry and amount")
	await create_timer(0.25).timeout
	bar.flash_glow()
	await create_timer(0.2).timeout
	check(bar.is_glowing(), "A repeated hit restarts feedback instead of ending at the old deadline")
	await create_timer(0.25).timeout
	check(not bar.is_glowing(), "Transient feedback fades fully back to rest")
	bar.glow_enabled = true
	bar.flash_glow()
	bar.clear_glow()
	check(bar.is_glowing(), "Optional steady glow survives transient cancellation")
	bar.glow_enabled = false
	check(not bar.is_glowing(), "Steady glow can be disabled independently")
	bar.set_amount(0, 10)
	bar.flash_glow()
	check(bar.is_glowing(), "An empty bar can show a fatal hit")
	bar.hide()
	bar.show()
	check(not bar.is_glowing(), "Hiding a bar clears stale transient feedback")
	bar.queue_free()
	other.queue_free()
	await process_frame

	var demo: Control = load("res://components/ui/indicators/pixel_stat_bar/demo.tscn").instantiate()
	view.add_child(demo)
	await process_frame
	await _snapshot("stat-bars-resting")
	demo.get_node("Glow").pressed.emit()
	check(demo.get_node("Health").is_glowing() and demo.get_node("Empty").is_glowing(), "Demo previews feedback on full, partial and empty examples")
	await _snapshot("stat-bars-highlight")
	demo.queue_free()
	await process_frame

	game = load("res://scenes/main.tscn").instantiate()
	view.add_child(game)
	await process_frame
	var item: Dictionary = _encounter()
	check(not game.hp_bar.is_glowing() and not game.enemy_bar.is_glowing(), "An encounter starts with quiet health borders")
	game._act()
	check(not game.hp_bar.is_glowing() and game.enemy_bar.is_glowing(), "Player hit highlights only enemy health before the response")
	check(not game.mana_bar.is_glowing() and not game.stamina_bar.is_glowing() and not game.enemy_shield_bar.is_glowing(), "Combat does not highlight unrelated resource bars")
	await _snapshot("stat-bars-combat-hit")
	await _wait_for_response()
	check(game.hp_bar.is_glowing() and not game.enemy_bar.is_glowing(), "Incoming damage highlights player health when the monster responds")
	game.playback.cancel()
	await create_timer(0.46).timeout
	check(not game.hp_bar.is_glowing() and not game.enemy_bar.is_glowing(), "Both health bars return to rest after a turn")
	await _snapshot("stat-bars-combat-resting")

	item = _encounter()
	item["block"] = 20
	game._act()
	check(game.run.hp == 20 and not game.hp_bar.is_glowing(), "Fully blocked incoming attacks do not signal lost health")
	check(game.enemy_bar.is_glowing(), "A protected player still highlights damage dealt to the enemy")
	await _wait_for_action()

	item = _encounter()
	game.run.enemy["armor"] = 999
	game.run.enemy["attacks"] = [0]
	game._act()
	check(game.run.enemy["hp"] == 100 and not game.enemy_bar.is_glowing(), "Fully absorbed outgoing attacks leave enemy health quiet")
	await _wait_for_action()

	item = _encounter()
	item["healing"] = 10
	game.run.enemy["regen"] = 20
	game._act()
	await _wait_for_response()
	check(game.run.hp > 20 and game.hp_bar.is_glowing(), "Healing in the same turn does not hide incoming damage feedback")
	check(game.run.enemy["hp"] == 100, "Enemy regeneration resolves during its response")
	game.front.settings["flash"] = false
	game._settings_changed()
	check(not game.hp_bar.is_glowing() and not game.enemy_bar.is_glowing(), "Disabling Combat flash cancels active health feedback")
	await _wait_for_action()

	item = _encounter()
	game.front.settings["flash"] = false
	game._act()
	await _wait_for_response()
	check(game.run.hp < 20 and game.run.enemy["hp"] < 100, "Flash-off still resolves damage")
	check(not game.hp_bar.is_glowing() and not game.enemy_bar.is_glowing(), "Combat flash preference disables both health highlights")
	await _wait_for_action()

	item = _encounter()
	item["damage"] = 0
	game.run.enemy["attacks"] = [0]
	game.run.enemy_poison = 4
	game.run.player_poison = 2
	game._act()
	check(game.hp_bar.is_glowing() and game.enemy_bar.is_glowing(), "Damage over time also highlights the health it removes")
	await _wait_for_action()
	game.show_menu()
	check(not game.hp_bar.is_glowing() and not game.enemy_bar.is_glowing(), "Leaving combat clears hidden health feedback")

	item = _encounter()
	game.run.enemy["hp"] = 1
	game._act()
	check(game.enemy_bar.value == 0 and game.enemy_bar.is_glowing(), "The killing blow highlights the empty enemy bar")
	await _wait_for_action()
	game._open_reward(true)
	game._choose(0)
	check(not game.enemy_bar.is_glowing() and not game.hp_bar.is_glowing(), "The next encounter inherits no previous damage highlight")
	game.hp_bar.flash_glow()
	game.enemy_bar.flash_glow()
	game.start_run("warrior", 42)
	check(not game.hp_bar.is_glowing() and not game.enemy_bar.is_glowing(), "A new run resets transient feedback")
	# Let the audio mixer release playback handles before the process exits.
	game.front.audio.next_track_timer.stop()
	if game.front.audio.transition and game.front.audio.transition.is_valid():
		game.front.audio.transition.kill()
	for player: Node in game.find_children("*", "AudioStreamPlayer", true, false):
		player.stream_paused = false
		player.stop()
	await create_timer(0.1).timeout
	view.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	report("STAT BAR GLOW RESULT")
	quit(1 if failures else 0)

func _wait_for_response() -> void:
	while not game.run.pending_turn.is_empty():
		await process_frame

func _wait_for_action() -> void:
	if game.playback.active and game.run.phase == PackRun.Phase.FIGHT:
		await _wait_for_response()
		if game.run.combat_state == PackRun.CombatState.FINISHED:
			while game.busy:
				await process_frame
			return
		game.playback.cancel()
		await create_timer(0.22).timeout
		game.busy = false
		game._refresh()
	else:
		while game.busy:
			await process_frame


func _encounter() -> Dictionary:
	game.start_run("warrior", 42)
	game._open_reward(true)
	game._choose(0)
	game.front.settings["flash"] = true
	game.run.relics.clear()
	game.run.items.clear()
	game.run.hp = 20
	game.run.enemy["hp"] = 100
	game.run.enemy["max_hp"] = 100
	game.run.enemy["attacks"] = [3]
	game.run.enemy["hits"] = 1
	for stat: String in ["armor", "opening_armor", "cycle_armor", "parry", "regen", "drain", "pierce", "reflect", "poison", "sunder"]:
		game.run.enemy[stat] = 0
	var item: Dictionary = game.run.add_item("rusty_knife")
	game.run.auto_place(item)
	for stat: String in PackCatalog.STATS:
		item[stat] = 0
	item["damage"] = 8
	game._refresh()
	return item


func _snapshot(file_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png(preload("res://tests/support/artifact_paths.gd").path("%s.png") % file_name)
