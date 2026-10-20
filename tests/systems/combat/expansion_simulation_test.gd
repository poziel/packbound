extends "res://tests/support/test_case.gd"

const ITEMS = preload("res://systems/items/expansion_items.gd")
const RELICS = preload("res://systems/relics/expansion_relics.gd")
var saves := PackRunSaves.new()

func fixture(character: String) -> PackRun:
	var run := PackRun.new()
	run.reset(61019, character)
	run.items.clear()
	run.relics.clear()
	if character == "ranger":
		var quiver: Dictionary = run.add_item("magnificent_quiver", Vector2i.ZERO)
		quiver["arrow_type"] = "broadhead"
	run.enemy["hp"] = 10000
	run.enemy["max_hp"] = 10000
	run.enemy["attacks"] = [1, 2]
	return run

func verify_preview(run: PackRun, label: String) -> void:
	var before: Dictionary = saves.capture(run, 0.0)
	var stats: Dictionary = run.effects()
	check(stats == run.effects(), label + " deterministic repeated effects")
	var outcome: Dictionary = run.outcome(stats)
	check(outcome == run.outcome(stats), label + " deterministic repeated outcomes")
	check(before == saves.capture(run, 0.0), label + " previews preserve all captured state and RNG")
	check(int(stats[GameplayTypes.Stat.DAMAGE]) == int(stats["physical_damage"]) + int(stats["magical_damage"]), label + " typed damage total")
	for key: String in ["mana_after", "stamina_after"]:
		check(int(stats.get(key, 0)) >= 0, label + " nonnegative " + key)
	var restored := PackRun.new()
	saves.restore(restored, before)
	check(restored.effects() == stats, label + " save restores preview")

func verify_commit(run: PackRun, label: String) -> void:
	if not run.start_combat():
		check(false, label + " combat starts")
		return
	run.begin_turn()
	var snapshot: Dictionary = saves.capture(run, 0.0)
	var restored := PackRun.new()
	saves.restore(restored, snapshot)
	check(restored.begin_turn().is_empty(), label + " saved committed player action cannot repeat")
	run.complete_turn()
	restored.complete_turn()
	check(saves.capture(run, 0.0) == saves.capture(restored, 0.0), label + " resumed monster checkpoint matches uninterrupted turn")
	check(run.mana >= 0 and run.stamina >= 0 and run.momentum >= 0, label + " committed resources do not underflow")

func natural_progression(character: String) -> void:
	var run := PackRun.new()
	run.reset(61019, character)
	if run.needs_arrows():
		run.choose_loot("arrow_broadhead")
	# Seed three compatible expansion items and one relic, then use only actual
	# rewards and legal route choices; no HP/stat edits or defeat recovery.
	var candidates: Array[String] = []
	for key: String in ITEMS.ITEM_KEYS:
		var allowed: Array = ITEMS.items()[key].get("classes", [])
		if allowed.is_empty() or character in allowed:
			candidates.append(key)
	for index: int in range(3):
		run.auto_place(run.add_item(candidates[run.rng.randi_range(0, candidates.size() - 1)]))
	run.relics.assign([RELICS.RELIC_KEYS[run.rng.randi_range(0, RELICS.RELIC_KEYS.size() - 1)]])
	var iterations: int = 0
	while run.phase not in [PackRun.Phase.VICTORY, PackRun.Phase.DEFEAT] and iterations < 2000:
		iterations += 1
		while not run.relic_rewards.is_empty():
			run.choose_relic(run.relic_offers[0])
		while not run.offers.is_empty():
			run.choose_loot(run.offers[0])
		match run.phase:
			PackRun.Phase.FIGHT:
				run.end_turn()
				check(run.mana >= 0 and run.stamina >= 0 and run.momentum >= 0, character + " natural resources nonnegative")
			PackRun.Phase.LOOT, PackRun.Phase.ROOM_COMPLETE:
				run.enter_selector()
			PackRun.Phase.SELECTOR:
				run.choose_destination(str(run.door_choices[0]["id"]))
			PackRun.Phase.ROOM:
				if run.room_reward_pending and not run.room_relic_offers.is_empty():
					run.resolve_room("relic:" + run.room_relic_offers[0])
				elif run.room_kind == "rest" and run.hp < run.max_hp:
					run.resolve_room("rest")
				elif run.room_kind == "encounter" and run.room_event == "interrogation":
					run.resolve_room("answer")
				else:
					run.resolve_room("leave")
	check(iterations < 2000, character + " natural run terminates")
	print("EXPANSION NATURAL %s: %s, floor %d/20, HP %d/%d, %d combat turns" % [character, "VICTORY" if run.phase == PackRun.Phase.VICTORY else "DEFEAT", run.display_floor(), run.hp, run.max_hp, run.total_turns])

func _initialize() -> void:
	if not require_isolation():
		return
	for key: String in ITEMS.ITEM_KEYS:
		var definition: Dictionary = ITEMS.items()[key]
		var classes: Array = definition.get("classes", [])
		var character: String = str(classes[0]) if not classes.is_empty() else "warrior"
		var run: PackRun = fixture(character)
		var item: Dictionary = run.add_item(key)
		check(run.auto_place(item), key + " can occupy legal grid")
		run.momentum = 8 if character == "warrior" else 0
		verify_preview(run, key)
		verify_commit(run, key)
	for key: String in RELICS.RELIC_KEYS:
		for character: String in ["warrior", "ranger", "mage", "assassin", "necromancer"]:
			var run: PackRun = fixture(character)
			var weapon: Dictionary = run.add_item("rusty_knife")
			run.auto_place(weapon)
			run.relics.assign([key])
			run.momentum = 8 if character == "warrior" else 0
			run.hp = 8
			run.enemy_burn = 2
			run.enemy_poison = 2
			run.enemy_slow = 2
			verify_preview(run, key + "/" + character)
			verify_commit(run, key + "/" + character)
	# Full-depth engine smoke: seeded loadouts, normal enemy definitions, sustained
	# HP for coverage. This deliberately measures engine invariants, not balance.
	for character: String in ["warrior", "ranger", "mage", "assassin", "necromancer"]:
		var rng := RandomNumberGenerator.new()
		rng.seed = 61019
		var run: PackRun = fixture(character)
		for floor_number: int in range(20):
			run.floor_index = floor_number
			run.fight = floor_number
			run.hp = run.max_hp
			run.items = run.items.filter(func(item: Dictionary) -> bool: return run.is_permanent(item))
			for attempt: int in range(12):
				var key: String = ITEMS.ITEM_KEYS[rng.randi_range(0, ITEMS.ITEM_KEYS.size() - 1)]
				var allowed: Array = ITEMS.items()[key].get("classes", [])
				if allowed.is_empty() or character in allowed:
					run.auto_place(run.add_item(key))
			run.relics.assign([RELICS.RELIC_KEYS[rng.randi_range(0, RELICS.RELIC_KEYS.size() - 1)]])
			run.prepare_enemy(PackRun.enemies()[floor_number])
			verify_preview(run, "%s/floor%d" % [character, floor_number + 1])
			verify_commit(run, "%s/floor%d" % [character, floor_number + 1])
	for character: String in ["warrior", "ranger", "mage", "assassin", "necromancer"]:
		natural_progression(character)
	print("EXPANSION SIMULATION: %d checks, %d failures; 96 items, 250 relic/class cases, 100 floor checkpoints" % [checks, failures])
	report("expansion_simulation")
	quit(1 if failures else 0)
