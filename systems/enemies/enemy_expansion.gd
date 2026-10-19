extends RefCounted
## Numerical enemy profiles are the authority; README prose is independent.

const INDEX_PATH := "res://assets/enemies/expansion.json"
static var _profiles: Array[Dictionary] = []

static func profiles() -> Array[Dictionary]:
	if not _profiles.is_empty():
		return _profiles.duplicate(true)
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(INDEX_PATH))
	for path: String in index["enemies"]:
		var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var enemy: Dictionary = profile["starting_stats"].duplicate(true)
		enemy.merge({"key": profile["id"], "name": profile["name"], "intent": profile["intent"], "detail": profile["detail"], "encounter_floor": int(profile["encounter_floor"])}, true)
		# JSON numbers are floats; combat dictionaries retain their integer contract.
		for key: String in enemy.keys():
			if enemy[key] is float:
				enemy[key] = int(enemy[key])
		var attacks: Array[int] = []
		for amount: float in enemy["attacks"]:
			attacks.append(int(amount))
		enemy["attacks"] = attacks
		_profiles.append(enemy)
	return _profiles.duplicate(true)

static func pool(floor_number: int, original: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = [original.duplicate(true)]
	for enemy: Dictionary in profiles():
		if enemy["encounter_floor"] == floor_number:
			result.append(enemy)
	return result
