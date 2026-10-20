extends RefCounted
## Rarity expansion: fixed definitions, ordinary existing combat stats only.

const ITEM_KEYS: Array[String] = ["field_blade", "riveted_guard", "tempered_blade", "iron_guard", "oathsteel_blade", "sentinel_guard", "dusksteel_blade", "citadel_guard", "dawnbringer", "sovereign_guard"]
const RELIC_KEYS: Array[String] = ["hearth_token", "herbalist_knot", "trail_medallion", "bastion_seal", "starwell_crown"]

static func items() -> Dictionary:
	var result: Dictionary = {}
	for key: String in ITEM_KEYS:
		result[key] = PackCatalog.item(key)
	return result

static func relics() -> Dictionary:
	var result: Dictionary = {}
	for key: String in RELIC_KEYS:
		result[key] = PackCatalog.relic(key)
	return result
