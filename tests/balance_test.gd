extends SceneTree

# Deterministic packing bot: uses only earned items and offered rewards.
# It samples legal arrangements, never alters HP, enemies or combat stats.
var packing_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for character in ["warrior", "ranger", "mage"]:
		var state: PackRun = PackRun.new()
		state.reset(42, character)
		packing_rng.seed = 1234
		var floor_turns: Array[int] = []
		var rewards: Array[String] = []
		while state.phase not in [PackRun.Phase.VICTORY, PackRun.Phase.DEFEAT]:
			if not state.relic_rewards.is_empty():
				bind_relic(state)
			if state.phase == PackRun.Phase.FIGHT and state.turn == 1:
				optimize(state, 28)
			if state.phase == PackRun.Phase.FIGHT:
				state.end_turn()
				if state.turn > 35:
					printerr("STALL: " + character)
					failures += 1
					break
			if state.phase == PackRun.Phase.LOOT:
				floor_turns.append(state.turn - 1)
				state.advance_encounter()
				var pick: String = state.offers[0]
				var best_score: float = -INF
				for key in state.offers:
					var trial: PackRun = clone(state)
					trial.choose_loot(key)
					if not trial.relic_rewards.is_empty():
						bind_relic(trial)
					var score: float = optimize(trial, 16)
					if score > best_score:
						best_score = score
						pick = key
				rewards.append(pick)
				state.choose_loot(pick)
		var won: bool = state.phase == PackRun.Phase.VICTORY
		if not won:
			failures += 1
		print("BALANCE %s: %s, floor %d, HP %d/%d, turns %d" % [character, "VICTORY" if won else "DEFEAT", state.fight + 1, state.hp, state.max_hp, state.total_turns])
		print("Turns per floor: %s" % str(floor_turns))
		print("Rewards: %s" % str(rewards))
		print("Relics: %s" % str(state.relics))
	print("BALANCE RESULT: %d failed runs" % failures)
	quit(1 if failures else 0)

func clone(source: PackRun) -> PackRun:
	var target: PackRun = PackRun.new()
	for property in ["combat_state", "undead_companions", "class_key", "max_hp", "hp", "block", "carry_block", "mana", "player_poison", "enemy_poison", "enemy_burn", "enemy_shield_spent", "fight", "turn", "total_turns", "phase", "last_thread_used", "next_id"]:
		target.set(property, source.get(property))
	target.pending_turn = source.pending_turn.duplicate(true)
	target.items = source.items.duplicate(true)
	target.enemy = source.enemy.duplicate(true)
	target.offers = source.offers.duplicate()
	target.item_rewards = source.item_rewards.duplicate(true)
	target.relic_rewards = source.relic_rewards.duplicate()
	target.relics = source.relics.duplicate()
	target.relic_offers = source.relic_offers.duplicate()
	target.relic_floors_claimed = source.relic_floors_claimed.duplicate()
	target.rng.state = source.rng.state
	return target

func bind_relic(state: PackRun) -> void:
	var priority: Array[String] = ["mana_furnace", "returning_guard", "diagonal_thread", "plague_seal", "echo_clock", "blood_pact", "last_thread", "folded_space", "arcane_barter"]
	for key in priority:
		if state.relic_offers.has(key):
			state.choose_relic(key)
			return

func value(item: Dictionary, state: PackRun) -> float:
	var score: float = float(item["damage"]) + float(item["block"]) * 1.2 + float(item["healing"]) * 2.5 + float(item["vampirism"]) * 2.5 + float(item["poison"]) * 3 + float(item["burn"]) * 3 + float(item["plating"]) * 3 + float(item["slow"]) * 3 + float(item["thorns"]) * 2 + float(item["ward"]) + float(item["cleanse"])
	score += float(item["mana"]) * (3.0 if state.class_key == "mage" or state.relics.has("mana_furnace") else 0.5)
	if item["role"] == "booster":
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
			printerr("Invalid bot placement")
			failures += 1
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
