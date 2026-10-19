extends RefCounted
## Validated mutations of an active run. Presentation and persistence belong to the host.
const EXPANSION = preload("res://systems/enemies/enemy_expansion.gd")
const PLAYER_STATS: Array[String] = ["hp", "max_hp", "mana", "stamina", "block", "momentum", "undead_companions", "volley_remaining"]
const ENEMY_STATS: Array[String] = ["hp", "enemy_poison", "enemy_burn", "enemy_slow", "enemy_spark", "enemy_doom", "enemy_doom_turns"]
const REPLACEMENTS: Array[String] = ["prepare_enemy", "restart_encounter", "defeat_enemy", "travel", "entrance"]

func catalog(kind: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if kind == "enemies":
		var seen: Dictionary = {}
		for enemy: Dictionary in PackRun.enemies() + EXPANSION.profiles():
			if not seen.has(enemy.key):
				entries.append(enemy.duplicate(true))
				seen[enemy.key] = true
	else:
		var keys: Array = PackCatalog.RELICS if kind == "relics" else PackCatalog.ROSTER
		for key: String in keys:
			var entry: Dictionary = PackCatalog.relic(key) if kind == "relics" else PackCatalog.item(key)
			entry = entry.duplicate(true)
			entry["key"] = key
			entries.append(entry)
		if kind == "items":
			for key: String in PackRun.QUIVER.OPTIONS:
				var entry: Dictionary = PackRun.QUIVER.OPTIONS[key].duplicate(true)
				entry["key"] = key
				entries.append(entry)
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.name).naturalnocasecmp_to(str(b.name)) < 0)
	return entries

func validate(run: PackRun, command: String, args: Dictionary = {}) -> String:
	var key: String = str(args.get("key", ""))
	if run.phase == PackRun.Phase.DEFEAT and command in ["grant_item", "remove_item", "add_relic", "remove_relic", "quiver_upgrade"]:
		return "Restore health and restart or leave the defeated encounter before editing equipment."
	match command:
		"grant_item":
			if not PackCatalog.ROSTER.has(key) or PackRun.QUIVER.OPTIONS.has(key): return "Choose an ordinary catalog item."
			var quantity: int = int(args.get("quantity", 1))
			if quantity < 1 or quantity > 100: return "Quantity must be between 1 and 100."
			if not run.item_enabled(PackCatalog.item(key)): return "This item is unavailable for this class."
			if key == PackRun.QUIVER.KEY and (run.class_key != "ranger" or not run.quiver().is_empty() or quantity != 1): return "Only one permanent Bowmaster quiver is allowed."
		"remove_item":
			var item: Dictionary = _item(run, int(args.get("id", -1)))
			if item.is_empty(): return "Choose an inventory item."
			if run.is_permanent(item): return "Permanent class equipment cannot be removed."
		"add_relic", "remove_relic":
			if not PackCatalog.RELICS.has(key): return "Choose a catalog relic."
			if command == "add_relic" and run.relics.has(key): return "This relic is already owned."
			if command == "add_relic" and not run.item_enabled(PackCatalog.relic(key)): return "This relic is unavailable for this class."
			if command == "remove_relic" and not run.relics.has(key): return "This relic is not owned."
		"quiver_upgrade":
			if run.class_key != "ranger" or run.quiver().is_empty(): return "A Bowmaster quiver is required."
			if not PackRun.QUIVER.OPTIONS.has(key): return "Choose a quiver option."
			if PackRun.QUIVER.INITIAL.has(key):
				if not run.needs_arrows(): return "Starting arrows have already been chosen."
			elif not PackRun.QUIVER.available(run.quiver()).has(key): return "This upgrade is capped."
		"set_player", "set_enemy":
			var stat: String = str(args.get("stat", ""))
			var value: int = int(args.get("value", -1))
			if not (PLAYER_STATS if command == "set_player" else ENEMY_STATS).has(stat): return "Unknown editable stat."
			if value < 0 or value > 1000000: return "Value must be between 0 and 1,000,000."
			if command == "set_player":
				if stat == "max_hp" and value < 1: return "Maximum health must be positive."
				if stat == "hp" and (value < 1 or value > run.max_hp): return "Health must be between 1 and maximum health; use combat to test defeat."
				if stat == "undead_companions" and (run.class_key != "necromancer" or value > PackRun.NECROMANCER_COMPANION_CAP): return "Necromancer companions must be between 0 and 3."
				if stat == "momentum" and run.class_key != "warrior": return "Momentum is a Warmonger resource."
				if stat == "volley_remaining" and (run.class_key != "ranger" or value < 1 or value > 3): return "Volley countdown must be between 1 and 3 for a Bowmaster."
			elif run.phase != PackRun.Phase.FIGHT: return "Enemy edits require an active encounter."
			elif stat == "hp" and value > int(run.enemy.max_hp): return "Enemy health exceeds maximum health."
		"prepare_enemy":
			if _enemy(key).is_empty(): return "Choose an enemy from the roster."
		"restart_encounter", "defeat_enemy":
			if not run.has_combat_room() or (command == "defeat_enemy" and run.phase != PackRun.Phase.FIGHT): return "There is no active enemy to defeat."
			if run.hp <= 0: return "Restore health before restarting the encounter."
		"travel":
			var floor_number: int = int(args.get("floor", 0))
			var kind: String = str(args.get("kind", ""))
			if floor_number < 1 or floor_number > PackRun.FLOORS: return "Floor must be between 1 and 20."
			if kind not in ["combat", "rest", "relic", "encounter", "selector"]: return "Unknown room type."
			if kind == "selector" and floor_number == PackRun.FLOORS: return "The final floor has no next-floor selector."
		"restore_health", "refill_resources", "clear_player_conditions", "clear_resource_budgets", "entrance": pass
		_: return "Unknown developer command."
	return ""

func apply(run: PackRun, command: String, args: Dictionary = {}) -> Dictionary:
	var error: String = validate(run, command, args)
	if not error.is_empty(): return _result(false, error)
	if not run.pending_turn.is_empty(): return _result(false, "Finish the pending exchange first.")
	if run.combat_state == PackRun.CombatState.RUNNING: return _result(false, "Pause combat at a round boundary first.")
	var old_state: int = run.combat_state
	# Use the normal inventory authorities at this deliberately paused boundary.
	run.combat_state = PackRun.CombatState.PREPARING
	var key: String = str(args.get("key", ""))
	var world_changed: bool = command in ["prepare_enemy", "restart_encounter", "travel", "entrance"]
	var rewards: Dictionary = {}
	if world_changed:
		for property: String in ["offers", "relic_offers", "item_rewards", "relic_rewards", "relic_floors_claimed"]:
			rewards[property] = run.get(property).duplicate(true)
		run.pending_turn.clear()
		run.crafting_events.clear()
		# Destination state must never retain status fields from an abandoned fight.
		for property: String in ["player_poison", "enemy_poison", "enemy_burn", "enemy_slow", "enemy_spark", "enemy_doom", "enemy_doom_turns", "enemy_shield_spent"]:
			run.set(property, 0)
		run.elemental_traces.clear()
		run.room_resolved = false
		run.room_reward_pending = false
		run.room_relic_offers.clear()
		run.room_event = ""
		run.door_choices.clear()
	match command:
		"grant_item":
			for index in range(int(args.get("quantity", 1))):
				var item: Dictionary = run.add_item(key)
				if args.get("auto_place", false): run.auto_place(item)
		"remove_item": run.items.erase(_item(run, int(args.id)))
		"add_relic": run.relics.append(key)
		"remove_relic": run.relics.erase(key)
		"quiver_upgrade":
			if PackRun.QUIVER.INITIAL.has(key) and not run.item_rewards.is_empty() and run.offers.has(key):
				run.choose_loot(key)
			else:
				run.apply_quiver_option(key)
		"set_player":
			var stat: String = str(args.stat)
			var value: int = int(args.value)
			run.set(stat, value)
			if stat == "max_hp": run.hp = mini(run.hp, value)
			if stat in ["mana", "stamina", "block"]:
				run.resource_overrides[stat] = value
				run.set(stat + "_capacity", value)
			if stat == "block": run.block_capacity = maxi(run.block_capacity, value)
		"restore_health": run.hp = run.max_hp
		"refill_resources": run._refill_round_resources()
		"clear_resource_budgets":
			run.resource_overrides.clear()
			run._refill_round_resources()
		"clear_player_conditions": run.player_poison = 0
		"set_enemy":
			if str(args.stat) == "hp":
				run.enemy.hp = int(args.value)
				if int(args.value) == 0: run.finish_defeated_enemy()
			else: run.set(str(args.stat), int(args.value))
		"prepare_enemy":
			run.room_kind = "combat"
			run.room_resolved = false
			run.prepare_enemy(_enemy(key))
		"restart_encounter":
			run.room_kind = "combat"
			var enemy: Dictionary = run.enemy.duplicate(true)
			enemy.hp = int(enemy.max_hp)
			run.prepare_enemy(enemy)
		"defeat_enemy":
			run.enemy.hp = 0
			run.finish_defeated_enemy()
		"entrance":
			run.enter_room(run.floor_index, "combat")
		"travel":
			var kind: String = str(args.kind)
			if kind == "selector":
				run.floor_index = int(args.floor) - 1
				run.fight = run.floor_index
				run.room_kind = "combat"
				run.phase = PackRun.Phase.ROOM_COMPLETE
				run.room_reward_pending = false
				run.room_relic_offers.clear()
				run.room_event = ""
				run.enter_selector()
			else: run.enter_room(int(args.floor) - 1, kind)
	for property: String in rewards:
		run.set(property, rewards[property])
	if not world_changed and command != "defeat_enemy" and run.phase == PackRun.Phase.FIGHT:
		run.combat_state = old_state
	elif not world_changed and run.phase != PackRun.Phase.FIGHT:
		run.combat_state = PackRun.CombatState.FINISHED
	run.log_line("[DEV] %s %s" % [command.replace("_", " "), str(args)])
	return _result(true, command.replace("_", " ").capitalize() + " applied.", world_changed)

func _enemy(key: String) -> Dictionary:
	for enemy: Dictionary in catalog("enemies"):
		if str(enemy.key) == key: return enemy
	return {}

func _item(run: PackRun, id: int) -> Dictionary:
	for item: Dictionary in run.items:
		if int(item.id) == id: return item
	return {}

func _result(ok: bool, message: String, world_changed: bool = false) -> Dictionary:
	return {"ok": ok, "message": message, "world_changed": world_changed}
