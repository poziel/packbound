class_name PackCatalog
extends RefCounted

const DATA = preload("res://systems/content/runtime_content.gd")
const CATEGORIES = preload("res://systems/content/collectible_categories.gd")

const QUIVER = preload("res://systems/characters/archer_quiver.gd")
const RARITY = preload("res://systems/items/item_rarity.gd")
const CONTENT = preload("res://systems/content/rarity_content.gd")
const EXPANSION_ITEMS = preload("res://systems/items/expansion_items.gd")
const EXPANSION_RELICS = preload("res://systems/relics/expansion_relics.gd")

const ROSTER: Array[String] = ["rusty_knife", "cracked_shield", "blood_gem", "bandage", "longsword", "tower_shield", "cursed_idol", "iron_charm", "shortbow", "quiver", "buckler", "ember_tome", "frost_wand", "spark_ring", "venom_dagger", "vampire_fang", "plate_mail", "thorn_mail", "warding_sigil", "hunting_trap", "battle_axe", "healing_herbs", "hourglass", "mirror_shard", "antidote", "lightning_wand", "void_tome", "venom_orb", "field_blade", "riveted_guard", "tempered_blade", "iron_guard", "oathsteel_blade", "sentinel_guard", "dusksteel_blade", "citadel_guard", "dawnbringer", "sovereign_guard"] + EXPANSION_ITEMS.ITEM_KEYS
const RELICS: Array[String] = ["diagonal_thread", "returning_guard", "blood_pact", "plague_seal", "echo_clock", "arcane_barter", "folded_space", "mana_furnace", "last_thread", "hearth_token", "herbalist_knot", "trail_medallion", "bastion_seal", "starwell_crown"] + EXPANSION_RELICS.RELIC_KEYS

static func classes() -> Dictionary:
	var result: Dictionary = {}
	var characters: Array[CharacterDefinition] = DATA.content().characters.duplicate()
	characters.sort_custom(func(a: CharacterDefinition, b: CharacterDefinition) -> bool:
		return int(a.get_meta("selection_order", 999)) < int(b.get_meta("selection_order", 999)))
	for character: CharacterDefinition in characters:
		var kind: CharacterClassDefinition
		for candidate: CharacterClassDefinition in DATA.content().character_classes:
			if candidate.id == character.class_id:
				kind = candidate
		var entry: Dictionary = DATA.rules(kind.abilities)
		var starters: Array[String] = []
		var positions: Array[Vector2i] = []
		var rotations: Array[int] = []
		for equipment: StartingEquipmentDefinition in character.starting_equipment:
			starters.append(str(equipment.item_id))
			positions.append(equipment.position)
			rotations.append(equipment.rotation)
		entry.merge({"name": kind.display_name, "hp": int(character.resource_capacities.get(GameplayTypes.ResourceType.HEALTH, 0)),
			"icon": str(kind.get_meta("icon_item_id", "")), "detail": kind.description,
			"starters": starters, "positions": positions, "rotations": rotations}, true)
		result[str(character.id)] = entry
	return result

static func base_resources(key: String) -> Dictionary:
	var value: CharacterDefinition = DATA.character(key)
	return {"mana": int(value.resource_capacities.get(GameplayTypes.ResourceType.MANA, 0)),
		"stamina": int(value.resource_capacities.get(GameplayTypes.ResourceType.STAMINA, 0)),
		"block": int(value.base_stats.get(GameplayTypes.Stat.BLOCK, 0))}

static func innate_stats(key: String) -> Array[Dictionary]:
	var character: Dictionary = classes()[key]
	var resources: Dictionary = base_resources(key)
	var result: Array[Dictionary] = [{"key": "health", "value": int(character["hp"])}]
	for stat: String in ["mana", "stamina", "block"]:
		if int(resources[stat]) > 0:
			result.append({"key": stat, "value": int(resources[stat])})
	return result

static func item(key: String) -> Dictionary:
	var value: CollectibleDefinition = CATEGORIES.definition_for_key(key)
	if not value is ItemDefinition:
		push_error("Unknown item: " + key)
		return {}
	return DATA.collectible(value)

static func relic(key: String) -> Dictionary:
	var value: CollectibleDefinition = CATEGORIES.definition_for_key(key)
	if not value is RelicDefinition:
		push_error("Unknown relic: " + key)
		return {}
	return DATA.collectible(value)

static func items_of_rarity(tier: GameplayTypes.Rarity) -> Array[String]:
	var result: Array[String] = []
	for key: String in ROSTER:
		if item(key)["rarity"] == tier:
			result.append(key)
	return result

static func relics_of_rarity(tier: GameplayTypes.Rarity) -> Array[String]:
	var result: Array[String] = []
	for key: String in RELICS:
		if relic(key)["rarity"] == tier:
			result.append(key)
	return result

static func enemies() -> Array[Dictionary]:
	var originals: Array[MonsterDefinition] = []
	for value: MonsterDefinition in DATA.content().monsters:
		if value.has_meta("progression_index"):
			originals.append(value)
	originals.sort_custom(func(a: MonsterDefinition, b: MonsterDefinition) -> bool:
		return int(a.get_meta("progression_index")) < int(b.get_meta("progression_index")))
	var result: Array[Dictionary] = []
	for value: MonsterDefinition in originals:
		result.append(DATA.monster(value))
	result.append_array(preload("res://systems/enemies/enemy_expansion.gd").profiles())
	return result
