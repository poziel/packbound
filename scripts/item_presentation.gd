extends RefCounted
## Shared source labels and nested definitions for applied item bonuses.
const QUIVER = preload("res://scripts/archer_quiver.gd")

static func display_name(item: Dictionary) -> String:
	return "Bowmaster's Quiver" if item.get("key") == QUIVER.KEY else str(item["name"])

static func bonuses(run, item: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if item.get("key") == QUIVER.KEY:
		var arrow: String = "arrow_" + str(item.get("arrow_type", ""))
		if QUIVER.OPTIONS.has(arrow):
			result.append(_upgrade(arrow, 1))
		for key: String in QUIVER.OPTIONS:
			var count: int = int(item.get("upgrades", {}).get(key, 0))
			if count > 0:
				result.append(_upgrade(key, count))
	var sources: Array = run.packed()
	sources.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["id"]) < int(b["id"]))
	for source: Dictionary in sources:
		var amount: int = run.bonus(source, item)
		if amount <= 0:
			continue
		var stat: String = "block" if item["role"] == "shield" else "damage"
		var label: String = "+%d %s from %s" % [amount, stat, display_name(source)]
		var source_key: String = "catalog_item_" + str(source["key"])
		var markup: String = PackKeywordLinks.rich("+%d %s from " % [amount, stat]) + "[url href=%s underline=never][u]%s[/u][/url]" % [source_key, display_name(source)]
		result.append({"key": "item_bonus_%d_%d" % [item["id"], source["id"]], "label": label, "tooltip": false, "markup": markup, "definitions": {source_key: catalog_inspection(str(source["key"]))}})
	return result

static func catalog_inspection(key: String) -> Dictionary:
	var item: Dictionary = PackCatalog.item(key)
	return {"key": "catalog_item_" + key, "title": display_name(item), "body": PackKeywords.item_description(item), "bound": key == QUIVER.KEY, "keyword_list": [] if key == QUIVER.KEY else PackKeywords.item_stats(item), "keyword_stats": volley_stats(null, item), "resource_costs": PackKeywords.item_resource_costs(item)}

static func _upgrade(key: String, count: int) -> Dictionary:
	var option: Dictionary = QUIVER.OPTIONS[key]
	return {"key": "quiver_bonus_" + key, "label": str(option["name"]) + (" ×%d" % count if count > 1 else ""), "title": str(option["name"]), "body": str(option["detail"]).replace("Choose your starting arrows: ", "").replace("Quiver upgrade: ", "") + ("\nApplied %d times" % count if count > 1 else "")}

static func volley_stats(run, item: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if item.get("key") != QUIVER.KEY:
		return result
	var values: Dictionary = QUIVER.stats(item, run.item_bonus(item) if run != null else 0)
	for key: String in ["damage", "pierce", "poison", "burn"]:
		if int(values[key]) > 0:
			result.append({"key": "piercing" if key == "pierce" else key, "icon": "physical_attack" if key == "damage" else ("piercing" if key == "pierce" else key), "value": int(values[key])})
	return result
