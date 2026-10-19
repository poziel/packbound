extends "res://tests/support/prototype_support.gd"

func _run() -> void:
	var saves := PackRunSaves.new()
	var original: PackRun = fixture()
	original.fight = 8
	original.hp = 17
	original.items[0].priority = 3
	var legacy: Dictionary = saves.capture(original, 90.0)
	for key: String in ["floor_index", "room_kind", "door_choices", "room_flow_version"]:
		legacy.state.erase(key)
	legacy.version = 1
	var restored: PackRun = fixture()
	saves.restore(restored, legacy)
	check(restored.display_floor() == 9 and restored.hp == 17, "Legacy depth and health survive migration")
	check(restored.items[0].priority == 3, "Legacy inventory preserved")
	for seed_value in range(20):
		original.reset(seed_value)
		original.hp = 12
		original.phase = PackRun.Phase.LOOT
		original.enter_selector()
		var snapshot: Dictionary = saves.capture(original, 12)
		saves.restore(restored, snapshot)
		check(restored.door_choices == original.door_choices and restored.rng.state == original.rng.state, "Selector reopening preserves choices and RNG")
		check(restored.phase == PackRun.Phase.SELECTOR and restored.display_floor() == 1, "Selector restores without consuming floor")
		var choice: String = original.door_choices.back().id
		original.choose_destination(choice)
		snapshot = saves.capture(original, 13)
		saves.restore(restored, snapshot)
		check(restored.room_kind == original.room_kind and restored.display_floor() == 2, "Committed destination restores once")
	original.phase = PackRun.Phase.SELECTOR
	original.door_choices = [{"id": "encounter", "kind": "encounter"}]
	original.choose_destination("encounter")
	original.room_event = "blood_offering"
	original.hp = original.max_hp
	original.resolve_room("offer")
	saves.restore(restored, saves.capture(original, 20))
	check(restored.hp == original.hp and restored.room_reward_pending, "Paid event reward survives reopening")
	check(not restored.resolve_room("offer"), "Reopening cannot charge or reroll blood reward")
	saves.directory = preload("res://tests/support/artifact_paths.gd").path("legacy_logs/room-save-tests")
	check(saves.write("room", saves.capture(original, 21)) and not saves.read("room").is_empty(), "Version two room saves round-trip through disk")
	check(saves.write("legacy", legacy) and not saves.read("legacy").is_empty(), "Version one saves remain readable")
	var invalid: Dictionary = saves.capture(original, 22)
	invalid.state.phase = PackRun.Phase.SELECTOR
	invalid.state.door_choices = [{"id": "arbitrary_scene", "kind": "rest"}]
	check(saves.write("invalid", invalid) and saves.read("invalid").is_empty(), "Invalid saved door IDs cannot load arbitrary destinations")
	report("ROOM SAVE")
	quit(1 if failures else 0)
