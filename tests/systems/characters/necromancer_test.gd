extends "res://tests/support/test_case.gd"



func fixture() -> PackRun:
	var state: PackRun = PackRun.new()
	state.reset(421, "necromancer")
	state.choose_relic(state.relic_offers[0])
	state.relics.clear()
	return state

func _initialize() -> void:
	if not require_isolation():
		return
	var state: PackRun = fixture()
	check(state.hp == 28 and state.undead_companions == 1, "Necromancer begins with 28 HP and one thrall")
	for item in state.items:
		check(state.can_place(item, item["cell"]), "Each starter fits without overlap")
	var stats: Dictionary = state.effects()
	check(stats["companion_damage"] == 2 and stats["damage"] == 7, "First turn damage includes fang plus one thrall; unfunded tome sleeps")
	state.items.clear()
	state.enemy["armor"] = 1
	var preview: Dictionary = state.outcome(state.effects())
	check(preview["dealt"] == 1, "Enemy armor applies to thrall damage")
	state.undead_companions = 3
	check(state.effects()["damage"] == 6, "Three thralls add six displayed direct damage")
	check(state.outcome(state.effects())["dealt"] == 5, "Combined thrall hit pays armor once")
	state = fixture()
	state.items.clear()
	state.enemy["hp"] = 1
	var before: Array[String] = state.history.duplicate()
	for attempt in range(3):
		preview = state.outcome(state.effects())
		check(preview["raised_companion"], "Preview predicts a raise on a surviving kill")
	check(state.undead_companions == 1 and state.enemy["hp"] == 1 and state.history == before, "Repeated previews mutate neither army, enemy nor log")
	var actual: Dictionary = state.end_turn()
	check(actual["dealt"] == preview["dealt"] and actual["hp_after"] == preview["hp_after"], "Committed turn matches combat preview")
	check(state.undead_companions == 2 and state.phase == PackRun.Phase.LOOT, "Surviving kill raises one companion and offers loot")
	check(state.history.any(func(line: String) -> bool: return line.contains("Raise Dead:")), "Raise is visible in combat history")
	check(state.end_turn().is_empty() and state.undead_companions == 2, "Repeated end turn cannot raise the same defeated foe")
	check(state.offers.size() == 3, "Necromancer has valid loot groups")
	state.advance_encounter()
	state.choose_loot(state.offers[0])
	check(state.fight == 1 and state.undead_companions == 2, "Army persists on the next floor")
	check(state.mana == 0 and state.block == 0, "New floor resources wait for the next fight start")
	state.enemy["hp"] = 1
	state.end_turn()
	check(state.undead_companions == 3, "Second kill reaches three companions")
	state.advance_encounter()
	state.choose_loot(state.offers[0])
	state.enemy["hp"] = 1
	actual = state.end_turn()
	check(not actual["raised_companion"] and state.undead_companions == 3, "Further kills obey army cap")
	state.reset(421, "necromancer")
	check(state.undead_companions == 1, "New necromancer run resets army to one")
	state.reset(421, "warrior")
	check(state.undead_companions == 0 and state.effects()["companion_damage"] == 0, "Changing class removes army bonus")
	# Every existing kill path reaches the same raise resolution.
	for source: String in ["poison", "burn", "thorns"]:
		state = fixture()
		state.items.clear()
		state.undead_companions = 0
		state.enemy["hp"] = 1
		if source == "poison":
			state.enemy_poison = 1
		elif source == "burn":
			state.enemy_burn = 1
		else:
			state.add_item("buckler", Vector2i.ZERO)
		actual = state.end_turn()
		check(actual["raised_companion"] and state.undead_companions == 1, "%s kill raises one companion" % source)
	state = fixture()
	state.items.clear()
	state.hp = 1
	state.player_poison = 1
	state.enemy["hp"] = 1
	actual = state.end_turn()
	check(state.phase == PackRun.Phase.DEFEAT and not actual["raised_companion"] and state.undead_companions == 1, "Simultaneous fatal special damage does not raise a companion")
	state = fixture()
	state.items.clear()
	state.hp = 1
	state.player_poison = 1
	state.enemy["hp"] = 1
	state.relics.append("last_thread")
	actual = state.end_turn()
	check(actual["revived"] and actual["raised_companion"] and state.undead_companions == 2, "Last Thread survival permits the killing blow's raise")
	state = fixture()
	state.items.clear()
	state.undead_companions = 0
	state.hp = 1
	actual = state.end_turn()
	check(state.phase == PackRun.Phase.DEFEAT and state.undead_companions == 0 and not actual["raised_companion"], "Death to a living monster never raises an ally")
	print("Necromancer checks: %d, failures: %d" % [checks, failures])
	report("necromancer")
	quit(0 if failures == 0 else 1)
