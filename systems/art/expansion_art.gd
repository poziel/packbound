extends RefCounted
## Compatibility views over authored icons; no separate texture-path catalog.
static var ITEM_TEXTURES: Dictionary:
	get:
		return _textures(preload("res://systems/items/expansion_items.gd").ITEM_KEYS)
static var RELIC_TEXTURES: Dictionary:
	get:
		return _textures(preload("res://systems/relics/expansion_relics.gd").RELIC_KEYS)

static func _textures(ids: Array) -> Dictionary:
	var result: Dictionary = {}
	for key: String in ids:
		var value: CollectibleDefinition = preload("res://systems/content/collectible_categories.gd").definition_for_key(key)
		result[key] = value.icon.atlas if value.icon is AtlasTexture else value.icon
	return result
