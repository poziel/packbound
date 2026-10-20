@tool
class_name GameContentDefinition
extends Resource
## Authored cross-domain index. Loading this does not replace PackCatalog.
@export_tool_button("Refresh From Content Folders") var refresh_content: Callable = _refresh_in_inspector

@export var collectibles: CollectibleCatalogDefinition
@export var character_classes: Array[CharacterClassDefinition] = []
@export var characters: Array[CharacterDefinition] = []
@export var monsters: Array[MonsterDefinition] = []
@export var recipes: Array[RecipeDefinition] = []
@export var status_effects: Array[StatusEffectDefinition] = []
@export var loot_pools: Array[LootPoolDefinition] = []
@export var loot_progressions: Array[LootProgressionDefinition] = []

func _refresh_in_inspector() -> void:
	for error: String in refresh_from_folders():
		push_error(error)

## Validate a complete candidate before updating any current shared resources.
func refresh_from_folders(assets_root: String = "res://assets") -> PackedStringArray:
	var candidate: Resource = get_script().new()
	candidate.collectibles = preload("res://systems/content/collectible_catalog_definition.gd").new()
	var errors: PackedStringArray = candidate.collectibles.refresh_from_folders(assets_root.path_join("items"), assets_root.path_join("relics"), assets_root.path_join("categories"))
	var discovery: Script = preload("res://systems/content/collectible_discovery.gd")
	for spec: Array in [
		["character_classes", "characters", "character_class.tres", preload("res://systems/characters/character_class_definition.gd")],
		["characters", "characters", "character.tres", preload("res://systems/characters/character_definition.gd")],
		["monsters", "enemies", "monster.tres", preload("res://systems/enemies/monster_definition.gd")],
		["recipes", "recipes", "*.tres", preload("res://systems/crafting/recipe_definition.gd")],
		["status_effects", "status_effects", "status_effect.tres", preload("res://systems/combat/status_effect_definition.gd")],
		["loot_pools", "loot/pools", "*.tres", preload("res://systems/loot/loot_pool_definition.gd")],
		["loot_progressions", "loot/progressions", "*.tres", preload("res://systems/loot/loot_progression_definition.gd")],
	]:
		var paths: PackedStringArray = discovery.paths(assets_root.path_join(spec[1]), spec[2])
		if paths.is_empty():
			errors.append("No %s found under %s." % [spec[2], assets_root.path_join(spec[1])])
		for path: String in paths:
			var value: Resource = ResourceLoader.load(path)
			if not is_instance_of(value, spec[3]):
				errors.append("%s has the wrong Resource type for %s." % [path, spec[0]])
			else:
				candidate.get(spec[0]).append(value)
	if not errors.is_empty():
		return errors
	errors = candidate.validation_errors()
	if not errors.is_empty():
		return errors
	# Recipe order is authored crafting priority. Retain existing entries in order;
	# append newly discovered recipes in deterministic filename order.
	var remaining: Dictionary = {}
	for recipe: RecipeDefinition in candidate.recipes:
		remaining[recipe.id] = recipe
	var ordered: Array[RecipeDefinition] = []
	for recipe: RecipeDefinition in recipes:
		if recipe != null and remaining.has(recipe.id):
			ordered.append(remaining[recipe.id])
			remaining.erase(recipe.id)
	for recipe: RecipeDefinition in candidate.recipes:
		if remaining.has(recipe.id):
			ordered.append(recipe)
			remaining.erase(recipe.id)
	if collectibles == null:
		collectibles = candidate.collectibles
	else:
		# Preserve the external collectibles.tres reference and shared Inspector edits.
		collectibles.collectibles.assign(candidate.collectibles.collectibles)
		collectibles.categories.assign(candidate.collectibles.categories)
		collectibles.emit_changed()
	character_classes.assign(candidate.character_classes)
	characters.assign(candidate.characters)
	monsters.assign(candidate.monsters)
	recipes.assign(ordered)
	status_effects.assign(candidate.status_effects)
	loot_pools.assign(candidate.loot_pools)
	loot_progressions.assign(candidate.loot_progressions)
	resource_name = "Game Content"
	emit_changed()
	return errors

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var by_domain: Dictionary = {}
	if collectibles == null:
		errors.append("collectibles must not be null.")
	else:
		errors.append_array(collectibles.validation_errors())
		var items: Dictionary = {}
		for entry: CollectibleDefinition in collectibles.collectibles:
			if entry != null:
				items[entry.id] = entry
		by_domain["collectibles"] = items
	for field: String in ["character_classes", "characters", "monsters", "recipes", "status_effects", "loot_pools", "loot_progressions"]:
		var entries: Array = get(field)
		var ids: Dictionary = {}
		for index: int in range(entries.size()):
			var entry: Resource = entries[index]
			if entry == null:
				errors.append("%s[%d] must not be null." % [field, index])
				continue
			for error: String in entry.validation_errors():
				errors.append("%s[%d]: %s" % [field, index, error])
			if ids.has(entry.id):
				errors.append("%s[%d] duplicates ID %s." % [field, index, entry.id])
			ids[entry.id] = entry
		by_domain[field] = ids
	for character: CharacterDefinition in characters:
		if character == null:
			continue
		if not by_domain.character_classes.has(character.class_id):
			errors.append("character %s references unknown class %s." % [character.id, character.class_id])
		for equipment: StartingEquipmentDefinition in character.starting_equipment:
			if equipment != null and not by_domain.get("collectibles", {}).get(equipment.item_id) is ItemDefinition:
				errors.append("character %s references unknown starting item %s." % [character.id, equipment.item_id])
	for recipe: RecipeDefinition in recipes:
		if recipe == null:
			continue
		var required: Array[StringName] = [recipe.result_item_id]
		for ingredient: RecipeIngredientDefinition in recipe.ingredients:
			if ingredient != null:
				required.append_array(ingredient.accepted_item_ids)
		for id: StringName in required:
			if not by_domain.get("collectibles", {}).get(id) is ItemDefinition:
				errors.append("recipe %s references unknown item %s." % [recipe.id, id])
	if collectibles != null:
		for entry: CollectibleDefinition in collectibles.collectibles:
			if entry == null:
				continue
			for field: String in ["allowed_class_ids", "preferred_class_ids", "allowed_character_ids", "preferred_character_ids"]:
				var domain: Dictionary = by_domain.character_classes if field.contains("class") else by_domain.characters
				for id: StringName in entry.get(field):
					if not domain.has(id):
						errors.append("collectible %s %s references unknown ID %s." % [entry.id, field, id])
	for pool: LootPoolDefinition in loot_pools:
		if pool == null:
			continue
		for id: StringName in pool.collectible_weights:
			if not by_domain.get("collectibles", {}).has(id):
				errors.append("loot pool %s references unknown collectible %s." % [pool.id, id])
	for progression: LootProgressionDefinition in loot_progressions:
		if progression == null:
			continue
		for id: StringName in progression.pool_ids:
			if not by_domain.loot_pools.has(id):
				errors.append("loot progression %s references unknown pool %s." % [progression.id, id])
	return errors
