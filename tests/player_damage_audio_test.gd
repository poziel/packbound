extends "res://tests/prototype_test.gd"

func _run() -> void:
	for guard: int in [0, 3, 5, 8]:
		var state: PackRun = fixture("ranger")
		state.items.clear()
		state.enemy["attacks"] = [5]
		state.enemy["hits"] = 1
		state.block = guard
		var stats: Dictionary = state.effects()
		stats["block"] = guard
		var result: Dictionary = state.outcome(stats)
		check(result["player_shield_broken"] == (guard > 0 and guard <= 5), "Break detected at shield depletion: %d" % guard)
		check(result["player_hit_unshielded"] == (guard <= 5), "Unshielded sound includes exact break: %d" % guard)
		check(result["player_hit_shielded"] == (guard > 5), "Shield hit only while shield remains: %d" % guard)
	print("PLAYER DAMAGE AUDIO: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
