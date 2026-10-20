extends "res://tests/support/test_case.gd"



func fixture() -> PackRun:
	var state: PackRun = PackRun.new()
	state.reset(42, "assassin")
	state.choose_relic(state.relic_offers[0])
	state.relics.clear()
	state.enemy["hp"] = 200
	state.enemy["max_hp"] = 200
	state.enemy["attacks"] = [7]
	state.enemy["hits"] = 3
	state.enemy[GameplayTypes.Stat.POISON] = 4
	state.enemy["drain"] = 6
	state.enemy[GameplayTypes.Stat.PIERCE] = 2
	return state

func _initialize() -> void:
	if not require_isolation():
		return
	call_deferred("_run")

func _run() -> void:
	var state: PackRun = fixture()
	check(state.max_hp == 30, "Assassin has30 HP")
	for item in state.items:
		check(state.can_place(item, item["cell"]), "Assassin starter layout is nonoverlapping")
	for current in range(1, 11):
		state.turn = current
		var expected: bool = current in [1, 4, 7, 10]
		check(state.is_invisible() == expected, "Shadowstep cadence turn%d" % current)
		var before_hp: int = state.hp
		var before_enemy: int = state.enemy["hp"]
		var before_poison: int = state.player_poison
		var before_mana: int = state.mana
		var result: Dictionary = state.outcome(state.effects())
		check(state.hp == before_hp and state.enemy["hp"] == before_enemy and state.player_poison == before_poison and state.mana == before_mana and state.turn == current, "Preview is pure on turn%d" % current)
		check(result["invisible"] == expected, "Preview reports visibility")
		if expected:
			check(result["taken"] == 0 and result["blocked"] == 0 and result["retaliation"] == 0, "Invisible skips all3 piercing hits and contact thorns")
			check(result["poison_after"] == 0, "Invisible prevents on-hit poison")
			check(result["enemy_hp_after"] == before_enemy - result["dealt"] - result["poison_tick"], "Invisible prevents drain")
		else:
			check(result["taken"] > 0 and result["retaliation"] == 3 and result["poison_after"] == 4, "Visible turns allow multihit, thorns and poison")
	state = fixture()
	state.enemy["regen"] = 5
	var prediction: Dictionary = state.outcome(state.effects())
	check(prediction["enemy_hp_after"] == 200 - prediction["dealt"] - prediction["poison_tick"] + 5, "Regeneration remains active while player invisible")
	var actual: Dictionary = state.end_turn()
	check(actual == prediction and state.hp == prediction["hp_after"] and state.enemy["hp"] == prediction["enemy_hp_after"], "Committed invisible turn exactly matches pure preview")
	check(state.turn == 2 and not state.is_invisible(), "End turn leaves invisibility")
	check(state.block == 4, "Invisible first round retains the full starting shield")
	state = fixture()
	state.player_poison = 3
	state.enemy["reflect"] = 2
	state.add_item("cursed_idol", Vector2i(4, 0))
	prediction = state.outcome(state.effects())
	check(prediction["special_taken"] == 6 and prediction["hp_after"] == 24, "Existing poison3 reflection2 curse1 still damage invisible assassin")
	check(prediction["poison_after"] == 2, "Existing poison decays without adding on-hit stacks")
	state.add_item("warding_sigil", Vector2i(2, 1))
	prediction = state.outcome(state.effects())
	check(prediction["ward_absorbed"] == 4 and prediction["special_taken"] == 2, "Ward still absorbs special damage while invisible")
	state = fixture()
	state.items.clear()
	state.add_item("ember_tome", Vector2i(0, 0))
	state.relics.append("arcane_barter")
	state.hp = 2
	prediction = state.outcome(state.effects())
	check(prediction["blood_cost"] == 3 and prediction["hp_after"] == 0, "Blood costs can kill invisible assassin")
	state = fixture()
	state.enemy["hp"] = 1
	state.end_turn()
	check(state.phase == PackRun.Phase.LOOT and state.offers.size() == 3, "Assassin earns loot on kill")
	state.advance_encounter()
	state.choose_loot(state.offers[0])
	check(state.turn == 1 and state.is_invisible(), "New floor restarts Shadowstep")
	for key in ["warrior", "ranger", "mage", "necromancer"]:
		state.reset(42, key)
		check(not state.is_invisible(), "Other classes cannot become invisible: " + key)
	var game: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.front.show_classes()
	await process_frame
	await process_frame
	check(game.front.class_buttons.size() == 5, "Five classes are selectable")
	var previous: Rect2 = Rect2()
	for key in PackCatalog.classes():
		var button: Button = game.front.class_buttons[key]
		check(Rect2(0, 0, 1280, 800).encloses(button.get_rect()), "Class card stays in1280 canvas: " + key)
		check(not previous.intersects(button.get_rect()), "Class cards do not overlap: " + key)
		previous = button.get_rect()
		var labels: Array[Label] = []
		for child in button.get_children():
			if child is Label:
				check(Rect2(Vector2.ZERO, button.size).encloses(child.get_rect()), "Class copy stays in card: " + key)
				for other in labels:
					check(not child.get_rect().intersects(other.get_rect()), "Class labels do not overlap: " + key)
				labels.append(child)
			elif child is TextureRect:
				check(child.texture.get_size() == Vector2(192, 160), "Native character source192x160: " + key)
	game.queue_free()
	await process_frame
	report("ASSASSIN RESULT")
	quit(1 if failures else 0)
