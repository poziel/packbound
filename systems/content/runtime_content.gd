extends RefCounted
## Read-only authored definitions; adapters return independent mutable run records.
static var _content: GameContentDefinition

static func content() -> GameContentDefinition:
	if _content == null:
		var candidate: GameContentDefinition = load("res://assets/game_content.tres")
		var errors: PackedStringArray = candidate.refresh_from_folders()
		if not errors.is_empty():
			push_error("Cannot load game content: " + "; ".join(errors))
			return null
		_content = candidate
	return _content

static func character(id: String) -> CharacterDefinition:
	for value: CharacterDefinition in content().characters:
		if value.id == StringName(id):
			return value
	return null

static func monster_definition(id: String) -> MonsterDefinition:
	for value: MonsterDefinition in content().monsters:
		if value.id == StringName(id):
			return value
	return null

static func rules(abilities: Array[AbilityDefinition]) -> Dictionary:
	var result: Dictionary = {}
	for ability: AbilityDefinition in abilities:
		for effect: EffectDefinition in ability.effects:
			if effect is CatalogRuleEffectDefinition:
				result.merge(effect.parameters.duplicate(true), true)
	return result

static func collectible(value: CollectibleDefinition) -> Dictionary:
	var result: Dictionary = rules(value.abilities)
	result.merge({"key": str(value.id), "name": value.display_name,
		"detail": value.description, "rarity": value.rarity,
		"lore": value.lore, "tags": value.tags.duplicate(),
		"category_ids": value.category_ids.duplicate(), "classes": value.allowed_class_ids.duplicate(),
		"characters": value.allowed_character_ids.duplicate(),
		"preferred_class_ids": value.preferred_class_ids.duplicate(),
		"preferred_character_ids": value.preferred_character_ids.duplicate()}, true)
	for stat_type: int in GameplayTypes.Stat.values():
		var stat: String = str(GameplayTypes.stat_id(stat_type))
		result[stat] = int(value.base_stats.get(stat_type, 0))
	if value is RelicDefinition:
		var stats: Dictionary = {}
		for stat: int in value.base_stats:
			stats[str(GameplayTypes.stat_id(stat))] = value.base_stats[stat]
		result["stats"] = stats
		# Qualifiers remain presentation metadata; ordinary stat values have one owner.
		for row: Dictionary in result.get("keyword_stats", []):
			if stats.has(str(row.get("key", ""))):
				row["value"] = stats[str(row.key)]
	if value is ItemDefinition:
		if value.activation_costs.has(GameplayTypes.ResourceType.MOMENTUM):
			result["momentum_cost"] = value.activation_costs[GameplayTypes.ResourceType.MOMENTUM]
		var size := Vector2i.ZERO
		for cell: Vector2i in value.footprint:
			size = size.max(cell + Vector2i.ONE)
		result.merge({"mask": value.footprint.duplicate(), "shape": size, "rotation": 0,
			"rotatable": value.rotatable, "cost": int(value.activation_costs.get(GameplayTypes.ResourceType.MANA, 0)),
			"stamina_cost": int(value.activation_costs.get(GameplayTypes.ResourceType.STAMINA, 0)),
			"health_cost": int(value.activation_costs.get(GameplayTypes.ResourceType.HEALTH, 0)),
			"damage_type": str(GameplayTypes.damage_type_id(value.damage_type)),
			"element": str(GameplayTypes.element_id(value.element))}, true)
	return result

static func monster(value: MonsterDefinition) -> Dictionary:
	var result: Dictionary = {"intent": "", "hits": 1, "armor": 0, "pierce": 0,
		"poison": 0, "drain": 0, "reflect": 0, "sunder": 0, "enrage": 0,
		"regen": 0, "parry": 0, "opening_armor": 0, "cycle_armor": 0,
		"cleanse": 0, "physical_resistance": 0, "magical_resistance": 0}
	result.merge(rules(value.abilities), true)
	result.merge({"key": str(value.id), "name": value.display_name,
		"hp": int(value.resource_capacities.get(GameplayTypes.ResourceType.HEALTH, 0)),
		"detail": value.description}, true)
	for stat: int in value.base_stats:
		result["armor" if stat == GameplayTypes.Stat.BLOCK else str(GameplayTypes.stat_id(stat))] = int(value.base_stats[stat])
	var attacks: Array[int] = []
	for action: ActionDefinition in value.behavior.actions:
		for effect: EffectDefinition in action.effects:
			if effect is CatalogRuleEffectDefinition and effect.rule_id == &"enemy_response":
				attacks.append(int(effect.parameters.get("damage", 0)))
				result.hits = int(effect.parameters.get("hits", 1))
	if not value.abilities.is_empty():
		result.detail = value.abilities[0].description
	result.attacks = attacks
	if value.has_meta("encounter_floor"):
		result.encounter_floor = int(value.get_meta("encounter_floor"))
	return result

static func recipes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value: RecipeDefinition in content().recipes:
		var ingredients: Array[String] = []
		var choices: Array[Array] = []
		for ingredient: RecipeIngredientDefinition in value.ingredients:
			for count: int in ingredient.quantity:
				ingredients.append(str(ingredient.accepted_item_ids[0]))
				choices.append(ingredient.accepted_item_ids.duplicate())
		result.append({"id": str(value.id), "ingredients": ingredients, "choices": choices,
			"result": str(value.result_item_id), "quantity": value.result_quantity})
	return result
