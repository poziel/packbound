@tool
class_name CollectibleCatalogDefinition
extends Resource
## Authored container for item/relic definitions and their complete category graph.
## This does not register content or replace the running PackCatalog service.

@export_tool_button("Refresh From Item / Relic Folders") var refresh_catalog: Callable = _refresh_in_inspector

@export_group("Collectibles")
@export var collectibles: Array[CollectibleDefinition] = []

@export_group("Categories")
@export var categories: Array[CollectibleCategoryDefinition] = []

func _refresh_in_inspector() -> void:
	var errors: PackedStringArray = refresh_from_folders()
	for error: String in errors:
		push_error(error)

## Build and validate a candidate first; never publish a partial or invalid catalog.
func refresh_from_folders(item_root: String = "res://assets/items", relic_root: String = "res://assets/relics", category_root: String = "res://assets/categories") -> PackedStringArray:
	var discovered: Dictionary = preload("res://systems/content/collectible_discovery.gd").discover(item_root, relic_root, category_root)
	var errors: PackedStringArray = discovered.errors
	if not errors.is_empty():
		return errors
	var candidate: Resource = get_script().new()
	candidate.collectibles.assign(discovered.collectibles)
	candidate.categories.assign(discovered.categories)
	errors = candidate.validation_errors()
	if not errors.is_empty():
		return errors
	collectibles.assign(candidate.collectibles)
	categories.assign(candidate.categories)
	resource_name = "Collectibles"
	emit_changed()
	return errors

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var category_by_id: Dictionary[StringName, CollectibleCategoryDefinition] = {}
	for index: int in range(categories.size()):
		var category: CollectibleCategoryDefinition = categories[index]
		if category == null:
			errors.append("categories[%d] must not be null." % index)
			continue
		for error: String in category.validation_errors():
			errors.append("categories[%d]: %s" % [index, error])
		if str(category.id).strip_edges().is_empty():
			continue
		if category_by_id.has(category.id):
			errors.append("categories[%d] duplicates category ID %s." % [index, category.id])
		else:
			category_by_id[category.id] = category
	for index: int in range(categories.size()):
		var category: CollectibleCategoryDefinition = categories[index]
		if category != null and category.parent_category_id != &"" and not category_by_id.has(category.parent_category_id):
			errors.append("categories[%d].parent_category_id references unknown category %s." % [index, category.parent_category_id])
	errors.append_array(_category_cycle_errors(category_by_id))
	var collectible_ids: Dictionary[StringName, bool] = {}
	for index: int in range(collectibles.size()):
		var collectible: CollectibleDefinition = collectibles[index]
		if collectible == null:
			errors.append("collectibles[%d] must not be null." % index)
			continue
		for error: String in collectible.validation_errors():
			errors.append("collectibles[%d]: %s" % [index, error])
		if not str(collectible.id).strip_edges().is_empty():
			if collectible_ids.has(collectible.id):
				errors.append("collectibles[%d] duplicates collectible ID %s." % [index, collectible.id])
			collectible_ids[collectible.id] = true
		for category_index: int in range(collectible.category_ids.size()):
			var category_id: StringName = collectible.category_ids[category_index]
			if not category_by_id.has(category_id):
				errors.append("collectibles[%d].category_ids[%d] references unknown category %s." % [index, category_index, category_id])
	return errors

## Iterative traversal avoids recursion limits for deeply nested authoring data.
func _category_cycle_errors(by_id: Dictionary[StringName, CollectibleCategoryDefinition]) -> PackedStringArray:
	var errors := PackedStringArray()
	var state: Dictionary[StringName, int] = {}
	for start: StringName in by_id:
		if state.has(start):
			continue
		var path: Array[StringName] = []
		var cursor: StringName = start
		while by_id.has(cursor) and not state.has(cursor):
			state[cursor] = 1
			path.append(cursor)
			cursor = by_id[cursor].parent_category_id
		if state.get(cursor, 0) == 1:
			errors.append("category cycle includes %s." % cursor)
		for category_id: StringName in path:
			state[category_id] = 2
	return errors
