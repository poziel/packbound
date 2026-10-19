extends "res://tests/support/test_case.gd"

const EXPANSION_ART = preload("res://systems/art/expansion_art.gd")


func _initialize() -> void:
	if not require_isolation():
		return
	check(PackCatalog.EXPANSION_ITEMS.ITEM_KEYS.size() == 96, "96 new items registered")
	check(PackCatalog.EXPANSION_RELICS.RELIC_KEYS.size() == 50, "50 new relics registered")
	var ids: Dictionary = {}
	for key: String in PackCatalog.ROSTER + PackCatalog.RELICS:
		check(not ids.has(key), "Cross-catalog unique ID: " + key)
		ids[key] = true
	var distribution: Dictionary = {}
	for key: String in PackCatalog.EXPANSION_ITEMS.ITEM_KEYS:
		var item: Dictionary = PackCatalog.item(key)
		distribution[item["rarity"]] = int(distribution.get(item["rarity"], 0)) + 1
		check(not item["mask"].is_empty(), "Footprint present: " + key)
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/items/%s/item.json" % key))
		check(parsed is Dictionary and parsed["id"] == key, "Author record loads: " + key)
		var texture: Texture2D = EXPANSION_ART.ITEM_TEXTURES.get(key)
		check(texture != null and texture.get_size() == Vector2(item["shape"]) * 32.0, "Runtime art matches footprint: " + key)
		for stat: String in PackCatalog.STATS:
			check(item.has(stat), "Complete stat contract: " + key + "/" + stat)
	check(distribution == {"common":20,"uncommon":24,"rare":24,"epic":18,"legendary":10}, "Item rarity distribution")
	for key: String in PackCatalog.EXPANSION_RELICS.RELIC_KEYS:
		var texture: Texture2D = EXPANSION_ART.RELIC_TEXTURES.get(key)
		check(texture != null and texture.get_size() == Vector2(32, 32), "Runtime relic texture loads at 32px: " + key)
	var counts: Dictionary = {}
	var signatures: Dictionary = {}
	var previous_ingredient_count: int = 5
	for recipe: Dictionary in PackRun.CRAFTING.RECIPES:
		check(recipe["ingredients"].size() <= previous_ingredient_count, "Longer recipes precede shorter recipes including legacy recipes")
		previous_ingredient_count = recipe["ingredients"].size()
		if not str(recipe["id"]).begins_with("assemble_"):
			continue
		var count: int = recipe["ingredients"].size()
		counts[count] = int(counts.get(count, 0)) + 1
		var sorted: Array = recipe["ingredients"].duplicate()
		sorted.sort()
		var signature: String = ",".join(sorted)
		check(not signatures.has(signature), "Recipe ingredient multiset unique: " + recipe["id"])
		signatures[signature] = true
		var output: Dictionary = PackCatalog.item(recipe["result"])
		var run := PackRun.new()
		var classes: Array = output.get("classes", [])
		run.reset(42, classes[0] if not classes.is_empty() else "warrior")
		run.relics.clear()
		run.items.clear()
		var ingredients: Array[Dictionary] = []
		for key: String in recipe["ingredients"]:
			var item: Dictionary = run.add_item(key)
			ingredients.append(item)
			check(run.item_enabled(item), "Ingredients obtainable by result class: " + recipe["id"] + "/" + key)
			check(PackCatalog.RARITY.TIERS.find(item["rarity"]) < PackCatalog.RARITY.TIERS.find(output["rarity"]), "Recipe raises rarity: " + recipe["id"])
		var placed: bool = _place_group(run, ingredients, 0)
		check(placed, "Connected layout fits: " + recipe["id"])
		if not placed:
			continue
		var before: Array[Dictionary] = run.items.duplicate(true)
		var plans: Array[Dictionary] = PackRun.CRAFTING.plans(run)
		check(plans.size() == 1 and plans[0]["recipe"] == recipe["id"], "Whole recipe wins over subsets: " + recipe["id"])
		run.effects()
		check(run.items == before, "Preview cannot consume recipe: " + recipe["id"])
		# Ranger's permanent quiver is needed to start combat, but excluded from recipes.
		if run.class_key == "ranger":
			var quiver: Dictionary = run.add_item("magnificent_quiver")
			quiver["arrow_type"] = "broadhead"
			run.auto_place(quiver)
		check(run.start_combat(), "Recipe combat starts: " + recipe["id"])
		var crafted: Array = run.items.filter(func(item: Dictionary) -> bool: return item["key"] == recipe["result"])
		check(crafted.size() == 1, "Recipe produces exactly one output: " + recipe["id"])
	check(counts == {2:36,3:24,4:9,5:3}, "72 recipes with approved ingredient counts")
	for character: String in PackCatalog.classes():
		for seed_value in range(12):
			var run := PackRun.new()
			run.reset(seed_value, character)
			run.fight = 16
			run.offers.clear()
			run.item_rewards.clear()
			run.roll_loot()
			for key: String in run.offers:
				check(run.item_enabled(PackCatalog.item(key)), "Rewards respect class: " + character + "/" + key)
	report("EXPANSION CATALOG")
	quit(1 if failures else 0)

func _place_group(run: PackRun, ingredients: Array[Dictionary], index: int) -> bool:
	if index == ingredients.size():
		return true
	var item: Dictionary = ingredients[index]
	for rotation in range(4):
		for y in range(PackRun.GRID.y):
			for x in range(PackRun.GRID.x):
				var at := Vector2i(x, y)
				if not run.can_place(item, at, rotation):
					continue
				item["cell"] = at
				item["rotation"] = rotation
				var connected: bool = index == 0
				for earlier in range(index):
					connected = connected or not PackRun.CRAFTING.links(run, [ingredients[earlier], item]).is_empty()
				if connected and _place_group(run, ingredients, index + 1):
					return true
				item["cell"] = null
	return false
