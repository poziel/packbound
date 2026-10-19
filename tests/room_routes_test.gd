extends "res://tests/prototype_test.gd"

func _run() -> void:
	var state: PackRun = fixture()
	check(state.has_method("enter_selector"), "Run supports a selector corridor")
	if not state.has_method("enter_selector"):
		print("ROOM ROUTES: %d checks, %d failures" % [checks, failures])
		quit(1)
		return
	var sizes: Dictionary = {}
	for seed_value in range(120):
		state.reset(seed_value)
		state.hp = 10
		state.phase = PackRun.Phase.LOOT
		state.combat_state = PackRun.CombatState.FINISHED
		check(state.enter_selector(), "Completed fight enters selector")
		check(state.display_floor() == 1, "Selector does not consume a floor")
		sizes[state.door_choices.size()] = true
		var kinds: Array[String] = []
		for door: Dictionary in state.door_choices:
			check(door.keys().size() == 2 and door.has("id") and door.has("kind"), "Door does not reveal its contents")
			check(not kinds.has(door.kind), "Choices have distinct types")
			kinds.append(door.kind)
		check(kinds.has("combat"), "Ordinary selector offers combat")
		var id: String = state.door_choices[0].id
		check(state.choose_destination(id), "Door commits destination")
		check(state.display_floor() == 2 and state.fight == 1, "Door advances depth once")
		check(not state.choose_destination(id) and state.display_floor() == 2, "Double click cannot advance twice")
	check(sizes.has(2) and sizes.has(3) and sizes.has(4), "Generation includes two, three and four doors")
	state.phase = PackRun.Phase.LOOT
	state.noncombat_streak = 2
	state.enter_selector()
	check(state.door_choices.size() == 1 and state.door_choices[0].kind == "combat", "Two noncombat floors require a real combat exit")
	state.choose_destination(state.door_choices[0].id)
	check(state.has_combat_room() and state.phase == PackRun.Phase.FIGHT, "Combat destination prepares one fight")
	state.fight = 18
	state.floor_index = 18
	state.phase = PackRun.Phase.LOOT
	state.enter_selector()
	check(state.door_choices.size() == 1, "Boss floor has one compulsory destination")
	state.choose_destination(state.door_choices[0].id)
	check(state.fight == 19 and state.enemy.key == PackCatalog.enemies()[19].key, "Final floor uses the boss")
	state.phase = PackRun.Phase.LOOT
	state.enter_selector()
	check(state.phase == PackRun.Phase.VICTORY, "Boss completion wins without another floor")
	print("ROOM ROUTES: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
