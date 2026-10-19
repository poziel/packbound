extends SceneTree

var failures: int = 0
var checks: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void:
	var tiers: Array[String] = ["common", "uncommon", "rare", "epic", "legendary"]
	for key: String in PackCatalog.ROSTER:
		check(PackCatalog.item(key).get("rarity", "") in tiers, "Item has authored rarity: " + key)
	for key: String in PackCatalog.RELICS:
		check(PackCatalog.relic(key).get("rarity", "") in tiers, "Relic has authored rarity: " + key)
	for key: String in PackCatalog.QUIVER.OPTIONS:
		check(PackCatalog.item(key).get("rarity", "") in tiers, "Quiver option has rarity: " + key)
	check(PackCatalog.item(PackCatalog.QUIVER.KEY).get("rarity", "") in tiers, "Bound quiver has rarity")
	for tier: String in tiers:
		check(PackCatalog.items_of_rarity(tier).size() >= 2, "At least two items in " + tier)
		check(not PackCatalog.relics_of_rarity(tier).is_empty(), "Relics cover " + tier)
	check(PackCatalog.items_of_rarity("invalid").is_empty(), "Unknown rarity cannot select rewards")
	var run := PackRun.new()
	run.reset(42)
	run.items.clear()
	run.relics.clear()
	var base: Dictionary = run.round_resources()
	run.relics.assign(["hearth_token", "herbalist_knot", "trail_medallion", "bastion_seal", "starwell_crown"])
	check(run.round_resources()["mana"] == base["mana"] + 2, "Relic mana refills each round")
	check(run.round_resources()["stamina"] == base["stamina"] + 2, "Relic stamina stacks across different relics")
	var effects: Dictionary = run.effects()
	check(effects["healing"] == 1 and effects["ward"] == 3 and effects["plating"] == 1, "New relic protection and regeneration are active")
	var item: Dictionary = run.add_item("rusty_knife", Vector2i.ZERO)
	item.erase("rarity")
	item["damage"] = 123
	var saves = preload("res://scripts/run_saves.gd").new()
	var saved: Dictionary = saves.capture(run, 0.0)
	saves.restore(run, saved)
	check(run.items[0]["rarity"] == "common" and run.items[0]["damage"] == 123, "Legacy save receives rarity without losing rolled stats")
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
				check(PackCatalog.item(key)["rarity"] == "common", "Early new equipment is common")
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
					var offered_tier: String = PackCatalog.item(key)["rarity"]
					seen[offered_tier] = true
					check(tiers.find(offered_tier) <= tier_index, "New reward obeys floor-tier gate")
		check(seen.has(tiers[tier_index]), "New tier enters rewards on floor %d" % (tier_index * 4 + 1))
	print("ITEM RARITY: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
