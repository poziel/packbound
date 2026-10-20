extends "res://tests/support/test_case.gd"
const CATEGORIES = preload("res://systems/content/collectible_categories.gd")

func _run() -> void:
	var content: Resource = load("res://assets/game_content.tres")
	check_equal(content.validation_errors(), PackedStringArray(), "Complete category graph and memberships validate")
	var families: Dictionary = {"weapon": "melee_weapons", "ranged": "ranged_weapons", "spell": "magic_weapons", "shield": "shields", "armor": "body_armor", "boots": "boots", "healer": "healing_supplies", "booster": "boosters", "focus": "focuses", "pendant": "pendants", "quiver": "quivers", "upgrade": "quiver_upgrades", "companion": "companions", "utility": "utilities"}
	for definition: CollectibleDefinition in content.collectibles.collectibles:
		check(not definition.category_ids.is_empty(), "Every collectible has a category")
		for category_id: StringName in definition.category_ids:
			check(CATEGORIES.matches(definition, category_id), "Direct membership resolves")
		if not definition is ItemDefinition:
			continue
		check(definition.get("role") == null, "Resource has no role property")
		var item: Dictionary = PackCatalog.item(str(definition.id))
		check(not item.has("role"), "Runtime catalog has no role field")
		check_equal(item.category_ids, definition.category_ids, "Runtime reads authored memberships")
		var legacy: Dictionary = PackCatalog._legacy_item(str(definition.id))
		if legacy.has("role"):
			check(CATEGORIES.matches(item, StringName(families[legacy.role])), "Legacy combat family preserved: " + str(definition.id))
	check(CATEGORIES.matches(PackCatalog.item("boiler_hammer"), &"hammers"), "Hammer has specific type")
	check(CATEGORIES.matches(PackCatalog.item("boiler_hammer"), &"melee_weapons"), "Hammer inherits melee family")
	check(CATEGORIES.matches(PackCatalog.item("boiler_hammer"), &"weapons"), "Hammer inherits weapons")
	check(not CATEGORIES.matches(PackCatalog.item("boiler_hammer"), &"magic_weapons"), "Hammer does not become a spell because it applies burn")
	check(CATEGORIES.matches(PackCatalog.item("longsword"), &"daggers"), "Legacy ID follows actual Iron Dagger identity")
	check(CATEGORIES.matches(PackCatalog.item("ember_tome"), &"magic_books"), "Grimoire is a magic book")
	check(CATEGORIES.matches(PackCatalog.item("ember_tome"), &"weapons"), "Magic books inherit weapons")
	check(CATEGORIES.matches(PackCatalog.item("shortbow"), &"bows"), "Bow has specific type")
	check(CATEGORIES.matches({"category_ids": ["boots"]}, &"armor"), "Boots inherit armor")
	var hybrid: Dictionary = {"category_ids": ["daggers", "bows"]}
	check(CATEGORIES.matches(hybrid, &"melee_weapons") and CATEGORIES.matches(hybrid, &"ranged_weapons"), "Multiple memberships work")
	check(CATEGORIES.matches_any(hybrid, ["weapons", "melee_weapons"]), "Several matching ancestors produce one boolean")
	check(not CATEGORIES.matches({"category_ids": ["missing"]}, &"missing"), "Unknown categories fail closed")
	check(CATEGORIES.matches({"key": "longsword", "role": "spell"}, &"melee_weapons"), "Old saves resolve by stable content ID")
	check(not CATEGORIES.matches({"key": "longsword", "role": "spell"}, &"magic_weapons"), "Obsolete role cannot override categories")
	check_equal(CATEGORIES.target_ids({"target_roles": ["weapon", "spell"]}), ["melee_weapons", "magic_weapons"], "Old adjacency saves translate safely")
	check_equal(CATEGORIES.target_ids({"target_category_ids": ["daggers"]}), ["daggers"], "New adjacency rules accept specific categories")
	report("COLLECTIBLE CATEGORIES")
	quit(1 if failures else 0)
