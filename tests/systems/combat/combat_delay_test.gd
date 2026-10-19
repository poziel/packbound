extends "res://tests/support/prototype_support.gd"

func _run() -> void:
	var state: PackRun = fixture("warrior")
	state.items.clear()
	state.hp = 30
	state.enemy["hp"] = 1000
	state.enemy["max_hp"] = 1000
	state.enemy["attacks"] = [3]
	state.add_item("rusty_knife", Vector2i.ZERO)["damage"] = 8
	var playback := PackCombatPlayback.new()
	root.add_child(playback)
	playback.set_process(false)
	playback.start(state, 1.0, 0.3, 0.28)
	playback._process(1.5)
	check(state.total_turns == 1 and state.turn == 2, "Enemy responds once after the default wait")
	playback._process(1.0)
	check(state.total_turns == 1, "Player waits after enemy damage instead of counterattacking immediately")
	playback._process(0.5)
	check(state.total_turns == 2, "Player responds after the full default 1.5 seconds")
	playback.cancel()
	for example: Array in [[0.5, 0.2, 2.5, 5.0, 0.4], [2.5, 2.5, 0.2, 0.08, 1.0], [10.0, 1.5, 1.5, 0.15, 0.15]]:
		state = fixture("warrior")
		state.items.clear()
		state.hp = 30
		state.enemy["hp"] = 1000
		state.enemy["max_hp"] = 1000
		state.enemy["attacks"] = [3]
		state.add_item("rusty_knife", Vector2i.ZERO)["damage"] = 8
		playback.start(state, example[0], 0.3, 0.28, 0.42, example[1], example[2])
		check(is_equal_approx(playback.remaining_seconds, example[3]), "Enemy wait respects independent delay and fractional speed")
		playback.set_paused(true)
		playback._process(20.0)
		check(state.turn == 1 and is_equal_approx(playback.remaining_seconds, example[3]), "Pause freezes configured enemy wait")
		playback.set_paused(false)
		playback._process(example[3] - 0.001)
		check(state.turn == 1, "Enemy cannot respond early")
		playback._process(0.002)
		check(state.turn == 2 and is_equal_approx(playback.remaining_seconds, example[4]), "Player wait uses its own delay and speed")
		playback._process(example[4] - 0.001)
		check(state.total_turns == 1, "Player cannot respond early")
		playback.set_paused(true)
		playback._process(20.0)
		check(state.total_turns == 1, "Pause also freezes player wait")
		playback.set_paused(false)
		playback._process(0.002)
		check(state.total_turns == 2, "Configured player wait advances exactly one action")
		playback.cancel()
	state = fixture("warrior")
	state.items.clear()
	state.enemy["hp"] = 1
	state.add_item("rusty_knife", Vector2i.ZERO)["damage"] = 8
	playback.start(state, 1.0, 0.3, 0.28, 0.42, 2.5, 2.5)
	check(is_equal_approx(playback.remaining_seconds, 0.72), "Lethal player hit only waits for impact and death, not response delays")
	playback._process(0.73)
	playback._process(0.01)
	check(not playback.active, "Lethal hit finishes without another attack")
	playback.queue_free()
	await process_frame
	report("COMBAT DELAY RESULT")
	quit(1 if failures else 0)
