extends "res://tests/support/test_case.gd"
const DATA = preload("res://systems/content/runtime_content.gd")
const CATEGORIES = preload("res://systems/content/collectible_categories.gd")
const CRAFTING = preload("res://systems/crafting/pack_crafting.gd")

func _run() -> void:
	var item: ItemDefinition = CATEGORIES.definition_for_key("longsword")
	var damage: int = item.base_stats[GameplayTypes.Stat.DAMAGE]
	var cost: int = item.activation_costs[GameplayTypes.ResourceType.STAMINA]
	item.base_stats[GameplayTypes.Stat.DAMAGE] = 17
	item.activation_costs[GameplayTypes.ResourceType.STAMINA] = 1
	var record: Dictionary = PackCatalog.item("longsword")
	check_equal(record[GameplayTypes.Stat.DAMAGE], 17, "Runtime item damage reads its typed definition")
	check_equal(record["activation_costs"][GameplayTypes.ResourceType.STAMINA], 1, "Runtime activation cost reads its definition")
	record.mask.clear()
	record.category_ids.clear()
	check(not item.footprint.is_empty(), "Run footprint mutations cannot change the shared definition")
	check(not item.category_ids.is_empty(), "Run categories cannot mutate the shared definition")
	var run := PackRun.new()
	run.reset(42)
	run.items.clear()
	run.add_item("longsword", Vector2i.ZERO)
	check_equal(run.effects().physical_damage, 17, "Combat consumes the authored item damage")
	item.base_stats[GameplayTypes.Stat.DAMAGE] = damage
	item.activation_costs[GameplayTypes.ResourceType.STAMINA] = cost
	var character: CharacterDefinition = DATA.character("warrior")
	var health: int = character.resource_capacities[GameplayTypes.ResourceType.HEALTH]
	var stamina: int = character.resource_capacities[GameplayTypes.ResourceType.STAMINA]
	character.resource_capacities[GameplayTypes.ResourceType.HEALTH] = 57
	character.resource_capacities[GameplayTypes.ResourceType.STAMINA] = 8
	var equipment := StartingEquipmentDefinition.new()
	equipment.item_id = &"bandage"
	equipment.position = Vector2i(4, 0)
	character.starting_equipment.append(equipment)
	run.reset(42)
	check_equal(run.max_hp, 57, "Fresh run health comes from CharacterDefinition")
	check_equal(PackCatalog.base_resources("warrior")[GameplayTypes.Stat.STAMINA], 8, "Round resource baseline comes from CharacterDefinition")
	check_equal(run.items.size(), 4, "Starting equipment uses its authored count")
	check_equal(run.items.back().cell, equipment.position, "Starting equipment uses its authored position")
	character.starting_equipment.pop_back()
	character.resource_capacities[GameplayTypes.ResourceType.HEALTH] = health
	character.resource_capacities[GameplayTypes.ResourceType.STAMINA] = stamina
	var relic: RelicDefinition = CATEGORIES.definition_for_key("hearth_token")
	var ward: int = relic.base_stats[GameplayTypes.Stat.WARD]
	relic.base_stats[GameplayTypes.Stat.WARD] = 9
	run.reset(42)
	run.relics.assign(["hearth_token"])
	check_equal(run.effects()[GameplayTypes.Stat.WARD], 9, "Relic passive stats use the typed definition")
	relic.base_stats[GameplayTypes.Stat.WARD] = ward
	var monster: MonsterDefinition = DATA.monster_definition("ash_rat")
	var hp: int = monster.resource_capacities[GameplayTypes.ResourceType.HEALTH]
	monster.resource_capacities[GameplayTypes.ResourceType.HEALTH] = 91
	run.reset(42)
	check_equal(run.enemy.max_hp, 91, "Encounter health comes from MonsterDefinition")
	monster.resource_capacities[GameplayTypes.ResourceType.HEALTH] = hp
	check_equal(PackCatalog.enemies()[0].key, "ash_rat", "First encounter remains stable")
	check_equal(PackCatalog.enemies()[19].key, "zippered_maw", "Boss encounter remains stable")
	check_equal(PackArt.item("longsword"), item.icon, "Item artwork reads the authored icon")
	check_equal(PackArt.enemy("ash_rat"), monster.icon, "Monster artwork reads the authored icon")
	_check_crafting()
	report("RUNTIME DEFINITIONS")
	quit(1 if failures else 0)

func _check_crafting() -> void:
	var original: Array[RecipeDefinition] = DATA.content().recipes.duplicate()
	var recipe := RecipeDefinition.new()
	recipe.id = &"test_alternatives"
	recipe.result_item_id = &"longsword"
	recipe.result_quantity = 2
	var alternatives := RecipeIngredientDefinition.new()
	alternatives.accepted_item_ids.assign([&"rusty_knife", &"bandage"])
	alternatives.quantity = 2
	var required := RecipeIngredientDefinition.new()
	required.accepted_item_ids.assign([&"rusty_knife"])
	recipe.ingredients.assign([alternatives, required])
	DATA.content().recipes.assign([recipe])
	var run := PackRun.new()
	run.reset(42)
	run.items.clear()
	run.add_item("rusty_knife", Vector2i.ZERO)
	run.add_item("bandage", Vector2i.RIGHT)
	run.add_item("bandage", Vector2i(2, 0))
	var before: Array[Dictionary] = run.items.duplicate(true)
	var plans: Array[Dictionary] = CRAFTING.plans(run)
	check_equal(plans.size(), 1, "Alternative ingredient matching backtracks instead of consuming the only required knife")
	check_equal(run.items, before, "Recipe preview never consumes ingredients")
	check_equal(recipe.ingredients[0].quantity, 2, "Recipe matching never mutates authored quantities")
	if not plans.is_empty():
		check_equal(plans[0].components.size(), 3, "Ingredient quantities consume distinct instances")
		CRAFTING.resolve(run)
		check_equal(run.items.size(), 2, "Authored output quantity creates two items")
		check(run.items[0].id != run.items[1].id, "Every crafted output has a distinct instance ID")
		for output: Dictionary in run.items:
			check_equal(output.key, "longsword", "Crafted result uses its authored item ID")
	DATA.content().recipes.assign(original)
