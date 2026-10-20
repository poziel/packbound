extends "res://tests/support/test_case.gd"
const CRAFTING = preload("res://systems/crafting/pack_crafting.gd")

func _run() -> void:
	var content: Resource = ResourceLoader.load("res://assets/game_content.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	check(content != null, "Complete game content loads in a fresh process")
	if content == null:
		report("CONTENT RESOURCES")
		quit(1)
		return
	check_equal(content.validation_errors(), PackedStringArray(), "All intrinsic and cross-domain references validate")
	var items: Dictionary = {}
	var relics: Dictionary = {}
	for value: CollectibleDefinition in content.collectibles.collectibles:
		var target: Dictionary = items if value is ItemDefinition else relics
		check(not target.has(str(value.id)), "Unique collectible ID")
		target[str(value.id)] = value
		var source: Dictionary = PackCatalog.item(str(value.id)) if value is ItemDefinition else PackCatalog.relic(str(value.id))
		check_equal(value.display_name, source.name, "Catalog display name: " + str(value.id))
		check_equal(value.rarity, source.rarity, "Catalog rarity")
		check_equal(PackedStringArray(value.allowed_class_ids), PackedStringArray(source.get("classes", [])), "Class restrictions retained")
		check_equal(PackedStringArray(value.allowed_character_ids), PackedStringArray(source.get("characters", [])), "Character restrictions retained")
		check(value.icon != null, "Existing icon retained")
		check(not value.abilities.is_empty(), "Authored abilities exist")
		var preserved: Dictionary = value.abilities[0].effects[0].parameters
		for field: String in ["momentum", "keyword_stats", "tooltip_detail", "mana_per_round", "stamina_per_round", "block_per_round"]:
			if source.has(field):
				check_equal(preserved.get(field), source[field], "Special rule parameter retained: " + field)
		check(not preserved.has(GameplayTypes.Stat.DAMAGE), "Typed damage has one authority")
		check(not value.resource_path.is_empty() and value.resource_path.ends_with(".tres"), "Collectible is an external resource")
		check(not value.abilities[0].resource_path.is_empty(), "Ability has one external authority")
		check(not value.abilities[0].effects[0].resource_path.is_empty(), "Effect has one external authority")
		if value is ItemDefinition:
			var views: Dictionary = CollectibleAbilityResolver.item_views(value.abilities)
			for bonus_key: String in ["adjacency_bonus", "quiver_bonus", "momentum_gain", "momentum_damage", "primary_bonuses"]:
				if views.has(bonus_key): check_equal(source.get(bonus_key), views[bonus_key], "Typed item bonus reaches runtime: " + str(value.id))
		for stat_type: int in GameplayTypes.Stat.values():
			var stat: String = str(GameplayTypes.stat_id(stat_type))
			var grants: Dictionary = CollectibleAbilityResolver.contributions(value.abilities, CollectibleAbilityResolver.ITEM_TRIGGER) if value is ItemDefinition else {}
			check_equal(int(value.base_stats.get(stat_type, 0)) + int(grants.get(stat_type, 0)), int(source.get(stat_type, 0)), "Authored stat/effect contribution retained: " + stat)
		if value is ItemDefinition:
			check_equal(value.footprint, source.mask, "Item footprint retained")
			check_equal(value.activation_costs.get(GameplayTypes.ResourceType.MANA, 0), int(source["activation_costs"].get(GameplayTypes.ResourceType.MANA, 0)), "Mana cost retained")
			check_equal(value.activation_costs.get(GameplayTypes.ResourceType.STAMINA, 0), int(source["activation_costs"].get(GameplayTypes.ResourceType.STAMINA, 0)), "Stamina cost retained")
			check_equal(value.element, source.element, "Element retained")
			check_equal(value.damage_type, source.damage_type, "Damage type retained")
	var expected_items: Array = PackCatalog.ROSTER.duplicate()
	expected_items.append(PackCatalog.QUIVER.KEY)
	for key: String in PackCatalog.QUIVER.OPTIONS:
		if not expected_items.has(key):
			expected_items.append(key)
	check_equal(items.size(), expected_items.size(), "Exact item coverage including special quiver options")
	for key: String in expected_items:
		check(items.has(key), "Item present: " + key)
	check_equal(relics.size(), PackCatalog.RELICS.size(), "Exact relic coverage")
	for key: String in PackCatalog.RELICS:
		check(relics.has(key), "Relic present: " + key)
	check_equal(content.characters.size(), PackCatalog.classes().size(), "Exact Delver coverage")
	check_equal(content.character_classes.size(), PackCatalog.classes().size(), "Exact class coverage")
	for character: CharacterDefinition in content.characters:
		var source: Dictionary = PackCatalog.classes()[str(character.class_id)]
		check_equal(character.resource_capacities[GameplayTypes.ResourceType.HEALTH], int(source.hp), "Gameplay HP is authoritative")
		var resources: Dictionary = PackCatalog.base_resources(str(character.class_id))
		for resource: String in ["mana", "stamina"]:
			check_equal(character.resource_capacities[GameplayTypes.resource_from_id(StringName(resource))], resources[GameplayTypes.stat_from_id(StringName(resource))], "Gameplay resource capacity retained")
		check_equal(character.starting_equipment.size(), source.starters.size(), "Starter count retained")
		for slot: int in range(source.starters.size()):
			check_equal(str(character.starting_equipment[slot].item_id), source.starters[slot], "Starter item retained")
			check_equal(character.starting_equipment[slot].position, source.positions[slot], "Starter position retained")
			check(items.has(str(character.starting_equipment[slot].item_id)), "Starter item resolves")
			var item: ItemDefinition = items[str(character.starting_equipment[slot].item_id)]
			for cell: Vector2i in item.footprint:
				var placed: Vector2i = cell + character.starting_equipment[slot].position
				check(placed.x < character.backpack_size.x and placed.y < character.backpack_size.y, "Starter footprint fits board")
	var source_monsters: Dictionary = {}
	for enemy: Dictionary in PackCatalog.enemies():
		source_monsters[enemy.key] = enemy
	check_equal(content.monsters.size(), source_monsters.size(), "Exact monster coverage")
	for monster: MonsterDefinition in content.monsters:
		var source: Dictionary = source_monsters[str(monster.id)]
		check_equal(monster.resource_capacities[GameplayTypes.ResourceType.HEALTH], int(source.hp), "Monster HP retained")
		for field: String in ["drain", "reflect", "sunder", "enrage", "regen", "parry", "opening_armor", "cycle_armor"]:
			check_equal(monster.abilities[0].effects[0].parameters.get(field, 0), source.get(field, 0), "Monster special rule retained: " + field)
		check_equal(monster.base_stats.get(GameplayTypes.Stat.CLEANSE, 0), int(source.get(GameplayTypes.Stat.CLEANSE, 0)), "Monster cleanse retained in typed stats")
		check(not monster.abilities[0].effects[0].parameters.has("attacks"), "Attack cycle has one authority")
		check_equal(monster.behavior.actions.size(), source.attacks.size(), "Attack cycle length retained")
		for turn: int in range(source.attacks.size()):
			check_equal(monster.behavior.actions[turn].effects[0].parameters[GameplayTypes.Stat.DAMAGE], int(source.attacks[turn]), "Attack cycle damage retained")
			check_equal(monster.behavior.actions[turn].effects[0].parameters.hits, int(source.get("hits", 1)), "Multiple hits retained")
	check_equal(content.recipes.size(), CRAFTING.RECIPES.size(), "Exact recipe coverage")
	for position: int in range(CRAFTING.RECIPES.size()):
		var source: Dictionary = CRAFTING.RECIPES[position]
		var recipe: RecipeDefinition = content.recipes[position]
		check_equal(str(recipe.id), source.id, "Recipe priority retained")
		check_equal(str(recipe.result_item_id), source.result, "Recipe result retained")
		check_equal(recipe.ingredients.size(), source.ingredients.size(), "Repeated ingredients retained")
		for ingredient: int in range(source.ingredients.size()):
			check_equal(str(recipe.ingredients[ingredient].accepted_item_ids[0]), source.ingredients[ingredient], "Ingredient ID retained")
			check_equal(recipe.ingredients[ingredient].quantity, 1, "Ingredient multiplicity retained")
	report("CONTENT RESOURCES")
	quit(1 if failures else 0)
