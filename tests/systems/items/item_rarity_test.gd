extends "res://tests/support/test_case.gd"



func _initialize() -> void:
	if not require_isolation():
		return
	var tiers: Array = GameplayTypes.Rarity.values()
	for key: String in PackCatalog.ROSTER:
		check(PackCatalog.item(key).get("rarity", "") in tiers, "Item has authored rarity: " + key)
	for key: String in PackCatalog.RELICS:
		check(PackCatalog.relic(key).get("rarity", "") in tiers, "Relic has authored rarity: " + key)
	for key: String in PackCatalog.QUIVER.OPTIONS:
		check(PackCatalog.item(key).get("rarity", "") in tiers, "Quiver option has rarity: " + key)
	check(PackCatalog.item(PackCatalog.QUIVER.KEY).get("rarity", "") in tiers, "Bound quiver has rarity")
	for tier: int in tiers:
		check(PackCatalog.items_of_rarity(tier).size() >= 2, "At least two items in " + str(GameplayTypes.rarity_id(tier)))
		check(not PackCatalog.relics_of_rarity(tier).is_empty(), "Relics cover " + str(GameplayTypes.rarity_id(tier)))
	check(PackCatalog.items_of_rarity(999).is_empty(), "Unknown rarity cannot select rewards")
	var run := PackRun.new()
	run.reset(42)
	run.items.clear()
	run.relics.clear()
	var base: Dictionary = run.round_resources()
	run.relics.assign(["hearth_token", "herbalist_knot", "trail_medallion", "bastion_seal", "starwell_crown"])
	check(run.round_resources()[GameplayTypes.Stat.MANA] == base[GameplayTypes.Stat.MANA] + 2, "Relic mana refills each round")
	check(run.round_resources()[GameplayTypes.Stat.STAMINA] == base[GameplayTypes.Stat.STAMINA] + 2, "Relic stamina stacks across different relics")
	var effects: Dictionary = run.effects()
	check(effects[GameplayTypes.Stat.HEALING] == 1 and effects[GameplayTypes.Stat.WARD] == 3 and effects[GameplayTypes.Stat.PLATING] == 1, "New relic protection and regeneration are active")
	var item: Dictionary = run.add_item("rusty_knife", Vector2i.ZERO)
	item.erase("rarity")
	item[GameplayTypes.Stat.DAMAGE] = 123
	var saves = preload("res://systems/runs/run_saves.gd").new()
	var saved: Dictionary = saves.capture(run, 0.0)
	saves.restore(run, saved)
	check(run.items[0]["rarity"] == GameplayTypes.Rarity.COMMON and run.items[0][GameplayTypes.Stat.DAMAGE] == 123, "Legacy save receives rarity without losing rolled stats")
	# Old saves recorded text; the loader replaces authored rarity from definitions.
	saved.state.items[0]["rarity"] = "common"
	saves.restore(run, saved)
	check_equal(run.items[0]["rarity"], GameplayTypes.Rarity.COMMON, "Legacy text rarity is normalized at save loading")
	check_equal(run.items[0][GameplayTypes.Stat.DAMAGE], 123, "Rarity migration preserves instance combat values")
	check(saves.capture(run, 0.0).state.items[0].rarity is int, "New save snapshots contain enum rarity")
	# Build a genuine pre-enum item, including customized values rather than catalog defaults.
	var legacy_item: Dictionary = saved.state.items[0]
	legacy_item.erase(GameplayTypes.Stat.DAMAGE)
	legacy_item["damage"] = 123
	legacy_item.erase("activation_costs")
	legacy_item["cost"] = 4
	legacy_item["stamina_cost"] = 2
	legacy_item["health_cost"] = 3
	legacy_item["momentum_cost"] = 1
	legacy_item["element"] = "void"
	legacy_item["damage_type"] = "magical"
	saves.restore(run, saved)
	var migrated: Dictionary = run.items[0]
	check_equal(migrated[GameplayTypes.Stat.DAMAGE], 123, "Legacy string damage keeps its rolled value")
	check_equal(migrated.activation_costs[GameplayTypes.ResourceType.MANA], 4, "Legacy mana activation cost survives loading")
	check_equal(migrated.activation_costs[GameplayTypes.ResourceType.STAMINA], 2, "Legacy stamina activation cost survives loading")
	check_equal(migrated.activation_costs[GameplayTypes.ResourceType.HEALTH], 3, "Legacy health activation cost survives loading")
	check_equal(migrated.activation_costs[GameplayTypes.ResourceType.MOMENTUM], 1, "Legacy Momentum activation cost survives loading")
	check_equal(migrated.element, GameplayTypes.Element.VOID, "Legacy element loads as an enum")
	check_equal(migrated.damage_type, GameplayTypes.DamageType.MAGICAL, "Legacy damage type loads as an enum")
	for retired: String in ["damage", "cost", "stamina_cost", "health_cost", "momentum_cost"]:
		check(not migrated.has(retired), "Loading removes retired duplicate item key: " + retired)
	var migrated_snapshot: Dictionary = saves.capture(run, 0.0)
	var roundtrip := PackRun.new()
	saves.restore(roundtrip, migrated_snapshot)
	check_equal(roundtrip.items[0], migrated, "Enum item snapshots restore without changing custom values")
	check_equal(PackCatalog.RARITY.label({"rarity": GameplayTypes.Rarity.LEGENDARY}), "Legendary", "Presentation translates enum rarity into its label")
	check_equal(PackCatalog.RARITY.tier({"rarity": 999}), GameplayTypes.Rarity.COMMON, "Invalid runtime rarity falls back safely")
	for recipe: Dictionary in PackRun.CRAFTING.RECIPES:
		var output: Dictionary = PackCatalog.item(recipe["result"])
		for ingredient: String in recipe["ingredients"]:
			check(tiers.find(PackCatalog.item(ingredient)["rarity"]) < tiers.find(output["rarity"]), "Crafting raises rarity: " + recipe["id"])
		if str(recipe["id"]).begins_with("forge_"):
			var crafting := PackRun.new()
			crafting.reset(17)
			crafting.items.clear()
			crafting.relics.clear()
			crafting.add_item(recipe["ingredients"][0], Vector2i.ZERO)
			crafting.add_item(recipe["ingredients"][1], Vector2i.RIGHT)
			check(crafting.start_combat(), "Upgrade starts combat: " + recipe["id"])
			check(crafting.items.size() == 1 and crafting.items[0]["key"] == recipe["result"] and crafting.items[0]["rarity"] == output["rarity"], "Upgrade consumes inputs and yields higher tier: " + recipe["id"])
	var found_new: bool = false
	for seed_value in range(100):
		var rewards := PackRun.new()
		rewards.reset(seed_value)
		rewards.item_rewards.clear()
		rewards.offers.clear()
		rewards.fight = 0
		rewards.roll_loot()
		for key: String in rewards.offers:
			if PackCatalog.CONTENT.ITEM_KEYS.has(key):
				found_new = true
				check(PackCatalog.item(key)["rarity"] == GameplayTypes.Rarity.COMMON, "Early new equipment is common")
	check(found_new, "New equipment participates in normal rewards")
	for tier_index in range(tiers.size()):
		var seen: Dictionary = {}
		for seed_value in range(100):
			var rewards := PackRun.new()
			rewards.reset(seed_value)
			rewards.item_rewards.clear()
			rewards.offers.clear()
			rewards.fight = tier_index * 4
			rewards.roll_loot()
			for key: String in rewards.offers:
				if PackCatalog.CONTENT.ITEM_KEYS.has(key):
					var offered_tier: int = PackCatalog.item(key)["rarity"]
					seen[offered_tier] = true
					check(tiers.find(offered_tier) <= tier_index, "New reward obeys floor-tier gate")
		check(seen.has(tiers[tier_index]), "New tier enters rewards on floor %d" % (tier_index * 4 + 1))
	report("ITEM RARITY")
	quit(1 if failures else 0)
