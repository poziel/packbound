extends RefCounted
## Category ancestry is the classification authority for Resources and legacy run records.
static var _parents: Dictionary = {}
static var _memberships: Dictionary = {}
static var _definitions: Dictionary = {}
static var _loaded: bool = false

static func _ensure_loaded() -> void:
	if _loaded:
		return
	var catalog: Resource = preload("res://systems/content/collectible_catalog_definition.gd").new()
	var errors: PackedStringArray = catalog.refresh_from_folders()
	if not errors.is_empty():
		push_error("Cannot discover collectibles: " + "; ".join(errors))
		return
	for category: CollectibleCategoryDefinition in catalog.categories:
		_parents[category.id] = category.parent_category_id
	for item: CollectibleDefinition in catalog.collectibles:
		_memberships[str(item.id)] = item.category_ids.duplicate()
		_definitions[str(item.id)] = item
	_loaded = true

## Definitions discovered once per process; callers must treat them as read-only.
static func definition_for_key(key: String) -> CollectibleDefinition:
	_ensure_loaded()
	return _definitions.get(key)

static func ids_for_key(key: String) -> Array:
	_ensure_loaded()
	return _memberships.get(key, []).duplicate()

static func matches(item: Variant, category_id: StringName) -> bool:
	_ensure_loaded()
	var ids: Array = []
	if item is Dictionary:
		# Old saves lack category IDs. Resolve stable content IDs; never infer from role.
		ids.assign(item.get("category_ids", ids_for_key(str(item.get("key", "")))))
	elif item is CollectibleDefinition:
		ids.assign(item.category_ids)
	for id: StringName in ids:
		var visited: Dictionary = {}
		var cursor: StringName = id
		while cursor != &"" and not visited.has(cursor):
			if cursor == category_id and _parents.has(cursor):
				return true
			visited[cursor] = true
			cursor = _parents.get(cursor, &"")
	return false

static func matches_any(item: Variant, category_ids: Array) -> bool:
	for id: StringName in category_ids:
		if matches(item, id):
			return true
	return false

## Read old saved adjacency rules without using an item's retired role field.
static func target_ids(rule: Dictionary) -> Array:
	if rule.has("target_category_ids"):
		return rule.target_category_ids
	var legacy: Dictionary = {"weapon": "melee_weapons", "ranged": "ranged_weapons", "spell": "magic_weapons", "shield": "shields", "companion": "companions", "quiver": "quivers"}
	var result: Array = []
	for id: String in rule.get("target_roles", []):
		if legacy.has(id):
			result.append(legacy[id])
	return result
