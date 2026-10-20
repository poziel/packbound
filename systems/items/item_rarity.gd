extends RefCounted
## Definition rarity is independent of combat role, art palette and instance ID.
const TYPES = preload("res://systems/content/gameplay_types.gd")
const TIERS: Array[String] = TYPES.RARITY_IDS
const COLORS: Dictionary = {
	"common": Color("c4bdb0"), "uncommon": Color("78be83"),
	"rare": Color("72aaf0"), "epic": Color("bb91e8"), "legendary": Color("edbd63")
}
static var ITEMS: Dictionary:
	get:
		return _rarities(true)
static var RELICS: Dictionary:
	get:
		return _rarities(false)

static func _rarities(items: bool) -> Dictionary:
	var result: Dictionary = {}
	var catalog: Resource = preload("res://systems/content/runtime_content.gd").content().collectibles
	for value: CollectibleDefinition in catalog.collectibles:
		if (value is ItemDefinition) == items:
			result[str(value.id)] = str(TYPES.rarity_id(value.rarity))
	return result

static func tier(data: Dictionary) -> String:
	# Legacy in-memory/saved instances can omit rarity; definitions remain authoritative.
	var raw: Variant = data.get("rarity", "")
	if str(raw).is_empty():
		var value: CollectibleDefinition = preload("res://systems/content/collectible_categories.gd").definition_for_key(str(data.get("key", "")))
		raw = value.rarity if value != null else "common"
	var value: String = str(TYPES.rarity_id(raw)) if raw is int else str(raw)
	return value if value in TIERS else "common"

static func color(data: Dictionary) -> Color:
	return COLORS[tier(data)]

static func label(data: Dictionary) -> String:
	return tier(data).capitalize()

static func markup(data: Dictionary) -> String:
	return "[color=#%s]%s[/color]" % [color(data).to_html(false), label(data)]
