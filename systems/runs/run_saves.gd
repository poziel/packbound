class_name PackRunSaves
extends RefCounted

const VERSION: int = 3
var directory: String = "user://runs"
var last_error: Error = OK

## Old saves are the only input boundary accepting string gameplay values.
static func migrate_legacy_values(value: Variant, state_root: bool = false) -> void:
	if value is Array:
		for child: Variant in value: migrate_legacy_values(child)
	elif value is Dictionary:
		if value.get_typed_key_builtin() == TYPE_INT:
			for child: Variant in value.values(): migrate_legacy_values(child)
			return
		if not state_root:
			for key: Variant in value.keys():
				if key is String:
					var stat: int = GameplayTypes.stat_from_id(key)
					if stat != GameplayTypes.INVALID_VALUE:
						value[stat] = value[key]
						value.erase(key)
		if value.has("mask") and value.has("key"):
			var costs: Dictionary = value.get("activation_costs", {}).duplicate()
			var authored_costs: Dictionary = PackCatalog.item(str(value.key)).get("activation_costs", {})
			for pair: Array in [["cost", GameplayTypes.ResourceType.MANA], ["stamina_cost", GameplayTypes.ResourceType.STAMINA], ["health_cost", GameplayTypes.ResourceType.HEALTH], ["momentum_cost", GameplayTypes.ResourceType.MOMENTUM]]:
				costs[pair[1]] = int(value.get(pair[0], costs.get(pair[1], authored_costs.get(pair[1], 0))))
				value.erase(pair[0])
			value["activation_costs"] = costs
		for field: String in ["element", "damage_type"]:
			if value.get(field) is String or value.get(field) is StringName:
				value[field] = GameplayTypes.element_from_id(value[field]) if field == "element" else GameplayTypes.damage_type_from_id(value[field])
		for field: String in ["elemental_traces", "traces_after"]:
			if value.get(field) is Dictionary:
				var converted: Dictionary = {}
				for key: Variant in value[field]:
					converted[GameplayTypes.element_from_id(key) if key is String else key] = value[field][key]
				value[field] = converted
		if value.get("elemental_inputs") is Array:
			value.elemental_inputs = value.elemental_inputs.map(func(element): return GameplayTypes.element_from_id(element) if element is String else element)
		for key: Variant in value:
			if key is String and key in ["statuses", "statuses_after"]: continue
			migrate_legacy_values(value[key], key is String and key == "player_state")

func new_id() -> String:
	return "%d-%s" % [Time.get_unix_time_from_system() * 1000, Crypto.new().generate_random_bytes(8).hex_encode()]

func capture(run: PackRun, elapsed: float, playback: PackCombatPlayback = null) -> Dictionary:
	var state: Dictionary = {}
	for property: Dictionary in run.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE and property.name not in ["rng", "_statuses", "_poison_statuses"]:
			state[property.name] = run.get(property.name)
	state["statuses"] = run.status_state()
	state["rng_seed"] = run.rng.seed
	state["rng_state"] = run.rng.state
	return {"version": VERSION, "elapsed": elapsed, "state": state.duplicate(true), "playback": playback.snapshot() if playback != null else {}}

func restore(run: PackRun, data: Dictionary) -> void:
	var state: Dictionary = data["state"].duplicate(true)
	migrate_legacy_values(state, true)
	for property: Dictionary in run.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE and state.has(property.name) and property.name not in ["rng", "_statuses", "_poison_statuses"]:
			run.set(property.name, state[property.name])
	run.restore_status_state(state.get("statuses", {}), state.get("poison_statuses", {}))
	run.rng.seed = state["rng_seed"]
	run.rng.state = state["rng_state"]
	run.normalize_room_state(state)
	if not state.has("momentum"):
		run.momentum = 0
		run.momentum_gain_bonus = 0
		run.momentum_cost_reduction = 0
	if not state.has("volley_remaining"):
		_migrate_archer(run)
	for key: String in ["enemy_slow", "enemy_spark", "enemy_doom", "enemy_doom_turns"]:
		if not state.has(key):
			run.set(key, 0)
	if not state.has("elemental_traces"):
		run.elemental_traces = {}
	for key: int in [GameplayTypes.Stat.PHYSICAL_RESISTANCE, GameplayTypes.Stat.MAGICAL_RESISTANCE]:
		if not run.enemy.has(key):
			run.enemy[key] = 0
	# Fill only newly introduced fields; preserve saved rolls and existing art/layout.
	for item: Dictionary in run.items:
		var defaults: Dictionary = PackCatalog.item(item["key"])
		# Normalize legacy text rarity here; runtime consumers accept enums only.
		item["rarity"] = defaults["rarity"]
		if item["key"] == PackCatalog.QUIVER.KEY:
			item["name"] = defaults["name"]
		var migration_keys: Array = ["priority", GameplayTypes.Stat.STAMINA, "stamina_per_round", "element", "damage_type"]
		for stat_type: int in GameplayTypes.Stat.values():
			migration_keys.append(stat_type)
		for key: Variant in migration_keys:
			if not item.has(key):
				item[key] = defaults.get(key, "" if key in ["element", "damage_type"] else 0)
	if not state.has("stamina"):
		run.stamina = 0 if not run.pending_turn.is_empty() else int(run.round_resources()[GameplayTypes.Stat.STAMINA])
		run.stamina_capacity = int(run.round_resources()[GameplayTypes.Stat.STAMINA])
	run.normalize_reward_restrictions()
	# An already committed old player action must finish without charging again.
	if not run.pending_turn.is_empty() and not run.pending_turn.has("stamina_after"):
		run.pending_turn["stamina_after"] = run.stamina
		run.pending_turn[GameplayTypes.Stat.STAMINA] = run.stamina_capacity
		run.pending_turn["player_state"]["stamina"] = run.stamina

func write(id: String, data: Dictionary) -> bool:
	if id.is_empty() or id.get_file() != id or id.contains(".."):
		last_error = ERR_INVALID_PARAMETER
		return false
	last_error = DirAccess.make_dir_recursive_absolute(directory)
	if last_error != OK:
		return false
	var path: String = directory.path_join(id + ".save")
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		last_error = FileAccess.get_open_error()
		return false
	file.store_var(data)
	file.flush()
	last_error = file.get_error()
	file.close()
	if last_error != OK:
		return false
	last_error = DirAccess.rename_absolute(path + ".tmp", path)
	return last_error == OK

func read(id: String) -> Dictionary:
	if id.get_file() != id or id.contains(".."):
		return {}
	var file := FileAccess.open(directory.path_join(id + ".save"), FileAccess.READ)
	if file == null:
		return {}
	var data: Variant = file.get_var(false)
	if not data is Dictionary or data.get("version") not in [1, 2, VERSION] or not data.get("state") is Dictionary:
		return {}
	var state: Dictionary = data.state
	for key: String in ["phase", "fight", "hp", "max_hp", "combat_state", "rng_seed", "rng_state", "pending_turn", "items", "enemy"]:
		if not state.has(key):
			return {}
	if not data.get("playback", {}) is Dictionary:
		return {}
	if state.has("floor_index"):
		if not state.floor_index is int or state.floor_index < 0 or state.floor_index >= PackRun.FLOORS or state.floor_index != state.fight:
			return {}
		if state.get("room_kind", "") not in ["combat", "rest", "relic", "encounter"] or not state.get("door_choices", []) is Array:
			return {}
		var ids: Array[String] = []
		for door: Variant in state.get("door_choices", []):
			if not door is Dictionary or door.get("kind", "") not in ["combat", "rest", "relic", "encounter"] or door.get("id") != door.get("kind") or ids.has(door.get("id", "")):
				return {}
			ids.append(door.id)
		if state.phase == PackRun.Phase.SELECTOR and ids.is_empty():
			return {}
	if not PackCatalog.classes().has(state.get("class_key", "")) or not state.get("items") is Array or not state.get("enemy") is Dictionary or not state.has("rng_state"):
		return {}
	if state.has("poison_statuses"):
		if not state.poison_statuses is Dictionary: return {}
		for owner: String in ["player", "enemy"]:
			if not StatusResolver.is_snapshot_valid(state.poison_statuses.get(owner), &"poison"): return {}
	if not state.pending_turn is Dictionary: return {}
	if not state.pending_turn.get("player_state", {}) is Dictionary: return {}
	for container: Dictionary in [state, state.pending_turn, state.pending_turn.get("player_state", {})]:
		for key: String in ["statuses", "statuses_after"]:
			if container.has(key) and not _status_snapshot_valid(container[key]): return {}
	for item: Variant in state.items:
		if not item is Dictionary or (not PackCatalog.ROSTER.has(item.get("key", "")) and item.get("key", "") != PackCatalog.QUIVER.KEY):
			return {}
	return data

func _migrate_archer(run: PackRun) -> void:
	run.volley_remaining = 3 - posmod(run.turn - 1, 3)
	if run.class_key != "ranger" or not run.quiver().is_empty():
		return
	var special: Dictionary = PackCatalog.item(PackCatalog.QUIVER.KEY)
	special["arrow_type"] = "broadhead"
	var old: Dictionary = {}
	for item: Dictionary in run.items:
		if item["key"] == "quiver":
			old = item
			break
	if not old.is_empty():
		for key: String in ["id", "cell", "rotation", "shape"]:
			special[key] = old[key]
		old.merge(special, true)
		special = old
	else:
		special["id"] = run.next_id
		run.next_id += 1
		special["cell"] = null
		run.items.append(special)
	if special["cell"] == null:
		for y in range(run.GRID.y):
			for x in range(run.GRID.x):
				if run.can_place(special, Vector2i(x, y)):
					special["cell"] = Vector2i(x, y)
					return
		# Preserve all carried items when an old full backpack needs room.
		for item: Dictionary in run.items:
			if item == special:
				continue
			for cell: Vector2i in run.cells(item):
				if cell in [Vector2i(0, 0), Vector2i(0, 1)]:
					item["cell"] = null
					break
		special["rotation"] = 0
		special["shape"] = Vector2i(1, 2)
		special["cell"] = Vector2i.ZERO

func remove(id: String) -> bool:
	if id.is_empty() or id.get_file() != id or id.contains(".."):
		last_error = ERR_INVALID_PARAMETER
		return false
	var path: String = directory.path_join(id + ".save")
	if not FileAccess.file_exists(path):
		last_error = ERR_FILE_NOT_FOUND
		return false
	last_error = DirAccess.remove_absolute(path)
	return last_error == OK

func is_victory_record(elapsed: float, current_id: String = "") -> bool:
	if not DirAccess.dir_exists_absolute(directory):
		return true
	for filename: String in DirAccess.get_files_at(directory):
		if not filename.ends_with(".save") or filename.trim_suffix(".save") == current_id:
			continue
		var data: Dictionary = read(filename.trim_suffix(".save"))
		if not data.is_empty() and data.state.get("phase") == PackRun.Phase.VICTORY and float(data.get("elapsed", INF)) <= elapsed:
			return false
	return true

func unfinished() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(directory):
		return result
	for filename: String in DirAccess.get_files_at(directory):
		if not filename.ends_with(".save"):
			continue
		var id: String = filename.trim_suffix(".save")
		var data: Dictionary = read(id)
		if data.is_empty() or data.state.get("phase") in [PackRun.Phase.VICTORY, PackRun.Phase.DEFEAT]:
			continue
		data["id"] = id
		result.append(data)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id > b.id)
	return result

static func _status_snapshot_valid(value: Variant) -> bool:
	if not value is Dictionary: return false
	for owner: String in PackRun.STATUS_IDS:
		if not value.get(owner) is Dictionary: return false
		for id: StringName in PackRun.STATUS_IDS[owner]:
			if not StatusResolver.is_snapshot_valid(value[owner].get(str(id)), id): return false
	return true
