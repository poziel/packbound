extends RefCounted
## Rarity expansion: fixed definitions, ordinary existing combat stats only.

const ITEM_KEYS: Array[String] = ["field_blade", "riveted_guard", "tempered_blade", "iron_guard", "oathsteel_blade", "sentinel_guard", "dusksteel_blade", "citadel_guard", "dawnbringer", "sovereign_guard"]
const RELIC_KEYS: Array[String] = ["hearth_token", "herbalist_knot", "trail_medallion", "bastion_seal", "starwell_crown"]
const STAT_KEYS: Array[String] = preload("res://systems/content/gameplay_types.gd").STAT_IDS

static func items() -> Dictionary:
	var result: Dictionary = {}
	result["field_blade"] = _item("field_blade", "Field Blade", "common", "weapon", 2, {"damage": 5}, 1, "Costs 1 stamina: 5 physical damage.")
	result["riveted_guard"] = _item("riveted_guard", "Riveted Guard", "common", "shield", 1, {"block": 4}, 0, "Starts each fight with 4 block.")
	result["tempered_blade"] = _item("tempered_blade", "Tempered Blade", "uncommon", "weapon", 2, {"damage": 8}, 1, "Costs 1 stamina: 8 physical damage.")
	result["iron_guard"] = _item("iron_guard", "Iron Guard", "uncommon", "shield", 1, {"block": 7}, 0, "Starts each fight with 7 block.")
	result["oathsteel_blade"] = _item("oathsteel_blade", "Oathsteel Blade", "rare", "weapon", 2, {"damage": 11, "pierce": 2}, 2, "Costs 2 stamina: 11 physical damage. Bypasses 2 block.")
	result["sentinel_guard"] = _item("sentinel_guard", "Sentinel Guard", "rare", "shield", 1, {"block": 11, "thorns": 1}, 0, "Starts each fight with 11 block. Retaliates for 1 damage per enemy strike.")
	result["dusksteel_blade"] = _item("dusksteel_blade", "Dusksteel Blade", "epic", "weapon", 2, {"damage": 15, "pierce": 3}, 2, "Costs 2 stamina: 15 physical damage. Bypasses 3 block.")
	result["citadel_guard"] = _item("citadel_guard", "Citadel Guard", "epic", "shield", 1, {"block": 16, "thorns": 2}, 0, "Starts each fight with 16 block. Retaliates for 2 damage per enemy strike.")
	result["dawnbringer"] = _item("dawnbringer", "Dawnbringer", "legendary", "weapon", 2, {"damage": 20, "pierce": 5}, 3, "Costs 3 stamina: 20 physical damage. Bypasses 5 block.")
	result["sovereign_guard"] = _item("sovereign_guard", "Sovereign Guard", "legendary", "shield", 1, {"block": 22, "thorns": 3}, 0, "Starts each fight with 22 block. Retaliates for 3 damage per enemy strike.")
	return result

static func _item(key: String, label: String, rarity: String, role: String, height: int, stats: Dictionary, stamina_cost: int, detail: String) -> Dictionary:
	var offsets: Array[Vector2i] = []
	for y in range(height):
		offsets.append(Vector2i(0, y))
	var result: Dictionary = {"key": key, "name": label, "rarity": rarity, "role": role, "mask": offsets, "shape": Vector2i(1, height), "rotation": 0, "detail": detail, "tooltip_detail": "", "cost": 0, "stamina_cost": stamina_cost, "priority": 0, "mana_per_round": 0, "stamina_per_round": 0, "block_per_round": 0, "damage_type": "physical", "element": ""}
	for stat: String in STAT_KEYS:
		result[stat] = 0
	result.merge(stats, true)
	return result

static func relics() -> Dictionary:
	return {
		"hearth_token": {"key": "hearth_token", "name": "Hearth Token", "icon": "hearth_token", "rarity": "common", "stats": {"ward": 1}, "detail": "While owned: +1 ward.", "keyword_stats": [{"key": "ward", "value": 1, "qualifier": ""}]},
		"herbalist_knot": {"key": "herbalist_knot", "name": "Herbalist Knot", "icon": "herbalist_knot", "rarity": "uncommon", "stats": {"healing": 1}, "detail": "While owned: +1 healing.", "keyword_stats": [{"key": "healing", "value": 1, "qualifier": ""}]},
		"trail_medallion": {"key": "trail_medallion", "name": "Trail Medallion", "icon": "trail_medallion", "rarity": "rare", "stats": {"stamina": 1}, "detail": "While owned: +1 stamina.", "keyword_stats": [{"key": "stamina", "value": 1, "qualifier": "maximum"}]},
		"bastion_seal": {"key": "bastion_seal", "name": "Bastion Seal", "icon": "bastion_seal", "rarity": "epic", "stats": {"plating": 1, "ward": 2}, "detail": "While owned: +1 plating, +2 ward.", "keyword_stats": [{"key": "plating", "value": 1, "qualifier": ""}, {"key": "ward", "value": 2, "qualifier": ""}]},
		"starwell_crown": {"key": "starwell_crown", "name": "Starwell Crown", "icon": "starwell_crown", "rarity": "legendary", "stats": {"mana": 2, "stamina": 1}, "detail": "While owned: +2 mana, +1 stamina.", "keyword_stats": [{"key": "mana", "value": 2, "qualifier": "maximum"}, {"key": "stamina", "value": 1, "qualifier": "maximum"}]},
	}
