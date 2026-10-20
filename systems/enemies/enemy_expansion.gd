extends RefCounted
## Adapt authored monster Resources to the existing combat dictionary contract.

const DATA = preload("res://systems/content/runtime_content.gd")

static func profiles() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for monster: MonsterDefinition in DATA.content().monsters:
		if monster.has_meta("encounter_floor"):
			result.append(DATA.monster(monster))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.key < b.key if a.encounter_floor == b.encounter_floor else a.encounter_floor < b.encounter_floor)
	return result

static func pool(floor_number: int, original: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = [original.duplicate(true)]
	for enemy: Dictionary in profiles():
		if enemy["encounter_floor"] == floor_number:
			result.append(enemy)
	return result
