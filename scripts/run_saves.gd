class_name PackRunSaves
extends RefCounted

const VERSION: int = 1
var directory: String = "user://runs"
var last_error: Error = OK

func new_id() -> String:
	return "%d-%s" % [Time.get_unix_time_from_system() * 1000, Crypto.new().generate_random_bytes(8).hex_encode()]

func capture(run: PackRun, elapsed: float, playback: PackCombatPlayback = null) -> Dictionary:
	var state: Dictionary = {}
	for property: Dictionary in run.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE and property.name != "rng":
			state[property.name] = run.get(property.name)
	state["rng_seed"] = run.rng.seed
	state["rng_state"] = run.rng.state
	return {"version": VERSION, "elapsed": elapsed, "state": state.duplicate(true), "playback": playback.snapshot() if playback != null else {}}

func restore(run: PackRun, data: Dictionary) -> void:
	var state: Dictionary = data["state"].duplicate(true)
	for property: Dictionary in run.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE and state.has(property.name) and property.name != "rng":
			run.set(property.name, state[property.name])
	run.rng.seed = state["rng_seed"]
	run.rng.state = state["rng_state"]
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
	for key: String in ["physical_resistance", "magical_resistance"]:
		if not run.enemy.has(key):
			run.enemy[key] = 0
	# Fill only newly introduced fields; preserve saved rolls and existing art/layout.
	for item: Dictionary in run.items:
		var defaults: Dictionary = PackCatalog.item(item["key"])
		if item["key"] == PackCatalog.QUIVER.KEY:
			item["name"] = defaults["name"]
		var migration_keys: Array[String] = ["priority", "stamina_cost", "stamina", "stamina_per_round", "element", "damage_type"]
		migration_keys.append_array(PackCatalog.STATS)
		for key: String in migration_keys:
			if not item.has(key):
				item[key] = defaults.get(key, "" if key in ["element", "damage_type"] else 0)
	if not state.has("stamina"):
		run.stamina = 0 if not run.pending_turn.is_empty() else int(run.round_resources()["stamina"])
		run.stamina_capacity = int(run.round_resources()["stamina"])
	# An already committed old player action must finish without charging again.
	if not run.pending_turn.is_empty() and not run.pending_turn.has("stamina_after"):
		run.pending_turn["stamina_after"] = run.stamina
		run.pending_turn["stamina"] = run.stamina_capacity
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
	if not data is Dictionary or data.get("version") != VERSION or not data.get("state") is Dictionary:
		return {}
	var state: Dictionary = data.state
	for key: String in ["phase", "fight", "hp", "max_hp", "combat_state", "rng_seed", "rng_state", "pending_turn", "items", "enemy"]:
		if not state.has(key):
			return {}
	if not data.get("playback", {}) is Dictionary:
		return {}
	if not PackCatalog.classes().has(state.get("class_key", "")) or not state.get("items") is Array or not state.get("enemy") is Dictionary or not state.has("rng_state"):
		return {}
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
