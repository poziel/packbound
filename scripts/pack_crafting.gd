extends RefCounted
## Recipes use orthogonal occupied-cell contact, independent of booster relics.
## Order is recipe priority; ingredients use stable backpack reading order.
const ANIMATION_SECONDS: float = 1.35
const RECIPES: Array[Dictionary] = [
	{"id": "iron_dagger", "ingredients": ["rusty_knife", "rusty_knife"], "result": "longsword"},
	{"id": "shield_relic", "ingredients": ["cracked_shield", "cracked_shield"], "result": "tower_shield"},
	{"id": "moonleaf", "ingredients": ["bandage", "bandage", "antidote"], "result": "healing_herbs"},
]

static func nearest_tiles(run, first: Dictionary, second: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var distance: int = 2147483647
	var a: Array[Vector2i] = run.cells(first)
	var b: Array[Vector2i] = run.cells(second)
	a.sort_custom(_cell_before)
	b.sort_custom(_cell_before)
	for start in a:
		for finish in b:
			var next_distance: int = (finish - start).length_squared()
			if next_distance < distance:
				distance = next_distance
				result.assign([start, finish])
	return result

static func _cell_before(a: Vector2i, b: Vector2i) -> bool:
	return a.y < b.y or (a.y == b.y and a.x < b.x)

static func links(run, components: Array[Dictionary]) -> Array[Dictionary]:
	# A spanning tree gives N-1 links, including chains, without extra triangles.
	var result: Array[Dictionary] = []
	if components.is_empty():
		return result
	var connected: Array[int] = [0]
	while connected.size() < components.size():
		var found: bool = false
		for source in connected.duplicate():
			for target in range(components.size()):
				if connected.has(target):
					continue
				var pair: Array[Vector2i] = nearest_tiles(run, components[source], components[target])
				if pair.size() == 2 and (pair[1] - pair[0]).length_squared() == 1:
					result.append({"from": pair[0], "to": pair[1], "source_id": components[source]["id"], "target_id": components[target]["id"]})
					connected.append(target)
					found = true
		if not found:
			return []
	return result

static func _placement(_run, recipe: Dictionary, components: Array[Dictionary]) -> Dictionary:
	var output: Dictionary = PackCatalog.item(recipe["result"])
	output["cell"] = null
	output["priority"] = components[0].get("priority", 0)
	return output

static func _place_result(run, output: Dictionary, components: Array[Dictionary]) -> void:
	var center := Vector2.ZERO
	for component in components:
		center += Vector2(component["cell"])
	center /= components.size()
	var best: float = INF
	for rotation in range(4):
		for y in run.GRID.y:
			for x in run.GRID.x:
				var at := Vector2i(x, y)
				var distance: float = Vector2(at).distance_squared_to(center)
				if distance < best and run.can_place(output, at, rotation):
					best = distance
					output["cell"] = at
					output["rotation"] = rotation
					output["shape"] = run.dimensions(output, rotation)

static func _match(run, recipe: Dictionary, pool: Array[Dictionary], chosen: Array[Dictionary], index: int) -> Dictionary:
	if index == recipe["ingredients"].size():
		var edges: Array[Dictionary] = links(run, chosen)
		if edges.size() != chosen.size() - 1:
			return {}
		var output: Dictionary = _placement(run, recipe, chosen)
		if output.is_empty():
			return {}
		return {"recipe": recipe["id"], "components": chosen.duplicate(), "output": output, "links": edges}
	for component in pool:
		if run.is_permanent(component):
			continue
		if component["key"] != recipe["ingredients"][index] or chosen.has(component):
			continue
		# Repeated keys are combinations rather than permutations.
		if index > 0 and recipe["ingredients"][index] == recipe["ingredients"][index - 1] and int(component["id"]) < int(chosen.back()["id"]):
			continue
		chosen.append(component)
		var candidate: Dictionary = _match(run, recipe, pool, chosen, index + 1)
		chosen.pop_back()
		if not candidate.is_empty():
			return candidate
	return {}

static func plans(run, respect_locks: bool = true) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not run.can_edit_inventory():
		return result
	var available: Array[Dictionary] = run.packed()
	if respect_locks:
		available = available.filter(func(item: Dictionary) -> bool: return not item.has("craft_lock"))
	for recipe in RECIPES:
		while true:
			var missing: Array = recipe["ingredients"].duplicate()
			for component in available:
				missing.erase(component["key"])
			if not missing.is_empty():
				break
			var chosen: Array[Dictionary] = []
			var candidate: Dictionary = _match(run, recipe, available, chosen, 0)
			if candidate.is_empty():
				break
			result.append(candidate)
			for component: Dictionary in candidate["components"]:
				available.erase(component)
	return result

static func attempts(run) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not run.can_edit_inventory():
		return result
	var available: Array[Dictionary] = run.packed()
	available = available.filter(func(item: Dictionary) -> bool: return not item.has("craft_lock"))
	# Reserve complete recipes first so partial groups cannot steal ingredients.
	for plan in plans(run):
		var total: int = plan["components"].size()
		result.append({"recipe": plan["recipe"], "components": plan["components"], "links": plan["links"], "output": plan["output"], "count": total, "total": total, "ready": true})
		for component: Dictionary in plan["components"]:
			available.erase(component)
	for recipe in RECIPES:
		for seed: Dictionary in available.duplicate():
			if not available.has(seed) or not recipe["ingredients"].has(seed["key"]):
				continue
			var remaining: Array = recipe["ingredients"].duplicate()
			var group: Array[Dictionary] = [seed]
			remaining.erase(seed["key"])
			var changed: bool = true
			while changed:
				changed = false
				for candidate in available:
					if group.has(candidate) or not remaining.has(candidate["key"]):
						continue
					for member in group.duplicate():
						var pair: Array[Vector2i] = nearest_tiles(run, member, candidate)
						if (pair[1] - pair[0]).length_squared() == 1:
							group.append(candidate)
							remaining.erase(candidate["key"])
							changed = true
							break
			if group.size() < 2:
				continue
			result.append({"recipe": recipe["id"], "components": group, "links": links(run, group), "output": _placement(run, recipe, group), "count": group.size(), "total": recipe["ingredients"].size(), "ready": remaining.is_empty()})
			for component in group:
				available.erase(component)
	return result

static func toggle_lock(run, item: Dictionary) -> bool:
	if not run.can_edit_inventory() or not run.items.has(item):
		return false
	if item.has("craft_lock"):
		item.erase("craft_lock")
	else:
		item["craft_lock"] = true
	return true

static func recipe_inspection(_run, item: Dictionary) -> Dictionary:
	var rows: Array[Dictionary] = []
	var definitions: Dictionary = {}
	for recipe: Dictionary in RECIPES:
		if not recipe["ingredients"].has(item["key"]):
			continue
		var ingredients: Array[Dictionary] = []
		for ingredient: String in recipe["ingredients"]:
			ingredients.append(PackCatalog.item(ingredient))
			_recipe_definition(ingredient, definitions)
		_recipe_definition(recipe["result"], definitions)
		rows.append({"ingredients": ingredients, "output": PackCatalog.item(recipe["result"])})
	if rows.is_empty():
		return {}
	return {"key": "crafts_%s" % str(item.get("id", item["key"])), "title": "Possible crafts", "recipes": rows, "definitions": definitions, "requires_alt": true}

static func _recipe_definition(key: String, definitions: Dictionary) -> void:
	var item: Dictionary = PackCatalog.item(key)
	var link: String = "recipe_item_" + key
	definitions[link] = {"key": link, "title": item["name"], "body": PackKeywords.item_description(item), "keyword_list": PackKeywords.item_stats(item, 0), "resource_costs": PackKeywords.item_resource_costs(item)}

static func partners(run, item: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if item.has("craft_lock"):
		return result
	for candidate: Dictionary in run.packed():
		if candidate.has("craft_lock"):
			continue
		if candidate["id"] == item["id"]:
			continue
		for recipe in RECIPES:
			var ingredients: Array = recipe["ingredients"]
			if ingredients.has(item["key"]) and ingredients.has(candidate["key"]) and (item["key"] != candidate["key"] or ingredients.count(item["key"]) >= 2):
				result.append(candidate)
				break
	return result

static func resolve(run) -> Array[Dictionary]:
	# Remove all consumed ingredients first, then place outputs without moving
	# unrelated items. Outputs never chain-craft during this combat start.
	var prepared: Array[Dictionary] = plans(run)
	for plan in prepared:
		for component: Dictionary in plan["components"]:
			run.items.erase(component)
	for plan in prepared:
		var names := PackedStringArray()
		for component: Dictionary in plan["components"]:
			names.append(run._log_item(component))
		var output: Dictionary = plan["output"]
		output["id"] = run.next_id
		run.next_id += 1
		_place_result(run, output, plan["components"])
		run.items.append(output)
		var destination: String = " Sent to stash: no room in the grid." if output["cell"] == null else ""
		run.log_line("Crafted %s from %s.%s" % [run._log_item(output), " + ".join(names), destination])
	return prepared

static func hint(run, item: Dictionary) -> String:
	for plan in plans(run):
		for component: Dictionary in plan["components"]:
			if component["id"] == item["id"]:
				return "Ready to merge into %s when battle starts." % plan["output"]["name"]
	for recipe in RECIPES:
		if not recipe["ingredients"].has(item["key"]):
			continue
		var names := PackedStringArray()
		for key: String in recipe["ingredients"]:
			names.append(PackCatalog.item(key)["name"])
		return "%s → %s. Touch components edge-to-edge; merges when battle starts. The result enters the grid, or the stash if full." % [" + ".join(names), PackCatalog.item(recipe["result"])["name"]]
	return ""
