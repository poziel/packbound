extends "res://tests/support/test_case.gd"

# Deterministic packing bot: uses only earned items and offered rewards.
# It samples legal arrangements, never alters HP, enemies or combat stats.
var packing_rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _initialize() -> void:
	if not require_isolation():
		return
	call_deferred("_run")

const RUN_SEED: int = 42
const PACKING_SEED: int = 1234
const MAX_STEPS: int = PackRun.FLOORS * 50
const MAX_FIGHT_TURNS: int = 35
const SAVES = preload("res://systems/runs/run_saves.gd")

func _run() -> void:
	for character in ["warrior", "ranger", "mage"]:
		var state := PackRun.new()
		state.reset(RUN_SEED, character)
		packing_rng.seed = PACKING_SEED
		var round_trip: PackRun = clone(state)
		check_equal(SAVES.new().capture(round_trip, 0.0), SAVES.new().capture(state, 0.0), "Full fixture clone preserves state and RNG for " + character)
		var steps: int = 0
		var floor_turns: Array[int] = []
		var rewards: Array[String] = []
		while state.phase not in [PackRun.Phase.VICTORY, PackRun.Phase.DEFEAT] and steps < MAX_STEPS:
			steps += 1
			var before := [state.phase, state.floor_index, state.turn, state.total_turns, state.hp, state.items.size(), state.item_rewards.size(), state.relic_rewards.size(), state.room_reward_pending]
			while not state.relic_rewards.is_empty() and not state.relic_offers.is_empty():
				var relic_count: int = state.relic_rewards.size()
				bind_relic(state)
				if state.relic_rewards.size() == relic_count:
					check(false, "Offered relic must be claimable")
					break
			while not state.offers.is_empty():
				# No next enemy exists yet while claiming rewards. Compare the actual
				# offered items rather than simulating the already defeated enemy.
				var pick: String = state.offers[0]
				var best: float = -INF
				for key: String in state.offers:
					var score: float = value(PackCatalog.item(key), state)
					if score > best:
						best = score
						pick = key
				rewards.append(pick)
				var count: int = state.item_rewards.size()
				state.choose_loot(pick)
				if state.item_rewards.size() == count:
					check(false, "Offered reward must be claimable: " + pick)
					break
			match state.phase:
				PackRun.Phase.FIGHT:
					if state.turn == 1:
						optimize(state, 28)
					state.end_turn()
					if state.phase == PackRun.Phase.LOOT:
						floor_turns.append(state.turn - 1)
					if state.turn > MAX_FIGHT_TURNS:
						check(false, "Fight turn budget exceeded for " + character)
						break
				PackRun.Phase.LOOT, PackRun.Phase.ROOM_COMPLETE:
					check(state.enter_selector(), "Completed floor permits travel")
				PackRun.Phase.SELECTOR:
					var door: Dictionary = state.door_choices[0] if not state.door_choices.is_empty() else {}
					for kind: String in (["rest", "relic", "combat", "encounter"] if state.hp < state.max_hp else ["relic", "combat", "encounter", "rest"]):
						var found: bool = false
						for candidate: Dictionary in state.door_choices:
							if candidate.kind == kind:
								door = candidate
								found = true
								break
						if found:
							break
					check(not door.is_empty() and state.choose_destination(str(door.get("id", ""))), "Offered destination is reachable")
				PackRun.Phase.ROOM:
					var action: String = "leave"
					if state.room_reward_pending and not state.room_relic_offers.is_empty():
						action = "relic:" + state.room_relic_offers[0]
					elif state.room_kind == "rest" and state.hp < state.max_hp:
						action = "rest"
					elif state.room_kind == "encounter" and state.room_event == "interrogation":
						action = "answer"
					check(state.resolve_room(action), "Room action is legal: " + action)
				PackRun.Phase.RELIC:
					check(false, "Current run unexpectedly uses obsolete RELIC phase")
			var after := [state.phase, state.floor_index, state.turn, state.total_turns, state.hp, state.items.size(), state.item_rewards.size(), state.relic_rewards.size(), state.room_reward_pending]
			if before == after:
				check(false, "Bot must progress: character=%s phase=%s floor=%d" % [character, state.phase, state.display_floor()])
				break
		check(steps < MAX_STEPS, "Run stays within explicit progress budget for " + character)
		check_equal(state.phase, PackRun.Phase.VICTORY, "Earned-reward packing bot wins seed %d for %s (floor=%d hp=%d turns=%d)" % [RUN_SEED, character, state.display_floor(), state.hp, state.total_turns])
		print("BALANCE %s: phase=%d floor=%d HP=%d/%d turns=%d steps=%d seeds=%d/%d" % [character, state.phase, state.display_floor(), state.hp, state.max_hp, state.total_turns, steps, RUN_SEED, PACKING_SEED])
		print("Turns per combat: %s; rewards: %s; relics: %s" % [floor_turns, rewards, state.relics])
	report("BALANCE RESULT")
	quit(1 if failures else 0)

func clone(source: PackRun) -> PackRun:
	var target := PackRun.new()
	var saves := SAVES.new()
	saves.restore(target, saves.capture(source, 0.0))
	return target

func bind_relic(state: PackRun) -> void:
	var priority: Array[String] = ["mana_furnace", "returning_guard", "diagonal_thread", "plague_seal", "echo_clock", "blood_pact", "last_thread", "folded_space", "arcane_barter"]
	for key in priority:
		if state.relic_offers.has(key):
			state.choose_relic(key)
			return
	if not state.relic_offers.is_empty():
		state.choose_relic(state.relic_offers[0])

func value(item: Dictionary, state: PackRun) -> float:
	var score: float = float(item["damage"]) + float(item["block"]) * 1.2 + float(item["healing"]) * 2.5 + float(item["vampirism"]) * 2.5 + float(item["poison"]) * 3 + float(item["burn"]) * 3 + float(item["plating"]) * 3 + float(item["slow"]) * 3 + float(item["thorns"]) * 2 + float(item["ward"]) + float(item["cleanse"])
	score += float(item["mana"]) * (3.0 if state.class_key == "mage" or state.relics.has("mana_furnace") else 0.5)
	if preload("res://systems/content/collectible_categories.gd").matches(item, &"boosters"):
		score += 7
	return maxf(1.0, score) / float(item["mask"].size())

func optimize(state: PackRun, attempts: int) -> float:
	var best: Array[Dictionary] = state.items.duplicate(true)
	var best_score: float = fight_score(state)
	for attempt in range(attempts):
		var order: Array[Dictionary] = []
		for item in state.items:
			item["cell"] = null
			order.append({"item": item, "priority": value(item, state) * packing_rng.randf_range(0.45, 1.6)})
		order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["priority"] > b["priority"])
		for entry in order:
			var item: Dictionary = entry["item"]
			var capacity: int = PackRun.GRID.x * PackRun.GRID.y
			var start_cell: int = packing_rng.randi_range(0, capacity - 1)
			var start_rotation: int = packing_rng.randi_range(0, 3)
			var placed: bool = false
			for offset in range(capacity):
				var index: int = (start_cell + offset) % capacity
				var point: Vector2i = Vector2i(index % PackRun.GRID.x, floori(float(index) / PackRun.GRID.x))
				for quarter in range(4):
					var rotation: int = (start_rotation + quarter) % 4
					if state.can_place(item, point, rotation):
						item["cell"] = point
						item["rotation"] = rotation
						item["shape"] = PackRun.dimensions(item)
						placed = true
						break
				if placed:
					break
		var score: float = fight_score(state)
		if score > best_score:
			best = state.items.duplicate(true)
			best_score = score
	state.items = best
	for item in state.items:
		if item["cell"] != null and not state.can_place(item, item["cell"]):
			check(false, "Invalid bot placement")
	return best_score

func fight_score(source: PackRun) -> float:
	var trial: PackRun = clone(source)
	trial.phase = PackRun.Phase.FIGHT
	for index in range(30):
		trial.end_turn()
		if trial.phase == PackRun.Phase.LOOT:
			return 1000.0 + trial.hp * 2.0 - (index + 1) * 1.2
		if trial.phase == PackRun.Phase.DEFEAT:
			return -float(trial.enemy["hp"]) - 100.0
	return -200.0 - float(trial.enemy["hp"])
