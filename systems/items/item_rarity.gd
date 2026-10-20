extends RefCounted
## Definition rarity is independent of combat role, art palette and instance ID.
const TYPES = preload("res://systems/content/gameplay_types.gd")
const COLORS: Dictionary = {
	TYPES.Rarity.COMMON: Color("c4bdb0"), TYPES.Rarity.UNCOMMON: Color("78be83"),
	TYPES.Rarity.RARE: Color("72aaf0"), TYPES.Rarity.EPIC: Color("bb91e8"), TYPES.Rarity.LEGENDARY: Color("edbd63")
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
			result[str(value.id)] = value.rarity
	return result

static func tier(data: Dictionary) -> GameplayTypes.Rarity:
	var raw: Variant = data.get("rarity")
	if raw == null:
		var value: CollectibleDefinition = preload("res://systems/content/collectible_categories.gd").definition_for_key(str(data.get("key", "")))
		raw = value.rarity if value != null else TYPES.Rarity.COMMON
	return raw if raw is int and TYPES.Rarity.values().has(raw) else TYPES.Rarity.COMMON

static func color(data: Dictionary) -> Color:
	return COLORS[tier(data)]

static func label(data: Dictionary) -> String:
	return str(TYPES.rarity_id(tier(data))).capitalize()

static func markup(data: Dictionary) -> String:
	return "[color=#%s]%s[/color]" % [color(data).to_html(false), label(data)]
