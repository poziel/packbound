extends RefCounted
## Shared reward selection. Inspection is pure; only roll() consumes the supplied RNG.
const DATA = preload("res://systems/content/runtime_content.gd")
const COLLECTIBLES = preload("res://systems/content/collectible_categories.gd")

static func progression(id: String) -> LootProgressionDefinition:
	var value: LootProgressionDefinition = DATA.definition(&"loot_progressions", StringName(id))
	if value != null: return value
	push_error("Unknown loot progression: " + id)
	return null

static func pool(id: String) -> LootPoolDefinition:
	var value: LootPoolDefinition = DATA.definition(&"loot_pools", StringName(id))
	if value != null: return value
	push_error("Unknown loot pool: " + id)
	return null

static func _rarities(value: LootProgressionDefinition, floor_number: int) -> Dictionary:
	var checkpoint: int = -1
	for at: int in value.rarity_weights_by_floor:
		if at <= floor_number and at > checkpoint: checkpoint = at
	return value.rarity_weights_by_floor.get(checkpoint, {})

static func _order(value: LootPoolDefinition) -> Array[StringName]:
	var result: Array[StringName] = value.candidate_order.duplicate()
	if result.is_empty():
		result.assign(value.collectible_weights.keys())
		result.sort()
	return result

static func candidates(progression_id: String, pool_id: String, character_id: String, floor_number: int, excluded: Array = [], allowed: Variant = null) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var tuning: LootProgressionDefinition = progression(progression_id)
	var source: LootPoolDefinition = pool(pool_id)
	var character: CharacterDefinition = DATA.character(character_id)
	if tuning == null or source == null or character == null or not tuning.pool_ids.has(source.id): return result
	var rarities: Dictionary = _rarities(tuning, maxi(1, floor_number))
	var highest: float = -INF
	for id: StringName in _order(source):
		if excluded.has(str(id)) or (allowed != null and not allowed.has(str(id))): continue
		if source.minimum_floors.get(id, 1) > maxi(1, floor_number): continue
		var value: CollectibleDefinition = COLLECTIBLES.definition_for_key(str(id))
		if value == null: continue
		if not value.allowed_class_ids.is_empty() and not value.allowed_class_ids.has(character.class_id): continue
		if not value.allowed_character_ids.is_empty() and not value.allowed_character_ids.has(character.id): continue
		var base: float = source.collectible_weights.get(id, 0.0)
		var rarity: float = float(rarities.get(value.rarity, 0.0))
		if base <= 0.0 or rarity <= 0.0: continue
		var preferred: bool = value.preferred_class_ids.has(character.class_id) or value.preferred_character_ids.has(character.id)
		# Normalize in log space so finite authored factors cannot overflow when multiplied.
		var weight: float = log(base) + log(rarity) + (log(tuning.preferred_weight_multiplier) if preferred else 0.0)
		highest = maxf(highest, weight)
		result.append({"id": str(id), "weight": weight, "log_weight": weight})
	for row: Dictionary in result:
		row.weight = exp(float(row.weight) - highest)
	return result

static func available(progression_id: String, character_id: String, floor_number: int, excluded: Array = [], allowed: Variant = null) -> Array[String]:
	var result: Array[String] = []
	var tuning: LootProgressionDefinition = progression(progression_id)
	if tuning == null: return result
	for pool_id: StringName in tuning.pool_ids:
		for row: Dictionary in candidates(progression_id, str(pool_id), character_id, floor_number, excluded, allowed):
			if not result.has(row.id): result.append(row.id)
	return result

static func _draw(rows: Array[Dictionary], rng: RandomNumberGenerator) -> int:
	# Rebase after every removal: tiny remaining weights must recover once the
	# dominant candidate has been drawn without replacement.
	var highest: float = -INF
	for row: Dictionary in rows: highest = maxf(highest, float(row.log_weight))
	for row: Dictionary in rows: row.weight = exp(float(row.log_weight) - highest)
	var equal: bool = true
	var total: float = 0.0
	for row: Dictionary in rows:
		total += float(row.weight)
		if row.weight != rows[0].weight: equal = false
	# Keep the original integer draw and exact RNG consumption for uniform authored pools.
	if equal: return rng.randi_range(0, rows.size() - 1)
	var remaining: float = rng.randf() * total
	var last_positive: int = 0
	for index: int in range(rows.size()):
		if float(rows[index].weight) > 0.0: last_positive = index
		remaining -= float(rows[index].weight)
		if remaining < 0.0: return index
	return last_positive

static func roll(progression_id: String, character_id: String, floor_number: int, rng: RandomNumberGenerator, excluded: Array = [], allowed: Variant = null) -> Array[String]:
	var result: Array[String] = []
	var tuning: LootProgressionDefinition = progression(progression_id)
	if tuning == null: return result
	for pool_id: StringName in tuning.pool_ids:
		var source: LootPoolDefinition = pool(str(pool_id))
		if source == null: continue
		var rows: Array[Dictionary] = candidates(progression_id, str(pool_id), character_id, floor_number, excluded, allowed)
		for count: int in source.offer_count:
			if rows.is_empty(): break
			var index: int = _draw(rows, rng)
			result.append(rows[index].id)
			if not source.allow_duplicates: rows.remove_at(index)
	return result

static func item_progression(character_id: String) -> String:
	var character: CharacterDefinition = DATA.character(character_id)
	return "items_" + str(character.class_id) if character != null else ""

static func initial_options(character_id: String = "ranger") -> Array[String]:
	var ids: Array[String] = available("quiver_initial", character_id, 1)
	var tuning: LootProgressionDefinition = progression("quiver_initial")
	if tuning == null or tuning.pool_ids.is_empty(): return []
	var count: int = pool(str(tuning.pool_ids[0])).offer_count
	return ids.slice(0, count)

static func available_upgrades(quiver: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var tuning: LootProgressionDefinition = progression("quiver_upgrades")
	if tuning == null: return result
	for pool_id: StringName in tuning.pool_ids:
		for id: StringName in _order(pool(str(pool_id))):
			var value: CollectibleDefinition = COLLECTIBLES.definition_for_key(str(id))
			var rules: Dictionary = DATA.collectible(value)
			if rules.has("cap") and int(quiver.get("upgrades", {}).get(str(id), 0)) < int(rules.cap):
				result.append(str(id))
	return result

static func item_offers(character_id: String, floor_number: int, rng: RandomNumberGenerator, quiver: Dictionary) -> Array[String]:
	var result: Array[String] = roll(item_progression(character_id), character_id, floor_number, rng)
	var tuning: LootProgressionDefinition = progression("quiver_upgrades")
	var character: CharacterDefinition = DATA.character(character_id)
	if tuning == null or character == null: return result
	var interval: int = int(tuning.get_meta("every_floors", 0))
	var slot: int = int(tuning.get_meta("replace_offer_index", -1))
	if character.class_id == StringName(tuning.get_meta("required_class_id", "")) and not quiver.is_empty() and str(quiver.get("key", "")) == str(tuning.get_meta("requires_item_id", "")) and interval > 0 and floor_number % interval == 0 and slot >= 0 and slot < result.size():
		var upgrades: Array[String] = roll("quiver_upgrades", character_id, floor_number, rng, [], available_upgrades(quiver))
		if not upgrades.is_empty(): result[slot] = upgrades[0]
	return result

## Compatibility repair preserves legal saved rolls and consumes no RNG.
static func repair(choices: Array, progression_id: String, character_id: String, floor_number: int, excluded: Array = []) -> Array[String]:
	var result: Array[String] = []
	result.assign(choices)
	var character: CharacterDefinition = DATA.character(character_id)
	var replacements: Array[String] = available(progression_id, character_id, floor_number, excluded)
	for index: int in range(result.size() - 1, -1, -1):
		var value: CollectibleDefinition = COLLECTIBLES.definition_for_key(result[index])
		if value != null and (value.allowed_class_ids.is_empty() or value.allowed_class_ids.has(character.class_id)) and (value.allowed_character_ids.is_empty() or value.allowed_character_ids.has(character.id)): continue
		var replacement: String = ""
		for id: String in replacements:
			if result.has(id): continue
			if replacement.is_empty(): replacement = id
			if value != null and COLLECTIBLES.definition_for_key(id).rarity == value.rarity:
				replacement = id
				break
		if replacement.is_empty(): result.remove_at(index)
		else: result[index] = replacement
	return result

static func fallback_item(character_id: String, floor_number: int) -> String:
	var tuning: LootProgressionDefinition = progression(item_progression(character_id))
	if tuning == null or tuning.pool_ids.is_empty(): return ""
	var rows: Array[Dictionary] = candidates(str(tuning.id), str(tuning.pool_ids.back()), character_id, floor_number)
	return str(rows[0].id) if not rows.is_empty() else ""
